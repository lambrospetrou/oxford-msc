# Serialization of Factorized Representations

## Motivation

A very important part of the project investigated ways to serialize, and possibly compress, f-representations (factorizations). It is very important to support serialization and deserialization of a factrorization both in a centralized setting and in a distributed setting. For example, sometimes we want to save an instance of a database on disk to manipulate and further process it later. In some other cases we want to ship data over the wire to neighboring PC nodes which need the data for additional processing on their side. 

In general, serialization is the method of efficiently converting an in-memory factorization into a series of bytes which is stored or transferred and later can be deserialized into the exact source factorization.
An important aspect of serialization and deserialization is that it has to be efficient in both time and space since we want to retain the major benefit of f-representations, which is the compressed size compared to corresponding flat representation. Thus, having a bad serialization that would take a lot of space or requiring a lot of time to process would be inappropriate for our setting, especially the distributed system which is the goal of this thesis.

