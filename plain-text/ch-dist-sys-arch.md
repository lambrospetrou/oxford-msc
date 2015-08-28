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
