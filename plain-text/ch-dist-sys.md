# Distributed query processing in FDB

## Motivation

Distributed systems and distributed query processing has become an absolute necessity in today's DBMS systems. The reason is simple, once you cannot process your data using a single machine (data too large to fit in memory or query processing too slow) you either have to partition it and process one part at a time by storing intermediate results on disk or you do distributed processing. 

Utilization of many machines has become the de-facto way to scale services to support either huge number of requests or the so-called Big Data, huge amount of data to be processed. There are a lot of existing systems that offer distributed query processing; almost all the current NoSQL database systems are layered upon a distributed scalable system in order to be able to achieve the high throughput and low latencies they advertise. Therefore it is natural that FDB needs to support distribution and delegation of query processing to clusters of nodes in order to enable processing on big data and speed up complex queries that are too slow with single node processing.

This chapter contains description of a system designed to work across a cluster of nodes, using the HyperCube algorithm to shuffle and distribute data and FDB query engine for query processing on each site with the local data partition.

## Contribution

1. Implementation of the HyperCube algorithm [**Suciu's paper and the others**] over factorizations for data shuffling and distribution and its integration with the Bit Serializer as described in **Chapter X**, resulting in _Bit Serializer HyperCube_ which is used during distribution.
2. Design and implementation of a distributed system that is able to receive a query, load the input from local storage at each site, shuffle and distribute data over TCP, execute the query on received data using the existing FDB query engine, and finally gather results. Major differentiation of this system from existing ones is that we use factorizations end-to-end. _Factorizations Input_ => _FDB Processing_ => _Factorizations Output_. 
3. Different distributed execution modes, namely Single round and Multi round execution. Single round execution only shuffles and transmits data between the nodes _once_ and then execute the whole query at the same time, whereas Multi round execution partitions the query into smaller segments and repeats the Single round execution for each query segment.

## HyperCube on Factorizations

In this section, we briefly introduce the HyperCube algorithm [**REFERENCE**] that previous work has shown to be great solution for data shuffling in distributed query processing. In addition, an algorithm is provided that describes how HyperCube is adapted on Factorizations and finally, how we integrated it with the _Bit Serializer_, see **Section X**, resulting in a new serializer dedicated in HyperCube coined _Bit Serializer HyperCube_.

### HyperCube introduction

**BLAH BLAH**

### Bit Serializer HyperCube

_Bit Serializer HyperCube_'s main purpose is to be used during the communication stages in FDB distributed query processing. Each node needs to send data over the wire to other nodes, therefore we use this special serializer to take into account the HyperCube configuration used and serialize only the fraction of the factorization required.

#### Arguments

_Bit Serializer HyperCube_ was designed to accept the following arguments:

1. the factorization to be serialized
2. a bitset or vector (array) with size the number of attributes in the factorization (1) which has its bits _set_ for each attribute ID that is to be hashed 
3. a vector (array) with size the number of attributes in the factorization (1) which in each position has the node's ID for that dimension

![alt text][cost_ftree]
[cost_ftree]: cost-tree.png "Simple Factorization Tree"
**Figure X.1 - a simple factorization tree.**

For example, let's examine the f-tree in **Figure X.1**. 

This f-tree has six attributes, and each attribute internally gets an ID ranging from zero to (N-1), where N in this case equals six. Assume that the IDs for these attributes are as below:

```
ID(A) = 0
ID(B) = 1
ID(C) = 2
ID(D) = 3
ID(E) = 4
ID(F) = 5
```

Moreover, let us consider that we want to use HyperCube and hash on attributes _A_ and _E_, and that our cluster contains 6 nodes.

There are four possible HyperCube configurations in order to use all nodes, all shown below. Notation _K x M_ means that we assign a dimension of size _K_ to attribute A and a dimension of size _M_ to attribute E.

```
Conf 1: 1 x 6
Conf 2: 6 x 1
Conf 3: 2 x 3
Conf 4: 3 x 2
```

In addition, each node will be assigned a **multi-dimensional ID** based on the HyperCube configuration used. For this example, let's use third HyperCube configuration (Conf 3), thus creating the node IDs below (basically we iterate over all possible values in each dimension).

```
Node 1: [0, 0]
Node 2: [0, 1]
Node 3: [0, 2]
Node 4: [1, 0]
Node 5: [1, 1]
Node 6: [1, 2]
```

Now that all the information is explained let us see the actual arguments used by _Bit Serializer HyperCube_ for this specific example.

1. factorization to be serialized

2. a bitset of size six with the bits _set_ for attributes A and E
    ```
    [ 1 0 0 0 1 0 ]
    ```

3. for each node we call the serialize method of the serializer passing in the multi-dimensional node ID expanded to have size of N. 
For example, when we want to serialize for node 6 the following vector ID is used:
    ```
    [ 1 0 0 0 2 0 ]
    ```
    
    and when we want to serialize for node 2 the following vector ID is used:
    ```
    [ 0 0 0 0 1 0 ]
    ```

As you can see each node's expanded ID is a vector of size N (number of attributes). Each position _T_ in this vector either has zero if attribute with ID T is _NOT_ among the hashed attributes or has the node's ID in dimension T as specified in the node's multi-dimensional ID.

#### Hashing and HC_Params

HyperCube's performance gains depend on value hashing and proper use of hash functions. In this project we decided to use the same hash functions as existing work that showed good results [**Suciu**] in order to allow us to compare in the future our results with theirs.

The hashing library used is **MurmurHash3** which is open-source and available online. This libary provides methods that given a series of bytes create hash values of size 128-bits and 32-bits. We decided to use the 128-bit version and just use the first 64-bits (starting from the Least-Significant-Bit).

Additionally, these hash functions accept a _seed index_ as argument which affects the result hash values. In order for the HyperCube to work as expected we need to use the **same** seed index for attributes that are to be joined together, or attributes that are named differently in the factorization but represent the same logical attribute. In addition, it would be better to use different seed indices for different joined attributes to avoid distribution issues that might result in skeweing of data partitioning and shuffling. Therefore, we have a pool of some seed indices that are given to each hashed attribute (seeds taken from online prime number resources and previous work on HyperCube).

**HC_Params**

The structure **hc_params** is the structured passed in the serialize function of _Bit Serializer HyperCube_ and contains the three arguments described in the previous **Section XX** and allows the serializer to use the right hash function for each attribute value during validity check.

#### Algorithms

In this section we present the algorithms behind bit serialization using HyperCube _filtering_.

Recall, that HyperCube shuffling hashes the value in each _hashed attribute_ and based on these hashed values sends the whole tuple to the nodes that have their multi-dimensional IDs matching the hashed values, attribute-wise (the hashed value of a column has to match the node's dimension ID on that column).

HyperCube implementation in flat databases handles tuple as a whole, therefore can apply hash functions in all the required attributes and find the matching nodes for the tuple instantly. In our case, factorizations, do not have all the information about a tuple in a single place since each tuple is assembled by retrieving a value from each attribute union along the factorization.

![alt text][cost_frep]
[cost_frep]: cost-rep.png "Simple Factorization"
**Figure X.2 - a simple data factorization.**

A naive approach would traverse the factorization, hash the values in each union and send them to each node that matches the hashed value in its multi-dimensional ID. This would lead to incorrect results since a single attribute union cannot determine the destination nodes. In order to be able to decide whether each value in a factorization should be sent to each node we have to make sure that the value exists in at least one tuple that is valid for that node, and we cannot know that before traversing all attribute unions in the factorization.

As a result, our algorithm consists of two phases, namely the **masking phase** and the **serialization phase**. During the _masking phase_ we create bitset masks for each union denoting whether each value is valid to be sent to the examined node, and during the _serialization phase_ the valid values are serialized in the exact way _Bit Serializer_ works, see **Section X.Y**.

An important optimization we noticed in the algorithm is that during the second phase there is no need to visit unions that do not have any valid values to be serialized. Therefore, a is lot of gain time-wise since we might skip complete branches from the top-most point we notice that a value is invalid.

For example, assume we are serializing the factorization seen in **Figure X.2** and the node we examine has the multi-dimensional ID `[ 1 0 0 0 1 0]`. If the value **a1** hashes into zero (0) then we know that the whole branch under _a1_ should not be visited since it will be not serialized for this node.

It is very important to distinguish between deciding if a value is _valid_ for a node and when it is not. When we are at a union examining the values to be serialized we can reject a value instantly if it does not hash to the proper value to match the node's multi-dimensional ID, thus complete subtrees, but we cannot know for sure if it is valid unless we examine its entire subtree. For example, if _a1_ hashes into one (1) which is valid it might still be invalid for the node we examine if _e2_, which is the other hashed attribute in our example case, does not hash into this node's dimension ID.

In order to make use of this opportunity to skip subtrees we have to keep-track of which values are valid in each union. One way was to create a virtual layer upon the factorization that kept this information, but since this would be inefficient, we decided to use a **vector** to hold each union's state. The states inside the vector after the _masking phase_ is finished should be in the order we are going to visit the valid unions during the serialization phase, which is not too difficult to maintain since we are doing a DFS traversal in both cases.

In the rest of this section we will provide and explain the algorithms for the two phases that implement the _Bit Serializer HyperCube_. As can be seen from the code, we included the masking phase into the first round of _Bit Serializer_ that gathers statistics about maximum values and bits required, therefore we still only do two passes over the factorization.

**Masking phase - statistics gathering - first pass**

```
// Algorithm: dfs_statistics

// @node: a node in the factorization to start serialization (initially root)
// @fTree: the f-tree used by the current factorization
// @hc_p: the HyperCube parameters as defined in **Section X.Y**
//
// @return: True iff *node contains values to be serialized
bool dfs_statistics(FRepNode *node, FactorizationTree *fTree, hc_params *hc_p) {
    // we only serialize Union nodes so we know this is an Operation node
    Operation *op = (Operation*)node;
    
    if (is_multiplication(op)) {
        if (op->children is empty) return false;
        bool valid_child = true;
        for each child attribute CA in op->children {
            // recurse on each union and make sure all of them are valid
            valid_child &= dfs_statistics(CA, fTree, hc_p);
            if (!valid_child) return false;
        }
        return true;
    } else if (is_union(op)){
        // special treatment for unions since they contain the values to be hashed
        return handle_union(op);
    }
}

//
// @mMasks: class field - vector that contains the bool masks for each union 
//
// @op: the union node in the factorization to gather statistics
// @fTree: the f-tree used by the current factorization
// @hc_p: the HyperCube parameters as defined in **Section X.Y**
//
// @return: True iff *op contains values to be serialized
bool handle_union(FRepNode *node, FactorizationTree *fTree, hc_params *hc_p) {
    // add our bitmask into the states vector
    mMasks.push_back();
    // keep reference to our state's position in the vector
    iMask = mMasks.size() - 1;

    // now we check each value if it is valid and if yes make sure
    // that its subtree has a valid result too before masking it valid
    for each value child CV in op->children {
        // make sure that the value hashes to the right Node dimension ID
        // if this union is of a hashed-attribute otherwise the value is 
        // always valid and will be serialized
        if (is_valid_value(CV, hc_p)) {
            if (is_leaf_attribute(op->attributeID, fTree)) {
                // leaf attribute means valid value instantly
                mMasks[iMask].push_back(true);
                // also gather statistics about required bits
                update_required_bits(CV);
            } else {
                // this is not a leaf union so we have to make sure
                // that the subtree contains valid values too
                if (dfs_statistics(CV, fTree, hc_p)) {
                    // finally valid value
                    mMasks[iMask].push_back(true);
                    update_required_bits(CV);
                } else {
                    // the value's subtree is invalid so the value is too
                    mMasks[iMask].push_back(false);
                }
            }
        } else {
            mMasks[iMask].push_back(false);
        }
    } // end for each value child

    // count the valid children
    valid_children = count(mMasks[iMask], true);

    // make sure that we have valid values to serialize otherwise
    // we have to return false such that our parent knows we are invalid
    if (valid_children == 0) {
        // remove our state from the masks vector and all of our descentants
        mMasks.resize(iMask);
        return false;
    }

    update_required_union_bits(valid_children);
    return true;
}
```

Entry point of the _masking phase_ is the **dfs_statistics()** method which is called initially with the root of the factorization and recursively visits all other nodes.

As previously explained, the algorithm cannot determine if a node or value is valid without recursing on its subtree. We also differentiate the two scenarios, a) Multiplication nodes from b) Union nodes in the factorization. When the current node is multiplication we want to make sure that we have valid values in **ALL** the subtrees since a tuple is assembled by the product of these subtrees, thus one of them being empty means no result. If the current node is a union it is treated separately by the **handle_union()** method.

