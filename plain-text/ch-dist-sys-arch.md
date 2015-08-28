## System Architecture

In this section, we will present the architecture of the distributed system implemented and how its individual components communicate and coordinate during the execution of a query.

An abstract overview of the whole distributed architecture is illustrated in **Figure X.1**.

**// IMAGE DAME**

### Model

The design of the distributed system follows the well-known "master-worker" model, where one node acts as a master which coordinates the worker nodes. The worker nodes form a cluster and its size can range from one to multiple nodes.

In our implementation the master node is used only for coordination, in order to provide abstract synchronization during the different stages of execution to the worker nodes who are working entirely asynchronous while a query is being processed.

Additionally, the implementation does not require the master node to be a standalone machine, hence giving someone the option to use any of the worker nodes as the master of the system too. The master's responsibility is just to receive a single message from each worker node at the beginning of each phase denoting their status (ready to proceed) and responding back with the next phase initiation signal.

Moreover, the system can be used entirely on a single machine and use separate processes to simulate the nodes of the cluster. This not only provides an easy way to debug and test the framework and its future extensions but it also let's us exploit multi-processor and multi-core machines. The current FDB implementation is centralized and single threaded so this customization is very welcomed since it enables parallel query execution, however in this project the system aimed to run on a cluster of machines.

All configuration options about the topology (master, worker nodes) and the query to be processed are specified using two simple configuration files, see **Section X**.

### System protocol

The system, once given a distributed query processing request, starts the _distributed runner_ in each site (node). This is a special class that determines whether the running process is a master or a worker and initiates distributed execution.

The distributed execution of a query has the four stages explained below.

1. **Initial Handshake**
    The purpose of this stage is to ensure that all nodes are up and running, ready to process the query.
    Each worker node sends a _hello_ message to the master in order to signal its existence and well being in the cluster. Once the worker sends this message, it blocks until the response from the master comes back. Before sending the _hello_ message though, each worker spawns a separate thread/process and runs the **ReaderData** (see **following Section**).
    The master node on the other side upon starting, waits to receive N _hello_ messages, where N is the number of worker nodes. As soon as the master receives all handshakes, it sends to all workers a message to initiate the next stage, _Connection Establishment_.

2. **Connection establishment**
    In this stage each worker node establishes TCP connection with all other workers, in order to be able to send and receive messages without establishing new connections every single time during the query execution.
    When a node receives the _Connection Establishment_ initiation message, it spawns a new thread/process and runs the **WriterData** (see following Section) which is going to initiate connection to the _ReaderData_ of all the worker nodes in the cluster. When all the connections have been established and cached each worker sends a _ConnectionEstablishmentFinished_ message to the master and blocks.
    The master again just waits to receive N _ConnectionEstablishmentFinished_ messages and once it does it broadcasts the _QueryExecution_ message to signal initiation of the next stage.

3. **Query execution**
    This is the most important stage of the whole distributed query processing.
    In this stage each worker will parse the query configuration, load the local inputs in memory and depending on the distribution mode (Single round vs Multi round) it will execute the query. When the query has been processed, the _QueryExecutionFinished_ message is sent to the master.
    The master waits for N _QueryExecutionFinished_ messages and once received sends the initiation message for the final stage.

4. **Results gathering**
    This is the stage where any communication of information regarding the partial results on each worker should be made. For example, each worker can send a path to the master node where the partial query result is located.
    Moreover, this stage is the final stage of the distributed query processing so the workers can do any cleanup and terminate gracefully.

The whole query processing is done in stage 3, including data partitioning, shuffling and f-plan execution on local factorizations. The rest stages were required for bootstrapping purposes of the system and in a real-world scenario where a cluster of nodes is already up and running they would not even exist. Therefore, it is nice to have the query processing isolated in order to be able to reason correctly about each processing phase and also about the end-to-end experience of the system which can easily be measured on the master node.

### Communication in the cluster

In the previous section, _System protocol_ we mentioned _ReaderData_ and _WriterData_.

These two classes, runnables in separate threads, are responsible for all the data transmission among worker nodes, both in Single and in Multi round execution. 

**ReaderData** is initiated during _Stage 1_ and it starts by creating a TCP socket listener ready to accept connections from the _WriterData_ threads during _Stage 2_. **WriterData** is initiated during _Stage 2_ and instantly tries to connect to all worker nodes, specifically to the _ReaderData_ threads running on them.

