# Serialization of Data Factorizations

## Motivation

A very important part of the project investigated ways to serialize, and possibly compress, factorizations (f-representations). It is very important to support serialization and deserialization of a factorization both in a centralized setting and in a distributed setting. For example, sometimes we want to save an instance of a database on disk to manipulate and further process it later. In some other cases we want to ship data over the wire to neighboring PC nodes which need the data for additional processing on their side. 

In general, serialization is the method of efficiently converting an in-memory factorization into a series of bytes which is stored or transferred and later can be deserialized into the exact source factorization.
An important aspect of serialization and deserialization is that it has to be efficient in both processing time and space (output size) since we want to retain the major benefit of factorizations, which is the compressed size compared to corresponding flat representations. Thus, having a serialization that would take a lot of space or requiring a lot of time to process would be inappropriate for our setting, especially the distributed system which is the goal of this thesis.

## Contributions

The contributions made to the project out of this chapter are four (4) serialization techniques for Data Factorizations and one (1) serialization technique for Factorization Trees, namely:

1. Factorization Tree (de)serializer - this is the only serialization technique for f-trees and is used in conjuction any of the factorization serialization techniques
2. Simple (De)Serializer - a simple serialization technique that is fast and retains the compression factor over flat representations
3. Byte (De)Serializer - an extension to the Simple serialization technique to only store the required number of bytes for each value
4. Bit (De)Serializer - a further extension to Byte serialization to only store the required number of bits for each value, with specialized methods that can be extended in the future to better support more values to allow better compression
5. Bit Serializer HyperCube - the serialization technique that is used in the distributed system which differs from the normal Bit Serializer in that it does not ship all the values of a union but only those that should be shipped based on the Dimensions ID given (this will be explained thoroughly in chapter **XXX**).

I do not consider the Boost serialization technique as a contribution since it was an experiment that failed and later removed completely from the source code!

## Factorization Serialization

In this section I will describe the different approaches I have taken for the serialization leading to the final version used in the distributed system.

### Example we will use

Let us first define an example scenario that we are going to use throughout this chapter (and reference later in other chapters).

Assume that we started with four (4) relations, R(A,B,C), S(A,B,D), T(A,E) and U(E,F), and applied a _NATURAL JOIN_ operator on all of them, resulting in the final table shown below.

**Flat relational table after a JOIN on 4 relations.**
A|B|C|D|E|F|
1|1|1|1|2|1|
1|1|1|1|2|2|
1|1|1|2|2|1|
1|1|1|2|2|2|
1|2|2|1|2|1|
1|2|2|1|2|2|
2|1|2|1|1|1|
2|1|2|1|2|1|
2|1|2|1|2|2|

![alt text][ex_ftree_wo]
[ex_ftree_wo]: example-tree-wo.png "Example Factorization Tree"
**Factorization Tree without the relation dependencies.**

![alt text][ex_ftree]
[ex_ftree]: example-tree.png "Example Factorization Tree"
**Factorization Tree with the relation dependencies.**


![alt text][ex_frep]
[ex_frep]: example-rep.png "Example Data Factorization"
**Data Factorization based on the previous f-tree.**

We will use the above Factorization Tree (_figure X.1_), named _Example-FTree_ to factorize the result of the JOIN with the Data Factorization based on that f-tree being shown in _figure X.3_. The f-tree show in _figure X.2_ also highlights the dependencies created due to the relation tables.

I will abstractly explain the in-memory representation of Data Factorizations as implemented at the moment.
A factorized representation at the moment contains the following types of nodes:

1. _Union_ nodes just contain a list of the values for that specific attribute union
2. _Multiplication values_ are value nodes that act like _Multiplication_ nodes since their attribute is a multiplication attribute (based on f-tree) and they have two or more Union nodes as children
3. _Union values_ are value nodes that just have one Union node as a child
4. _Operand values_ is just another node type to denote leaf values

### Factorization Tree serialization

The factorization tree is the back-bone component of a factorization since it defines the structure of the representation and all the relations between the attributes of the query.
The serialization of an f-tree is the same for all the different factorization serialization techniques and is implemented as a separate module since it is a very small data structure (around a few KBs) and we do not mind using the simplest serialization for it.

I decided to use the same structure as an f-tree definition file for its serialization too. As a result, the serialization of the f-tree show in _figure X.1_ is as follows:

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

