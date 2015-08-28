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

### System message protocol

The system, once given a distributed query processing request, starts the _distributed runner_ in each site (node). This is a special class that determines whether the running process is a master or a worker and initiates distributed execution.

The distributed execution of a query has the four stages explained below.

1. **Initial Handshake**
    The purpose of this stage is to ensure that all nodes are up and running, ready to process the query.
    Each worker node sends a _hello_ message to the master in order to signal its existence and well being in the cluster. Once the worker sends this message, it blocks until the response from the master comes back. Before sending the _hello_ message though, each worker spawns a separate thread/process and runs the **ReaderData** (see **following Section**).
    The master node on the other side upon starting, waits to receive N _hello_ messages, where N is the number of worker nodes. As soon as the master receives all handshakes, it sends to all workers a message to initiate the next stage, _Connection Establishment_.

2. **Connection establishment**
    In this stage each node establishes TCP connection with all other nodes, in order to be able to send and receive messages without establishing new connections every single time.
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
