In _Stage 3_, query execution stage, the two _services_ are responsible to send and receive factorizations over the wire using TCP. Specifically, ReaderData in each execution round (one for Single mode, many for Multi mode) waits on each one of the N worker TCP streams in order to receive this round's factorization from each other node. It uses the _Bit Deserializer_ to deserialize data received into in-memory dactorizations, skipping all empty factorizations. On the other side, WriterData is responsible to take the input factorizations (or the previous round's result) and serialize it to all worker nodes using the _Bit Serializer HyperCube_ which incorporates the HyperCube algorithm. If no values are valid to be sent to a node, the empty factorization is sent.

There exist, couple of design rules during data communication as enumerated below.

1. Each worker will send a single factorization to each other worker during each data communication phase of the query exeuction stage. In case no valid values exist then a factorization with zero values is sent (only the f-tree basically). 
2. All factorizations sent in the same communication round should have the same f-tree, because they are merged into a global one which is then being applied an f-plan (query operations).
3. The factorizations are serialized into the TCP streams using _Bit Serializer HyperCube_ and deserialized on the other side using _Bit Deserializer_.

The decoupling of data communication from the execution thread, even reading data from writing data, turned out to be very useful because it made the implementation more modularized and more extensible to make improvements on any side without affecting the other. Most importantly, since reading and writing are decoupled and they run in parallel we achieve concurrency during communication phase since a worker can send data to one node and receive from another at the same time.

#### Ordered communication vs others

In all distributed systems there is a certain point of time where each node has to communicate data with other nodes. Many times all nodes have to send data to all other nodes. 

One problem we spotted while designing the system is the order of the actual data transmission. It is a problem that appears in every distributed system but there is no published work on how this should be done. Even work that studies algorithms for better data partitioning and shuffling, like HyperCube, which are very relevant to this problem do not address this issue.

We had numerous ideas and thoughts but we concluded in two designs and finally implemented one, with the other added to the future work!

**Idea 1 - Ordered communication**

In this approach the threads ReaderData and WriterData  will read and write respectively data to other workers following a specific order with goal to achieve good throughput. ReaderData fully reads a message from one node before proceeding to the next one, while WriterData fully writes data to one node before writing to the next one.

The specific ordering in reads and writes aims to maximize possibility for high thoughput and maximum overlap between reads and writes in the cluster. We want to avoid having a node waiting to receive data from one node at the same time while another node is blocked waiting to send data to a busy node.

For example, let us see the following communication ordering in a cluster of 5 worker nodes.

_Writing ordering_
```
Node 1: 2 3 4 5
Node 2: 3 4 5 1
Node 3: 4 5 1 2
Node 4: 5 1 2 3
Node 5: 1 2 3 4
```

_Reading ordering_
```
Node 1: 5 4 3 2
Node 2: 1 5 4 3
Node 3: 2 1 5 4
Node 4: 3 2 1 5
Node 5: 4 3 2 1 
```

The first block defines the order of writes for each node. Node 1 for instance, will send data to node 2, then node 3, then node 4 finally node 5. The second block defines the order of reads for each node. For example, Node 3 will read from node 2, then node 1, then node 5 and finally node 4.

The important thing in this ordering is if we distinguish 4 communication rounds (vertical division) we can see that no node is ever stalled or blocked without reading or writing. Additionally, there is a pairing between the reads and the writes, which means that for any given node A, the writes _targetting_ A will be done in the same order as A will do his reads.

In our tests, the idea works as expected but still there were some cases when a node had to write more data than other nodes some nodes were waiting for it to finish.

**Idea 2 - Round robin communication**

A second approach to the communication problem was incorporated round-robin communication. The intuition to this idea is that instead of fully communicating with one node before moving on to the next one (either when writing or reading), we could write less to all the nodes and iterate more times.

For example if node A has to send 1000 MB to all other nodes, instead of sending the whole 1000MB one node at a time, it sends the first 100MB to all of them, then the next 100MB to all of them, and so long. This approach aims to keep all nodes busy at all times and possibly avoid having nodes blocked at a node that is doing a long read/write.

The disadvantage though of this approach to the previous ordered one is that we need to keep track of the required information while sending (or receiving) for all nodes. For example, when serializing a factorization we use some statistics and a vector that holds a state for each union node. In this approach we have to calculate and have in-memory this information for all nodes.

Unfortunately, due to limited time we did not compare the two solutions and only implemented the first one.