The serialized f-tree (including its size header) is prefixed in the final serialization of the Data Factorization such that it can be deserialized first and allow us to use it during the factorization deserialization.

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

Before going into details for this serialization technique I want to state some observations I made after investigating the reasons that led to failure of the previous serialization version.

* Each factorization is strictly associated with a factorization tree (f-tree) that defines its structure
* The main types of a node in a factorization are the _Multiplication_ (cross product) and the _Summation_ (union) node types
* The values inside a union node can be stored in continuous memory, thus avoiding the excessive overhead of Double-Linked-Lists due to the pointers for each value
* There is a need to de-couple the data, values, from the factorization structure since a lot of overhead comes with the representation and not the data

Apart from the above observations, the trick that led to this serialization method is that the only nodes required to be serialized are **Union** nodes along with their values. Since each factorization strictly follows an f-tree, it seemed obvious and very beneficial for me to use the f-tree as a guide during serialization and deserialization leading to a more succinct outcome which just contains the absolute minimum of information, _the values_!

The problem with generic serialization techniques, like _Boost_ described above is that all information goes into the serialized outcome to allow correct deserialization. We can avoid this overhead in our case since we know the special structure of the factorization and therefore we can use the f-tree to infer the structure of the representation and load the values from the serialized form as we go along during deserialization.

#### Idea

The main idea of **Simple Serializer** is that we traverse the f-representation in a DFS (Depth-First-Search) order and every time we find a _Union_ node we serialize it, then continue.
The serialization of a union node is extremely simple and just contains a number N indicating the number of values in that specific union, followed by N values of the attribute represented by that union.

For example, if a specific union of attribute A (of type _int_) has the values [3, 6, 7, 8, 123, 349], its serialization would be:
```
6 3 6 7 8 123 349
```

It is important to mention that I use **Binary** read and write methods during serialization and deserialization and for each children count I use 32-bit unsigned integer values whereas for the actual values I use the corresponding number of bytes required for that attribute data type (i.e. _double_ = sizeof(double) = 8 bytes).

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

To illustrate the serialization process let us see how the serialization of the factorization in the example will look like.

// **TODO**

**Simple Deserializer**
```
// @in: the input stream from which we deserialize the factorization
// @currentAttr: the current attribute node in the f-tree (initially the root)
FRepNode* dfs_load(istream *in, FTreeNode *currentAttr) {
    // we know that we only deserialize unions so create a new union
    Operation *opSummation = new Summation(currentAttr->name,
                                           currentAttr->ID,
                                           currentAttr->value_type);
    // deserialize the children count and the values for this union
    unsigned int childrenCount = read_binary(in);
    vector<Value*> values = read_binary_many(in, value_type, childrenCount);
    
    // now use the f-tree to infer factorization structure 
    if (is_leaf_attribute(currentAttr)) {
        // just append the values to the current union and return
        for each value V in 'values' {
            opSummation->addChild(V, new Operand(...));
        }
        return opSummation;
    } else {
        // this is an internal attribute node therefore we need to check if 
        // we have to create a multiplication node for each of child values
        if (!is_multiplication_attribute(currentAttr)) {
            // not a product attribute so just store children and recurse
            for each value V in 'values' {
                opSummation->addChild(V, dfs_load(in, currentAttr->firstChild));
            }
            return opSummation;
        } else {
            // each value of the union is a multiplication operation 
            for each value V in 'values' {
                Operation *opMult = new Multiplication();
                opSummation->addChild(V, opMult);
                // recurse on each attribute child and add it to this multiplication
                for each child attribute CA in currentAttr->children {
                    opMult->addChild(new Value(CA->attributeID),
                                     dfs_load(in, CA));
                } // end for each attribute in the product
            }
            return opSummation;
        } // end of if product attribute
    } // end of if leaf_attribute
}
```

**Simple Deserializer** is not as simple as its counterpart but it is easy as soon as some key things are explained.

First of all, we mentioned numerous times that we just serialize factorization nodes of type _Union_, so we know that in the deserialization we only deserialize union nodes, thus the creation of a Union node just from the start (_opSummation_). Then we read the children counter for this union and such many values from the input stream (note that we use binary format in deserializer too to match the serializer).

We have the values for the union now but we have to use the f-tree to determine what type of factorization node each value should represent. 

