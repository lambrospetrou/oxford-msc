# Future work

In this section I provide ideas and extensions to my contributions that I consider important and are great opportunities for research in future projects.

## Serialization & Compression

Extend the bitstreams used in _Bit (De)Serializer_ with specialized read and write methods to provide even better compression in the serialized factorization. Integrating compression techniques in the serialization process is very beneficial for Distributed FDB since it can have the advantages of state-of-the-art compression algorithms in a fraction of their processing times.

Although my serialization technique does not require _full_ deserialization before some processing can occur, it would be interesting to examine if some operations can be processed on the serialized form of a factorization itself without deserializing it at all. The f-tree can be used as guide over the unions being serialized in order to allow simple query execution upon the bitstreams.

## Distributed query processing

There are a lot of future goals related to distribution.

One research topic is the investigation of how f-trees can affect communication time, hence end-to-end processing time. For example, should each node apply f-plans on its local factorization before transmitting it in order to reduce its size but at the same time adding some processing cycles ? Or is it better to just ship everything as is avoiding extra processing time ? Moreover, would be better to use a global f-tree for the factorizations at each site or each node should bring the factorization in its own f-tree form to make processing upon it faster ?

There is the topic of data transmission, which is a well-known problem to all distributed systems. At the moment we use ordered reads and writes, but what if random communication or other policy is used. For example, initially we were planning to also test Round-Robin like communication where a small fraction of the serialization is sent to each node in order to keep feeding data to all the streams, thus never a node would stall waiting for data.

Additionally, a more interesting subject is the actual query processing. We also briefly discussed the possibility of transmitting only absolute required data needed by the query and not the whole factorization. For example, if the query joins at the root attribute of the f-tree then by serializing and transmitting just root attribute of the factorization, which is very smaller than the whole, we could do the whole JOIN successfully. Of course, the result should be communicated back to the nodes in order to generate the final result but this is trivial.

This idea was one of the reason why we think the current serialization technique (Bit Serializer) is good and should be further extended. Each union is handled separately and therefore makes possible clever optimizations like the previous partial processing.

## FDB query engine

In my opinion, an important topic of future work in FDB is making it more generic and usable. At the moment, most of FDB functionality assumes single factorization as input. It should be extended to be able to work with multiple inputs, merging them, inferring global f-trees in order to combine different factorizations dynamically in run-time. I have done some work on this but it is in very early stages.

Moreover, I believe that the current in-memory representation of factorizations is not ideal since it has a lot of overhead due to excessive usageof double linked lists which bring along pointer book-keeping. 


