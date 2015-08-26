# Serialization of Factorized Representations

## Motivation

A very important part of the project investigated ways to serialize, and possibly compress, f-representations (factorizations). It is very important to support serialization and deserialization of a factrorization both in a centralized setting and in a distributed setting. For example, sometimes we want to save an instance of a database on disk to manipulate and further process it later. In some other cases we want to ship data over the wire to neighboring PC nodes which need the data for additional processing on their side. 

In general, serialization is the method of efficiently converting an in-memory factorization into a series of bytes which is stored or transferred and later can be deserialized into the exact source factorization.
An important aspect of serialization and deserialization is that it has to be efficient in both time and space since we want to retain the major benefit of f-representations, which is the compressed size compared to corresponding flat representation. Thus, having a bad serialization that would take a lot of space or requiring a lot of time to process would be inappropriate for our setting, especially the distributed system which is the goal of this thesis.


## Serialization attempts

In this section I will describe the different approaches I have taken for the serialization leading to the final version used in the distributed system.

```
//////////////////////////////////////////////
<IMAGE_OF_A_FACTORIZATION_TREE_HERE>
/////////////////////////////////////////////
```
```
//////////////////////////////////////////////
<IMAGE_OF_A_REPRESENTATION_HERE_FOR_THE_TREE>
/////////////////////////////////////////////
```

### Factorization Tree serialization

// **TODO**

### Boost Serialization

As a first attempt to provide serialization/deserialization I decided to use **Boost::Serialization** library since it gathered high reviews in the online community and since I was already using _Boost_ for the networking modules of the system it seemed to be a great fit. 
The purpose of _Boost::Serialization_ library is to allow developers to provide an easy way to add serialization to their **existing** data structures without writing a lot of boilerplate code since it can be described more or less like a memory dump of the structure into a stream, which can be anything from a file, to a socket, etc.

The integration of the library in FDB and the actual implementation was pretty straightforward and was done in a few days, since I just had to add couple of _special_ methods in each class required to be serialized according to certain library rules. However, the end result was really bad.

As I mentioned, this is more like a memory dump of the structure, including any pointers and their destination objects, in order to easily allow the deserializer to create the exact data structure. The caveat here is that the existing _FDB_ implementation is **very bad**! I really can't emphasize this enough. 
The current data structure of an f-representation has a lot of overhead, including many unneccessary fields, keeping all the values of a Union for example as a Double-Linked-List thus introducing excessive amount of pointers and many more. As a result, the serialization module was dumping everything, more importantly the pointers structure, to allow recreation during deserialization leading to a bloated outcome, both in terms of raw size in bytes but also in long serialization times. 

In my first preliminary experiments the serialized representation was almost the same size as the flat-relational representation, thus completely eliminating the compression factor of FDB over flat databases, which was unacceptable!

In order to use _Boost::Serialization_ and at the same time having quality serialization I had to write custom code for each implementation class for every data structure we use to omit certain fields or doing my own book-keeping for the pointers and references to avoid all this going into the serialized output.
It didn't worth it since still there was going to be some overhead added by Boost which cannot be removed, like class versioning etc.

My **first attempt failed** but led to some interesting observations. Although the current implementation was poorly done, a good serialization does not need all that information and we could also take advantage of the special structure of a factorization to make it as succinct as possible.

### Simple Binary Serializer

Before going into details for this serialization technique I want to state some observations made clear after my serialization version.

* Each f-representation is strictly associated with a factorization tree (f-tree) that defines its structure
* The main types of a node in a factorization are the Multiplication (cross product) and the Summation (union) node types
* The values inside a union node can be stored in continuous memory, thus avoiding the excessive overhead of Double-Linked-Lists due to the pointers for each value

Apart from the above observations, the trick that led to this serialization method is that the only nodes required to be serialized are **Union** nodes along with their values. Since each factorization strictly follows an f-tree, it seemed obvious and very beneficial for me to use the f-tree as a guide during serialization and deserialization leading to a more succint outcome which just contains the absolute minimum of information, _the values_!

The problem with generic serialization techniques, like _Boost_ described above is that all information goes into the serialized outcome to allow correct deserialization. We can avoid this overhead in our case since we know the special structure of the factorization and therefore we can use the f-tree to infer the structure of the representation and load the values from the serialized form as we go along during deserialization.

#### Main Idea

The main idea of **Simple Serializer** is that we traverse the f-representation in a DFS (Depth-First-Search) order and every time we find a _Union_ node we serialize it, then continue.
The serialization of a union node is extremely simple and just contains a number N indicating the number of values in that specific union, followed by N values of the attribute represented by that union.

For example, if a specific union of attribute A (of type _int_) has the values [3, 6, 7, 8, 123, 349], its serialization would be:
```
6 3 6 7 8 123 349
```

It is important to mention that I use **binary** read and write methods during serialization and deserialization and for each children count I use 32-bit unsigned integer values whereas for the actual values I use the corresponding number of bytes required for that attribute data type (i.e. _double_ = sizeof(double) = 8 bytes).

Now you can imagine that the serialization of a factorization is just a sequence of _children counts_ followed by the corresponding values. As I said, the important benefit of this serialization is that I just store the absolute minimum information required to recover the representation.

**Simple Serializer** assumes that we already deserialized the Factorization Tree (discussed previously) and we can use it to infer the structure of the representation.

#### Algorithms

**Simple Serializer**

```
// @node: the starting node of our serialization (usually the root of the representation)
// @fTree: the Factorization Tree to be used as guide 
// @out: the outpout stream into which we will write the serialization (can be file, socket, memory stream, etc.)
dfs_save(FRepNode \*node, FactorizationTree \*fTree, ostream \*out) {
    Operation \*op = (Operation\*)node; 
    
    if (is_multiplication(op)) {
        // in multiplication nodes we just recurse without serializing 
        for each child attribute CA in op->children {
            dfs_save(CA, fTree, out);
        }
    } else if (is_union(op)) {
        // in union we serialize the number of children and values
        
        // serialize children count
        write_binary(out, op->childrenCount);
        
        // serialize values
        for each child value V in op->children {
            write_binary(out, V);
        }

        // recurse only if not leaf nodes
        if (!is_leaf_attribute(fTree, node->attributeID)) {
            for each child value CV in op->children {
                dfs_save(CV, fTree, out);
            }
        }
    }
}
```

Simple serializer extends a DFS traversal on the representation. I just want to mention that we iterate over the values twice since we want to serialize _all_ the values of a union completely and _then_ move on to the next union, like in an in-order traversal!
