If the current union we deserialize represents a leaf attribute (_currentAddr_) (like _C_, _D_ and _F_ in the example) we just append the values in the union node using our special Operand node (does not really matter what we pass to that fo the serialization module).

If the current union represents an internal attribute node (like _A_, _B_, _E_) we have to check if this is a multiplication attribute, meaning that it has 2 or more child attributes in the f-tree (like _A_ and _B_). If the current attribute is not product/multiplication we just add the values to the current union (_opSummation_) and as a _subtree_ node we add whatever the recursion will return (_line XXX_). If the current attribute is a multiplication then we need to create a factorization node of type _Multiplication_ for each value and each child of this multiplication will be the recursion result on each of the current attribute's children. For example, if the current attribute (currentAttr) is _B_ it means that is has two children, attribute _C_ and attribute _D_. Therefore each value of union B will have a node of type Multiplication that has two subtrees, one for each of the C and D attributes and their subtree nodes will be the respective recursion result (_line XXX_).

To illustrate the deserialization process let us see how the serialization of the factorization in the example will be deserialized.

// **TODO**


### Byte (De)Serializer

Byte (De)Serializer is an extension of the Simple Binary (De)Serializer technique where the only difference is that it just stores required bytes only for each value and not all the number of bytes of each data type. 

#### Idea

If we really wanted each value to have only the required amount of bytes then somehow we would need to store that amount somewhere in the serialization in order to allow the deserializer to know how many bytes to read. It is easy to see that with millions of values, having a companion byte indicating the number of required bytes for each value could be excessive. Therefore, we decided for each attribute to use the required amount of bytes to cover the maximum value occured for that attribute. Therefore, we have different required-bytes for each attribute and we avoid the overhead of having them for each value since we just store them once as a serialization header at the very beginning.

We also apply the same logic to the union children counts, thus for each attribute we store two values, required-bytes for union children and required-bytes for union values. These two counters for each attribute are serialized in full binary format (8-bit unsigned numbers) at the beginning of the serialization. Therefore the deserializer will read these counters and then it will know exactly the amount of bytes to read for each union node.

#### Algorithms

**Byte Serializer**

The `dfs_save()` method is the same as the _Simple Serializer_ with the only difference that the 2 lines writing to the output stream the children count and the actual values use a special variant of the `write_binary()` method that accepts a 3rd argument denoting the number of bytes to write from the given value.

However, in order to know this required-bytes for each attribute union children and values we have to do a pass over the factorization and gather statistics around the actual values. This means that Byte Serializer traverses the whole factorization twice, but as the experiments show it does not hurt a lot in processing time but helps a lot in space-efficiency.

Here I will skip the `dfs_save()` method since it is exactly the same as described above and I will only provide the 1st pass algorithm that gathers statistics.

```
//
// @attribute_info: this is used in the method below and is a field of the Byte Serializer class
//
// @node: the node to start gathering statistics (initially the factorization root)
// @fTree: the factorization tree of the representation
void dfs_statistics(FRepNode *node, FactorizationTree *fTree) {
    Operation *op = (Operation*)node;

    if (is_multiplication(op)) {
        // multiplication nodes children are unions so just recurse on them
        for each child union CU in op->children {
            dfs_statistics(CU, fTree);
        }
    } else {
        // check if the current attribute required-bytes need to be updated
        
        // check children counts
        children_bytes = required_bytes(op->childrenCount);
        if (attribute_info[op->attributeID].required_union_bytes < children_bytes)
            attribute_info[op->attributeID].required_union_bytes = children_bytes;
            
        // check value bytes
        for each child value CV in op->children {
            val_bytes = required_bytes(CV);
            if (attribute_info[op->attributeID].required_value_bytes < val_bytes)
                attribute_info[op->attributeID].required_value_bytes = val_bytes;

            // recurse if this is not a leaf attribute in the f-tree
            if (!is_leaf_attribute(fTree, op->attributeID)) {
                dfs_statistics(CV, fTree);
            }
        } // end for each child value
    }
}
```

The statistics gathering is pretty straight-forward. We do a DFS-traversal on the factorization and whenever we are at a union node we update the required bytes for the number of children and for the values of that specific attribute represented by that union node. The `required_bytes()` method returns the number of bytes used starting from the LSB (least significant byte) to the MSB (most significant byte).