Let us delve into the union handling. First of all, we have to create a union state and put it in the masks vector recording its index position. The reason we want to use an index and we don't always refer to the top state is that we will recurse again so possibly another state will be pushed, hence we need a safe way to access the state for the current union.

The logic behing HyperCube is in the lines following where we iterate over all the current union's values (**Lines XX**). For each value _CV_ we first check if it is a valid value. The validity of a value depends on whether this is a union of a hash-attribute or not. If it isn't then the value is valid, otherwise the hashed value is checked against the multi-dimensional ID of the node (use of the *hc_params*). If the value is not valid then we append into our mask-state a _false_ bit and continue to the next child immediately, thus skipping its subtree. If the value itself is valid, then we have to make sure that its subtree is valid before marking it as _true_, therefore if there is a subtree (not leaf attribute) we recurse and check the returned result for success and mask the current value accordingly.

Whenever the value is valid, we also calculate and update the required bits required for that attribute. When all the children have been processed we have to ensure that this union has at least one valid value, otherwise it should not be serialized. If it has not, then we return false. It is very important to understand the reason why the states vector is being resized to match the current union's index (_iMask_). Observing the traversal over the values and the recursion calls it is easy to see that we do a DFS-like traversal over the factorization. However, not all nodes will be visited since at any point one node might be invalid and therefore instantly return false to its parent, hence propagating the failure upwards to the current union. Therefore the number of states pushed into the masks vector is undetermined and can range from _zero_ to the _number of nodes in the subtree_ of each value. When the current union is invalid (children list empty) it means that none of our valid children (if any) will be serialized in the result, therefore their states need to be removed from the vector. 

