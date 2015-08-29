## Experimental evaluation

In this section we will present experimental evaluation for the main contributions of this project, namely the _COST_ function for finding good factorizations f-trees (see **Chapter XX**), the serialization techniques explained in **Chapter XX** and D-FDB, the distributed query engine as presented in **Chapter X**.

### Datasets and evaluation setup

#### Datasets

We used two different datasets throughout the development and evaluation of the above contributions, both described below.

1. **Housing**
    
    _Housing_ is a synthetic dataset emulating the textbook example for the house price market. 
    
    It consists of six tables: 
    
    * _House_ (postcode, size of living room/kitchen area, price, number of bedrooms, bathrooms, garages and parking lots, etc.) 
    * _Shop_ (postcode, opening hours, price range, brand, e.g. Costco, Tesco, Saynsbury's)
    * _Institution_ (postcode, type of educational institution, e.g., university or school, and number of students)
    * _Restaurant_ (postcode, opening hours, and price range)
    * _Demographics_ (postcode, average salary, rate of unemployment, criminality, and number of hospitals)
    * _Transport_ (postcode, the number of bus lines, train stations, and distance to the city center for the postcode).

    The scale factor **s** determines the number of generated distinct tuples per postcode in each relation: We generate _s_ tuples in _House_ and _Shop_, _log2(s)_ tuples in _Institution_, _s/2_ in _Restaurant_, and one in each of _Demographics_ and _Transport_.
    The experiments that use the _Housing_ dataset will examine scale factors ranging from 1 to 15.

2. **US retailer**
    
    The _US retailer_ dataset consists of three relations: 
        
    * _Inventory_ (storing information about the inventory units for products in a location, at a given date) (84M tuples)
    * _Sales_ (1.5M tuples)
    * _Clearance_ (370K tuples)
    * _ProMarbou_ (183K tuples)

#### Evaluation setup

The reported times for the COST function and the serialization techniques were taken on a server with the following specifications:
    
- Intel Core i7-4770, 3.40 GHz, 8MB cache
- 32GB main memory
- Linux Mint 17 Qiana
- Linux kernel 3.13

The experiments related to the distributed query engine  D-FDB were run on a cluster of 10 machines with the following specifications:
    
- Intel Xeon E5-2407 v2, 2.40GHZ, 10M cache
- 32GB main memory, 1600MHz
- Ubuntu 14.04.2 LTS
- Linux kernel 3.16


### COST function - finding good f-trees



### Serialization of Data factorizations

In this section, we evaluate each serialization technique examined and described in **Chapter SR**.
The factorizations we use to evaluate the serialization techniques are the _NATURAL JOINS_ of the two datasets, _Housing_ and _US retailer_on all of their relational tables.

#### Correctness of serialization

The correctness test of each serialization was done both in-memory and off-memory using the disk. For equality comparison between two factorizations we use a special function (_toSingletons()_) that traverses the factorization encoding the singletons into a string representation that contains attribute name, value and attribute ID in text format, thus creating a huge string that contains the whole data of the factorization.

**In memory tests**

For the in-memory tests we performed the following steps:

1. Load a factorization from disk, let's call it _OriginRep_
2. Serialize it in memory into a memory buffer (array of bytes)
3. Deserialize the buffer into a new instance of a factorization, let's call it _SerialRep_
4. Check the fields of _SerialRep_ that valid values are used
5. Use the _toSingletons()_ method and create the string representation for _OriginRep_ and _SerialRep_ and compare the two strings for equality. This ensures that not only we recover the same number of singletons properly but also that the IDs and values of those singletons are preserved during serialization and desrialization, even with floating point values.

For the off-memory tests we performed similar steps as in-memory with an extra additional test to further prove correction.
1. Load a factorization from disk, let's call it _OriginRep_
2. Serialize it to a file on disk (binary file mode)
3. Open the file in read mode and deserialize it into a new instance of a factorization, let's call it _SerialRep_
4. Check the fields of _SerialRep_ that valid values are used
5. Use the _toSingletons()_ method and create the string representation for _OriginRep_ and _SerialRep_ and compare the two strings for equality. This ensures that not only we recover the same number of singletons properly but also that the IDs and values of those singletons are preserved during serialization and desrialization, even with floating point values.
6. Enumerate the tuples encoded by the factorizations _OriginRep_ and _SerialRep_ into two files. Compare the two files for equality using the standard command line tool _diff_.

#### Serialization sizes

In this section we will examine the size of the serialization output

#### Serialization and Deserialization times

**PLOT 1 - Comparison of serialization techniques vs flat**

all three serialization result sizes (raw) vs flat (raw bytes)

**PLOT 2 - Comparison of all serialization techniques (SIMPLE vs BYTE vs BIT)**

all three serializations result size in raw bytes, gzipped max, bziped max

**PLOT 1 - Comparison of bit serialization vs FLAT**

the bit serializer (none, bzip min max, gzip min max) vs flat (gzip min max, bzip min max, raw)

#### Conclusions

The evaluation of these serialization techniques reconfirms the results of previous work that factorizations can have great compression factors over flat data. We showed that our serialization techniques retain these compression in serialization too.

Additionally, the comparison between the raw serialization sizes and the sizes after applying standard compression algorithms show that there still exists possibility to further reduce the serialization size by integrating some compression techniques into the serialization itself, like we did for example with _Bit Serializer_ and got much better results.
It would be more beneficial to integrate some compression techniques into the serialization since the standard compression algorithms are slower than us by several factors.







