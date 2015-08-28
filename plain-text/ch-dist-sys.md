# Distributed query processing in FDB

## Motivation

Distributed systems and distributed query processing has become an absolute necessity in today's DBMS systems. The reason is simple, once you cannot process your data using a single machine (data too large to fit in memory or query processing too slow) you either have to partition it and process one part at a time by storing intermediate results on disk or you do distributed processing. 

Utilization of many machines has become the de-facto way to scale services to support either huge number of requests or the so-called Big Data, huge amount of data to be processed. There are a lot of existing systems that offer distributed query processing; almost all the current NoSQL database systems are layered upon a distributed scalable system in order to be able to achieve the high throughput and low latencies they advertise. Therefore it is natural that FDB needs to support distribution and delegation of query processing to clusters of nodes in order to enable processing on big data and speed up complex queries that are too slow with single node processing.

This chapter contains description of a system designed to work across a cluster of nodes, using the HyperCube algorithm to shuffle and distribute data and FDB query engine for query processing on each site with the local data partition.

## Contribution

1. Implementation of the HyperCube algorithm [**Suciu's paper and the others**] over factorizations for data shuffling and distribution and its integration with the Bit Serializer as described in **Chapter X**, resulting in _Bit Serializer HyperCube_ which is used during distribution.
2. Design and implementation of a distributed system that is able to receive a query, load the input from local storage at each site, shuffle and distribute data over TCP, execute the query on received data using the existing FDB query engine, and finally gather results. Major differentiation of this system from existing ones is that we use factorizations end-to-end. _Factorizations Input_ => _FDB Processing_ => _Factorizations Output_. 
3. Different distributed execution modes, namely Single round and Multi round execution. Single round execution only shuffles and transmits data between the nodes _once_ and then execute the whole query at the same time, whereas Multi round execution partitions the query into smaller segments and repeats the Single round execution for each query segment.

## HyperCube on factorizations

// see the dist-sys-hypercube.md file


