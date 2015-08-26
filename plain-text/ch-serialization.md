# Serialization of Data Factorizations

## Motivation

A very important part of the project investigated ways to serialize, and possibly compress, factorizations (f-representations). It is very important to support serialization and deserialization of a factorization both in a centralized setting and in a distributed setting. For example, sometimes we want to save an instance of a database on disk to manipulate and further process it later. In some other cases we want to ship data over the wire to neighboring PC nodes which need the data for additional processing on their side. 

In general, serialization is the method of efficiently converting an in-memory factorization into a series of bytes which is stored or transferred and later can be deserialized into the exact source factorization.
An important aspect of serialization and deserialization is that it has to be efficient in both processing time and space (output size) since we want to retain the major benefit of factorizations, which is the compressed size compared to corresponding flat representations. Thus, having a serialization that would take a lot of space or requiring a lot of time to process would be inappropriate for our setting, especially the distributed system which is the goal of this thesis.

## Contributions

// **TODO** 

## Factorization Serialization

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

The factorization tree is the back-bone component of a factorization since it defines the structure of the representation and all the relations beteen the attributes of the query.
The serialization of an f-tree is the same for all the following different factorization serialization techniques and is implemented as a separate module since it is a very small data structure (around a few KBs) and we do not mind using the simplest serialization for it.

I decided to use the same structure as an f-tree definition file for its serialization too. As a result, the serialization of the f-tree show in **FIGURE OF F-TREE ABOVE** is as follows:
```
6 4
A int
B int
C int
D int
E int
F int
-1 0 1 1 0 4 
R S T U 
2 3 4 5 
A,B,C
A,B,D
A,E
E,F
```

The first line defines the number of attributes (N) and relations (M) in the f-tree, followed by N lines declaring the name of each attribute and its data type. 
The current FDB implementation assigns IDs to the attributes in the order they are defined here with the first attribute (A in this case) being given ID 0 (zero) and the last attribute (F in this case) being given ID 5 (N-1).
The next line defines the tree-relationship since for each attribute we specify the ID of its parent attribute. A has parent ID -1 which means A is root, then B has parent ID 0, C has parent ID 1, D has parent ID 1, E has parent ID 0 and F has parent ID 4.

Then we similarly have a line containing the relation names, again being given IDs internally, with the following line specifying for each relation its parent attribute node.

The last M lines are just the relations enumeration with their attributes.

The serialization of an f-tree uses **Text** format and it is prefixed with its size length to allow the deserializer to know up-front the total f-tree serialization size in order to read all the information at once.

The serialized f-tree (including its size header) is prefixed in the final serialization of the Data Factorization such that it can be deserialized first.

### Boost Serialization

As a first attempt to provide serialization/deserialization I decided to use **Boost::Serialization** library since it gathered high rating reviews among the online community and since I was already using _Boost_ for the networking modules of the system it seemed to be a great fit. 
The purpose of _Boost::Serialization_ library is to allow developers to provide an easy way to add serialization to their **existing** data structures without writing a lot of boilerplate code since it can be described more or less like a memory dump of a data structure into a stream, which can be anything from a file, to a socket, etc.

The integration of the library in FDB and the actual implementation was pretty straightforward and was done in a few days, since I just had to add couple of _special_ methods in each class required to be serialized according to certain library rules. However, the end result was really bad and disappointing.

As I mentioned, this is more like a memory dump of the structure, including any pointers and their destination objects, in order to easily allow the deserializer to create the exact data structure. The major problem here and the reason of the bloated serialized output is that the existing _FDB_ implementation is not as space-efficient as it should be and that overhead is transferred into the serialization. 
The current data structure of an f-representation has a lot of overhead, including many unneccessary fields, keeping all the values of a Union for example as a Double-Linked-List thus introducing excessive amount of pointers and many more. As a result, the serialization module was dumping everything, more importantly the pointer references, to allow re-creation during deserialization leading to a bloated outcome, both in terms of raw size in bytes but also in long serialization times. 

In my first preliminary experiments the serialized representation was almost the same size as the flat-relational representation, thus completely eliminating the compression factor of FDB over flat databases, which was unacceptable!

