## Query processing and configuration files

In this section we will provide a description of the two modes supported for distributed query execution, namely Single and Multi round execution, and then explain how these are implemented during the _execution stage_ of our system. Finally, we present the configuration files we use to specify the type of execution and the query to evaluate.

### Single vs Multi round 

The distributed query engine presented in this chapter supports two modes of execution, with each mode being different in the number of communication rounds before completely evaluating the query. 

#### Single round 

Single round execution refers to multi-way JOIN operations when a query requires joining more than one attribute. Single round execution is based on the use of the HyperCube algorithm which partitions and shuffles data considering all the attributes to be joined at the same time.

A lot of work has been done by researchers investigating the costs in a distributed system and it is widely acceptable that a major bottleneck in distributed execution is the communication among worker nodes. Therefore, people try to devise algorithms that try to eliminate this cost as much as possible, hence HyperCube and its variations, whose aim is to reduce communication rounds to a minimum.

To summarize, single round execution means that each worker will send data to other workers only once, hence the single communication round, followed by the complete evaluation of the multi-attribute JOIN producing the final result.

#### Multi round

Multi round execution refers to the evaluation of complex queries by processing a fraction of the query in each round until the whole query has been processed. For example, if the query requires joining on 3 attributes we could either have an execution that evaluates the two joins in the first round and the last one in the third round or we could even have three rounds evaluating a single join in each round.

With multi round execution one can investigate more complex topics like query decompositions into smaller queries that are easier to evaluate in separate rounds, that at the same time do not necessarily need to be single attribute JOIN operations.

However, D-FDB at the moment only supports concunctive queries (JOIN operations) and a multi-round execution evaluates one join at a time.

### Query execution phase

In this section we will describe how the above two modes are implemented in the proposed distributed system, what are their limitations and how can they improved.

Query processing and result evaluation corresponds to _Stage 3_ as described in the _System protocol_. Details about the query and the cluster topology are specified in configuration files (will be described in the next section).

First, we present the steps taken to process a single round evaluation and then explain how D-FDB builds on-top of that to provide multi round execution.

Each worker has three threads running, as previously described, main execution thread, ReaderData for receiving data and WriterData for sending data.

1. execution thread starts loading the input factorization in memory (using the configuration files to locate them)
2. it then signals ReaderData to start accepting factorizations from other workers and passes the input factorization to WriterData in order to begin writing data to other workers
3. once all factorizations from other workers have been received, the empty ones are dropped and the valid ones are passed over to the main execution thread. Then the special *merge\_same* operator is used to merge the partial factorizations received into a single factorization (recall that all factorizations sent in the same round use the same f-tree)
4. the last step of the processing uses the *f-plan executor* in order to evaluate the query specified in the query configuration file on the local factorization and produce the factorization result
5. finally, each worker notifies master node that the query has been completely evaluated

The multi round execution is similar, and pretty much wraps steps 1 to 4 into a loop, one iteration for each round, where the input for the first round is loaded from local storage and in consecutive rounds we use the result of the previous round as input to the next round.

### Configuration files

In this section we briefly present the two main configuration files used that specify the network topology and the query to be evaluated.

#### Settings configuration

```
#########################################################################
###### LINES STARTING WITH '#' or whitespace are skipped during parse!
#########################################################################

# number of nodes in the network
4
# all the IPs for each worker node (IP or IP:PORT format supported)
# each node will also receive an identification ID (uint32_t) based on its order
xxx.1.xxx.36:11110
xxx.1.xxx.39:11110
xxx.1.xxx.60:11110
xxx.1.xxx.65:11110

# specify the master node (IP or IP:PORT format supported)
xxx.1.xxx.36:11100

# now the query path follows
/home/lambros/dist-execution/dist_query.conf

# order of communication - data distribution
# we follow a cyclic (shifting policy)

# WRITING ORDER - we will have N lines, one line for each node that defines
# how that node should send its data
1 2 3
2 3 0
3 0 1
0 1 2

# READING ORDER - we will have N lines, one line for each node that defines
# how that node should read data
3 2 1
0 3 2
1 0 3
2 1 0
```

The excerpt above is part of a sample settings configuration file that contains all the required information about the network topology of our cluster of nodes. It starts by mentioning the number of worker nodes in the cluster, followed by their IPs. Recall that you can use different ports on the same machine to simulate different nodes. In the next line (next line not comment) we specify the master node. The master node is **required** to have a different port than _ALL_ the worker nodes but is not required to have different IP, thus being on different machine.

A path to the query configuration to be evaluated is provided in the next line and finally we have the communication ordering as explained in **Section P**. Briefly, for the writing ordering we have one line for each node that defines the order in which the node should read data from, and for the reading ordering there is a line for each node that defines the order in which the reads should be made.

