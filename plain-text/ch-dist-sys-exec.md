## Query processing

In this section we will provide a description of the two modes supported for distributed query execution, namely Single and Multi round execution, and then explain how these are implemented during the _execution stage_ of our system.

### Single vs Multi round 

The distributed system presented in this chapter supports two modes of execution, with each mode being different in the number of communication rounds before completely evaluating the query. 

#### Single round 

Single round execution refers to multi-way JOIN operations when a query requires joinining more than one attribute. Single round execution is based on the use of the HyperCube algorithm which partitions and shuffles the data based on all the attributes to joined at once.

A lot of researchers investigated the costs incurred in a distributed system and it is widely and publicly acceptable that a major bottleneck in distributed execution is the communication among worker nodes. Therefore, people try to devise algorithms that try to eliminate this cost as much as possible, hence HyperCube and its variations.

To summarize, single round execution means that each worker will send data to other workers only once, hence the single communication round, followed by evaluation of the multiple attribute JOIN.

#### Multi round

Multi round execution refers to the evaluation of complex queries by processing a fraction of the query in each round until the whole query has been processed. For example, if the query requires joining on 3 attributes we could either have an execution that evaluates the two joins in the first round and the last one in the third round or we could even have three rounds evaluating a single join in each round.

With multi round execution one can investigate more complex topics like query decompositions into smaller queries that are easier to evaluate in separate rounds, that at the same time do not necessarily need to be single attribute JOIN operations.


### Query execution phase

In this section we will describe how the above two modes are implemented in the proposed distributed system, what are their limitations and how can they improved.

Query processing and result evaluation corresponds to _Stage 3_ as described in the _System protocol_. Details about the query and the cluster topology are specified in configuration files (will be described in the next section).

We will present the steps to process a single round evaluation first which is then going to be used for Multi round.

1. we start by loading the input factorization in memory (using the configuration files to locate them)
2. we signal ReaderData to start accepting factorizations from other workers and give the inputs to WriterData to start writing data to other workers
3. once all factorizations from other workers have been received, we drop the empty ones and use the special *merge\_same* operator to merge the partial factorizations received into a single factorization
4. we now are at the last step of the processing where we read from the query configuration file the f-plan operations and using the *f-plan executor* we evaluate the query on the local factorization
5. notify master node that we finished query execution

The multi round execution is similar and pretty much wraps steps 1 to 4 into a loop for each round where the input initially is loaded from local storage and in consecutive rounds we use the result of the previous round as input to the next round.

### Configuration files

In this section we briefly present the two main configuration files used that specify the network topology and the query to be evaluated.