During the serialization process we do a DFS traversal on the factorization and each time a union node is encountered we get the first available state from the vector and serialize recursively only the valid values. Therefore, the states vector should only contain masks for the unions that are valid to be serialized and in the order they will be serialized.

To complete the union handling, the function just updates the required bits for the union children counter in case it is valid and return success to its caller.

**Serialization phase - second pass**

The second phase, the serialization, of our algorithm is identical to the second phase of the regular _Bit Serializer_. The only difference is that instead of serializing all the values in each union we use its mask state to identify the valid children and serialize those only. Respectively, recurse on them only. 
Each union just takes the next available mask state from the states vector, starting from index 0 moving upwards. 

**Complexity**

The complexity of serializing a factorization using _Bit Serializer HyperCube_ and _Bit Serializer_ is asymptotically the same. They both incorporate two passes over the whole factorization.

The HyperCube version, however, has the additional overhead of hashing the values in unions of hashed attributes which is constant overhead but stills adds up to the total processing time. Furthermore, this version might skip certain subtrees when values are invalid which can speed up the second phase significantly. Both points affect runtime of the HyperCube serialization but it strictly depends on each factorization's values and the number of hashed attributes whether it has better or worse performance.


#### Deserialization

_Bit Serializer HyperCube_ is perfectly compatible with the regular _Bit Deserializer_. Therefore one can use it to deserialize hypercube serializations into factorizations. This is how each node deserializes the data received into factorizations which are then being processed locally during the communication rounds in the FDB distributed query processing, see **Chapter U**. 
