In this simple example the ordering could be determined dynamically in runtime since it follows a pattern, but we decided to keep it in the settings file in case we want to try different orderings in the experimental evaluation, thus avoiding source code changes.


#### Query configuration

```
#########################################################################
###### LINES STARTING WITH '#' or whitespace are skipped during parse!!!
#########################################################################

# number of input factorizations
1
# all the paths to the factorizations (serializations) to be used as input
# ---- NOTE::: if the node does not find the path specified it will try to
#           load the path suffixed with '-n-NODE_ID-' before the extension
# i.e.
#       serialization.dat => if this does not exist it will try to load
#       serialization-n-1.data
#
/home/lambros/dist-datasets/somedataset/nodes_4/input-groot.dat

# now we have F-PLANS for the input
# each F-PLAN should have a single line with an integer N that specifies the
# number of lines describing the F-PLAN and then N lines with actions

# F-PLAN for factorization A
0

# final F-PLANs to be applied on the inputs
# number of plans (each plan for each communication round)
1

7
merge ksnid_1 ksnid_2
merge ksnid_1 ksnid_3
merge ksnid ksnid_1
merge locn_1 locn_2
merge locn_1 locn_3
merge locn locn_1
end

# Now we have the HyperCube configuration following
# a single line will contain all the attribute names of the combined result
# which will give each attribute a GLOBAL ID (their position in the line)
# which is used internally to map the attributes from local representations.
# the attributes as would specified in a global f-tree
# A,B,C,D,E,F
date,locn,ksnid,inventoryunits,salenbr,datesales,locn_3,loyalty,ksnid_3,regprice,units,locn_1,ksnid_1,mrkdnbegdt,mrkdnenddt,mrkdnamt,idpro,atvstadt,atvenddt,atvsts,ksnid_2,locn_2,__g_root_

# the hashed columns should be specified now starting from 0 to N using the
# GLOBAL IDs (position in the above line) (separated by space)
# (if there are more than 1 attributes that correspond to the same attribute
# logically but have different names just use one of them and group them below)
2 1

# the dimension for each hashed attribute (separated by space)
2 2

# group synonym attributes that have different names but are the same
# i.e. id_0, id_1, id_2 which can be renamed to avoid the limitation of FDB
# to handle same name attributes
#
# one number N specifies the number of these groups and then for each group we
# write the names of the attributes that are together.
# - each group should start with the attribute that was specified in the
# - hashed columns above!
2
ksnid,ksnid_3,ksnid_2,ksnid_1
locn,locn_3,locn_2,locn_1
```

In this section we present an example query configuration file.

We start by defining the path to the input factorization that will be loaded by each worker from its local srorage. A feature that we found useful to have is that if the path specified does not exist or fails to open, then each worker will try to load the path suffixed by its numeric ID. 

For example if the worker on node 2 tried to open the path on the above configuration file and failed, it will try to open the following path this time (note the _-2_ suffix):
```
/home/lambros/dist-datasets/somedataset/nodes_4/input-groot-2.dat
```

This little feature allowed us to have the input factorizations for all worker nodes in the same common directory and each node would end up loading the correct factorization, otherwise we would have to separately ship data to each node initially or use different configuration files at each worker.

The following group of options specifies an f-plan to be applied on the input right after loading it in memory, and consists of one line denoting how many lines follow with the f-plan operations.

In addition, we continue to the f-plans of the main query. The next line denotes the number of f-plans we want to evaluate. When this value is 1 we simulate Single round execution whereas when this value is more than 1 we simulate Multi round execution with each of the following f-plans be applied at the corresponding round.

The rest of the configuration is related to the HyperCube configuration. We start by enumerating all the attributes that exist in the factorizations we work with (they don't have to in any specific order and their order does not relate to the IDs they have inside their respective factorization f-trees).

Right below the attribute names, we specify the attributes to be hashed. Each hashed attribute is specified by using its position in the line before where all the attributes are enumerated. In the example above the hashed attributes are _ksnid_ and _locn_, hence the IDs 2 and 1. Moreover, the implementation of the Multi round execution uses one hashed attribute at each round, but can easily be extended to support arbitrary f-plan by adding more options to the configuration file.

Below the hashed attributes, we specify the dimension size for each of them. Each node will automatically get a multi-dimensional ID based on these dimensions.

The last lines make it easy for us to group different attribute names that refer to the same attribute together. We wanted this functionality since in HyperCube we want to use the same hash function for a specific hashed attribute, therefore we had to somehow group all the atribute names referring to _ksnid_ together and assign them a single hash function (seed index).

This concludes our configuration files regarding query execution.