In order to use _Boost::Serialization_ and at the same time having quality serialization I had to write custom code for each implementation class for every data structure we use to omit certain fields or doing my own book-keeping for the pointers and references to avoid all this going into the serialized output.
It didn't worth it since Boost was still going to add some overhead which cannot be removed, like class versioning etc.

My **first attempt failed** but led to some interesting observations. Although the current implementation was poorly done, a good serialization does not need all that information and we could also take advantage of the special structure of a factorization to make it as succinct as possible.

### Simple Binary (De)Serializer

Before going into details for this serialization technique I want to state some observations made clear after my serialization version.

* Each f-representation is strictly associated with a factorization tree (f-tree) that defines its structure
* The main types of a node in a factorization are the Multiplication (cross product) and the Summation (union) node types
* The values inside a union node can be stored in continuous memory, thus avoiding the excessive overhead of Double-Linked-Lists due to the pointers for each value

Apart from the above observations, the trick that led to this serialization method is that the only nodes required to be serialized are **Union** nodes along with their values. Since each factorization strictly follows an f-tree, it seemed obvious and very beneficial for me to use the f-tree as a guide during serialization and deserialization leading to a more succinct outcome which just contains the absolute minimum of information, _the values_!

The problem with generic serialization techniques, like _Boost_ described above is that all information goes into the serialized outcome to allow correct deserialization. We can avoid this overhead in our case since we know the special structure of the factorization and therefore we can use the f-tree to infer the structure of the representation and load the values from the serialized form as we go along during deserialization.

#### Main Idea

The main idea of **Simple Serializer** is that we traverse the f-representation in a DFS (Depth-First-Search) order and every time we find a _Union_ node we serialize it, then continue.
The serialization of a union node is extremely simple and just contains a number N indicating the number of values in that specific union, followed by N values of the attribute represented by that union.

For example, if a specific union of attribute A (of type _int_) has the values [3, 6, 7, 8, 123, 349], its serialization would be:
```
6 3 6 7 8 123 349
```

It is important to mention that I use **binary** read and write methods during serialization and deserialization and for each children count I use 32-bit unsigned integer values whereas for the actual values I use the corresponding number of bytes required for that attribute data type (i.e. _double_ = sizeof(double) = 8 bytes).

The serialization of a factorization is just a sequence of _children counts_ followed by their corresponding values. As I said, the important benefit of this serialization technique is that I just store the absolute minimum information required to recover the representation.

Moreover, **Simple Serializer** assumes that we already deserialized the Factorization Tree (discussed previously) and we can use it to infer the structure of the representation.

#### Algorithms

**Simple Serializer**

```
// @node: the starting node of our serialization (usually the root of the factorization)
// @fTree: the factorization tree to be used as guide 
// @out: the outpout stream to write the serialization (file, socket, memory stream, etc.)
dfs_save(FRepNode *node, FactorizationTree *fTree, ostream *out) {
    Operation *op = (Operation*)node; 
    
    if (is_multiplication(op)) {
        // in multiplication nodes we just recurse without serializing 
        for each child attribute CA in op->children {
            dfs_save(CA, fTree, out);
        }
    } else if (is_union(op)) {
        // in union we serialize the number of children and values
        
        // serialize union children count
        write_binary(out, op->childrenCount);
        
        // serialize union values
        for each child value V in op->children {
            write_binary(out, V);
        }

        // recurse only if the union's attribute is not leaf in the f-tree
        if (!is_leaf_attribute(fTree, node->attributeID)) {
            for each child value CV in op->children {
                dfs_save(CV, fTree, out);
            }
        }
    }
}
```

_Simple Serializer_ is an extension of the well-known DFS traversal algorithm with in-order value processing. 
The representation has two types of nodes, thus leading to two different treatments in serialization. When a _multiplication_ node is encountered the algorithm recurses on its descendants without serializing anything since the multiplication information can be inferred from the f-tree. When a _union_ node is encountered we first serialize the number of values in that union, followed by the serialization of all the values. At the end we recurse on each of child to complete the DFS-traversal.

I want to mention that we iterate over the values twice since we want to serialize _all_ the values of a union completely and _then_ move on to the next union, like in an in-order traversal. Additionally, we use the f-tree to determine if a union belongs to an attribute which is _leaf_ in the f-tree to avoid recursing unnecessarily.

















