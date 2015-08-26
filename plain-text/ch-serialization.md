# Serialization of Factorized Representations

## Motivation

A very important part of the project investigated ways to serialize, and possibly compress, f-representations (factorizations). It is very important to support serialization and deserialization of a factrorization both in a centralized setting and in a distributed setting. For example, sometimes we want to save an instance of a database on disk to manipulate and further process it later. In some other cases we want to ship data over the wire to neighboring PC nodes which need the data for additional processing on their side. 

In general, serialization is the method of efficiently converting an in-memory factorization into a series of bytes which is stored or transferred and later can be deserialized into the exact source factorization.
An important aspect of serialization and deserialization is that it has to be efficient in both time and space since we want to retain the major benefit of f-representations, which is the compressed size compared to corresponding flat representation. Thus, having a bad serialization that would take a lot of space or requiring a lot of time to process would be inappropriate for our setting, especially the distributed system which is the goal of this thesis.


## Serialization attempts

In this section I will describe the different approaches I have taken for the serialization up to the final version used in the distributed system.

### Boost Serialization

As a first attempt to provide serialization/deserialization I decided to use **Boost::Serialization** library since it gathered high reviews in the online community and since I was already using _Boost_ for the networking modules of the system it seemed to be a great fit. 
The purpose of _Boost::Serialization_ library is to allow developers to provide an easy way to add serialization to their **existing** data structures without writing a lot of boilerplate code since it can be described more or less like a memory dump of the structure into a stream, which can be anything from a file, to a socket, etc.

The integration of the library in FDB and the actual implementation was pretty straightforward and was done in a few days, since I just had to add couple of _special_ methods in each class required to be serialized according to certain library rules. However, the end result was really bad.

As I mentioned, this is more like a memory dump of the structure, including any pointers and their destination objects, in order to easily allow the deserializer to create the exact data structure. The caveat here is that the existing _FDB_ implementation is **very bad**! I really can't emphasize this enough. The current data structure of an f-representation has a lot of overhead, including many unneccessary fields, keeping all the values of a Union for example as a Double-Linked-List thus introducing excessive amount of pointers and many more. As a result, the serialization module was dumping everything, more importantly the pointers structure, to allow recreation during deserialization leading to a bloated outcome, both in terms of raw size in bytes but also in long serialization times.

In order to use _Boost::Serialization_ and at the same time having quality serialization I had to write custom code for each implementation class for every data structure we use to omit certain fields or doing my own book-keeping for the pointers and references to avoid all this going into the serialized output.
It didn't worth it since still there was going to be some overhead added by Boost which cannot be removed, like class versioning etc.

**First attempt failed** but led to some interesting observations. Although the current implementation was poorly done, a good serialization does not need all that information and we could also take advantage of the special structure of a factorization to make it as succinct as possible.

### Simple Binary Serializer









