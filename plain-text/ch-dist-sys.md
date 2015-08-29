# Distributed query processing in FDB

In this section, we present the design and implementation of D-FDB, a distributed query engine that uses FDB [**REFERENCE**] for distributed query processing on factorized data. We describe how the system integrates the HyperCube[**Suciu**] algorithm for shuffling the data among workers and also describe how the system can be used for Single and Multi round executions, where single or multi refers to the number of communication rounds before the query is completely evaluated.

## Motivation

Distributed query processing has become an absolute necessity in today's DBMS systems. The reason is simple, once you cannot process your data using a single machine (data too large to fit in memory or query processing too slow) you either have to partition it and process one part at a time by storing intermediate results on disk or you do distributed processing. 

Utilization of many machines has become the de-facto way to scale services to support either huge number of requests or the so-called Big Data, meaning huge amount of data to be processed. There are a lot of existing systems that offer distributed query processing; almost all the current NoSQL database systems are layered upon a distributed scalable system in order to be able to achieve the high throughput and low latencies they advertise[**F1, MyriaDB, Couchbase, BigTable, DynamoDB**]. Therefore it is natural that FDB needs to support distribution and delegation of query processing to clusters of nodes in order to enable processing on Big Data and speed up complex queries that are too slow with single node processing.

This chapter describes D-FDB, a distributed query processing engine designed to work across a cluster of nodes, using the HyperCube algorithm to shuffle data among worker nodes and FDB query engine for query processing on each site on local data partitions.

## Contribution of this chapter

The contributions of this chapter are as follows:

1. Implementation of the HyperCube algorithm [**Suciu's paper and the others**] over factorizations for data shuffling in a cluster of nodes and its integration with the Bit Serializer as described in **Chapter X**, resulting in _Bit Serializer HyperCube_ which is used during distribution.
2. Design and implementation of an end-to-end distributed query engine that is able to receive a query, load the input from local storage at each site, distribute data over TCP, execute the query on received data using the existing FDB query engine, and finally gather results. Major differentiation of this system from existing ones is that we use factorizations end-to-end. _Factorization Input_ => _FDB Processing on factorized data_ => _Factorization Output_. 
3. Different distributed execution modes, namely Single round and Multi round execution. Single round execution only shuffles and transmits data between the nodes _once_ and then execute the whole query at the same time, whereas Multi round execution splits the query into individual JOINs and repeats the Single round execution for each partial query.
    D-FDB at the moment supports conjunctive queries (i.e. JOIN queries on one or many attributes). 

## HyperCube on factorizations

// see the ch-dist-sys-hypercube.md file

## System architecture

// see the ch-dist-sys-arch.md

# Query processing

// see the ch-dist-sys-exec.md
