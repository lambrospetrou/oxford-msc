# Distributed query processing in FDB

## Motivation

Distributed systems and distributed query processing has become an absolute necessity in today's DBMS systems. The reason is simple, once you cannot process your data in a single machine (too large or too slow) you either have to process it fraction-at-a-time by storing intermediate results on disk or you do distributed processing. 

Utilization of many machines has become the de-facto way to scale services to support either huge number of requests or the so-called Big Data. There are a lot of existing systems that offer distributed query processing; almost all the current NoSQL database systems are layered upon a distributed scalable system in order to be able to achieve the high throughput and low latencies they advertise. Therefore it is natural that FDB needs to support distribution and delegation of query processing to a cluster of nodes in order to enable processing on big data or speed up complex queries that are too slow with single node processing.

This chapter contains description of a system designed to work across a cluster of nodes, using the HyperCube algorithm to shuffle and distribute data and FDB query engine for query processing on each site with the local data partition.

## Contribution

1. Implementation of the HyperCube algorithm over factorizations for data shuffling and distribution and integration of it with the Bit Serializer described in **Chapter X**.
2. Design and implementation of a distributed system that is able to receive a query, load the input from local storage, shuffle and distribute data over TCP, execute the query on local data using the FDB query engine, gather results. Important point that differentiate this system from other existing ones is that we use factorizations end-to-end, input -> processing -> output.
3. Different modes of distributed execution, namely Single round and Multi round execution. Single round execution is when the system only shuffles and transmits data between the nodes once and then apply the whole query at the same time, whereas Multi round execution partitions the query into smaller segments and repeats the Single round execution for each query segment.


