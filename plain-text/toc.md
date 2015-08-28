
# Table of Contents

* Introduction

* Preliminaries (just briefly mention previous work ???)
    - introduce factorized databases and Hypercube (with Murmur hash functions etc). There, you need to cite relevant literature.

* Finding good Factorization trees (COST function)
    - COST function idea and algorithm
    - estimates calculation algorithm
    - example with a factorization (calculate estimates, and compute the estimated size with the COST function for several f-trees)

* Serialization of Factorized representation
    - Boost
    - Simple Serializer (Binary)
    - Byte Serializer (required bytes only)
    - Bit Serializer (required bits only)
        * Bitstream implementation

* Distributed system
    - Bit Serializer HyperCube (Bit Serializer extended with HyperCube filtering)
    - Single round vs Multi round (they have the same issues)
        * Multi round is like a repeat execution of Single round but for a subset of the query
        * emphasize that the f-plans in each round can be anything and the distribution of data is done on 1 attribute at a time (but can easily be extended)
    - master & worker design following custom protocol
    - Communication issues (Ordered reading and writing) and design with ReaderData and WriterData threads
    - execution phase details
        * Reading inputs, applying initial f-plans
            - maybe describe the merge under common root algorithm
        * Partitioning and distribution of data (single factorization message per node)
        * Merge received factorizations (describe the algorithm for merge_same_tree)
        * apply query f-plan for current round
        * repeat if in Multi round execution
    - describe dist\_settings.conf and dist\_query.conf files

* Experiments
    - COST function 
        *(traverse some f-trees in housing-1..8)
        * compare estimated sizes for several f-trees against the real size with those f-trees
    - Compression with serialization on housing-1..15
        * Sanity checks with in-memory and on-disk serialization => diff on enumeration + diff on factorization encoding
        * GZIP, BZIP2 min max, NONE on Serializers vs GZIP, BZIP2, NONE on FLAT 
    - Communication cost 
    - End-to-End Computation time (centralized FDB vs nodes 4, nodes 6, nodes 8)
        * whole execution phase monitored by Master node so the time is accurate end-to-end
        * each node reports its own times too

* Future Work
    - Extension to the Bit serializer to provide custom serializer for certain data types (negative numbers, doubles, strings) to allow further compression
    - Concurrency added to the serialization should be trivial since each branch of the root attribute can be serialized in parallel and then just stored in order
    - A lot of proposals regarding the communication during the execution of the distributed query
        * What f-tree should nodes send data with
        * What policy should the nodes follow when communicating ? Ordered vs Unordered vs Paired vs Random vs Round-Robin with partial data
        * Partial loading/deserialization of a serialized factorization up to the point when enough information is already in-place to execute the query
        * Distributed query just by communicating the Hashed-Attributes - which is going to be very time saving and should not be very difficult upon the existing distributed system!!!