In the pseudocode above *attribute_info* is a field of the Byte Serializer class and its type is as following:

```
struct AttrInfo {
    uint8_t required_value_bytes;
    uint8_t required_union_bytes;
}
```

which as I mentioned before represents the header for each attribute that is written before the actual factorization serialization and each counter is an 8-bit unsigned integer.


**Byte Deserializer**

The _Byte Deserializer_ is exactly the same as the _Simple Deserializer_ with the only difference that the 2 lines where it reads from the input stream the number of children and the values themselves it uses a 3rd argument to the `read_binary()` method that specifies the number of bytes to read.

Before calling the method `dfs_load()` we separately read the counters for the required-bytes needed for union children and values respectively.


### Bit (De)Serializer

The final version of the serialization technique is _Bit Serializer_. As the name suggests it follows the same idea as the _Byte Serializer_ but instead of working at byte-level, it works at bit-level. Therefore, instead of storing the minimum amount of required bytes for each union count and each value, it stores only the required **bits** for them.

#### Idea

The idea of coming up with this serialization technique came up after we tested applying state-of-the-art compression algorithms like GZIP and BZIP2 upon our own _Simple_ and _Byte_ serializer. We saw that applying these compression algorithms reduced the output size by a constant factor ranging from 1-4x while at the same time increased the processing (serialization and deserialization) time significantly!

Although _serialization_ is different than compression and should not be mixed, in our case it was obvious that we could be more space-efficient by exploiting the data in our factorizations. As the experiments showed depending on the data of course, we achieved similar or close enough compression on our factorizations in a fraction of the time required by BZIP2 compression for example which provides the best compression at the cost of slow processing.

I want to emphasize that serialization is different than compression and that this chapter aimed at serialization of data factorizations. But, the knowledge of our structure allows us to exploit some things and at the same time be more space-efficient without increasing processing time a lot. Additionally, although we have some kind of compression, we do not have the drawback of standard compression algorithms (GZIP, BZIP2) that need the decompress the whole fragment first and then do any processing, since we are still able to deserialize each union separately and do processing as we go along (see future work section).

#### Algorithms

The algorithms are identical to those of _Byte Serializer_ and _Byte Deserializer_ with the exception that instead of using the `required_bytes()` method it uses the `required_bits()` method to only write the specific bits required to the output stream.

#### Bit Stream

This serialization technique requires bit-level precision when reading and writing values, but as we know all system calls and existing functionality provided by the standard libraries work at byte-level precision.

Therefore, in order to provide this functionality I implemented custom input and output streams (_obitstream_ and _ibitstream_) that are used upon the underlying standard binary byte streams and use those in the Bit Serializer and Bit Deserializer. These custom bit streams basically allow me for a given value to write only certain bits of its memory representation and respectively can read a certain number of bits from an input stream  and reinterpret them as a data type in memory.

Briefly, the way I do this is that I use a buffer of bytes in memory to write and read from certain amount of bits. Whenever the bytes available in the buffer are insufficient to satisfy a read operation I refill the internal buffer by reading from the underlying input stream. Whenever the internal buffer fills (or at user's request) I flush the internal buffer to the underlying output stream. Therefore, my implementation of bit streams work upon the underlying standard binary streams of C++ and use buffers to handle the required read and write operations.

In addition, an important feature that makes this serializer great is that in the future we could provide specialized read/write methods for certain data types (floats, doubles, strings) and further increase compression without adding processing overhead by applying compression algorithms. The current implementation of bit streams heavily uses C++ templates therefore this extension should be trivial to implement in a future project.

I am not going to provide any code here but you can find the source code in the project's repository.


## Final remarks

I described a serialization for Factorization Tree and 3 serialization techniques for Data Factorizations. In my serialization module I provide helper methods inside the package **fdb::serialization** that allows a user of the library to serialize and deserialize a full factorization with its f-tree easily.

Namely the _fdb::serialization::serialize(FRepTree *, ostream&)_ receives a data factorization, FRepTRee\*, and a reference to an output stream and serializes both f-tree and representation into the stream. The counterpart function _fdb::serialization::deserialize(istream&)_ deserializes from the input stream and returns an FRepTRee\*.

The combined serialization is of the form: 
```
<f-tree serialization size><f-tree serialization><factorization serialization size><factorization serialization>
```

