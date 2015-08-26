
# Table of Contents

* Introduction

* Background (just briefly mention previous work ???)

* Finding good Factorization trees (COST function)
    - COST function idea and algorithm
    - estimates calculation algorithm

* Serialization of Factorized representation
    - Boost
    - Simple Serializer (Binary)
    - Byte Serializer (required bytes only)
    - Bit Serializer (required bits only)
        * Bitstream implementation
    - Bit Serializer HyperCube (Bit Serializer extended with HyperCube filtering)

* Distributed system
    - Single round vs Multi round (they have the same issues)
        * Multi round is like a repeat execution of Single round but for a subset of the query
        * emphasize that the f-plans in each round can be anything and the distribution of data is done on 1 attribute at a time (but can easily be extended)
    - Communication issues (Ordered reading and writing)
    - design with ReaderData and WriterData threads
    - master & worker design following custom protocol
    - execution phase details
        * Reading inputs, applying initial f-plans
            - maybe describe the merge under common root algorithm
        * Partitioning and distribution of data (single factorization message per node)
        * Merge received factorizations (describe the algorithm for merge_same_tree)
        * apply query f-plan for current round
        * repeat if in Multi round execution
    - describe dist\_settings.conf and dist\_query.conf files

* Experiments
    - COST function (traverse some f-trees in housing-1..8)
    - Compression with serialization on housing-1..15
        * GZIP, BZIP2 min max, NONE on Serializers vs GZIP, BZIP2, NONE on FLAT 
    - Communication cost 
    - End-to-End Computation time (centralized FDB vs nodes 4, nodes 6, nodes 8)
