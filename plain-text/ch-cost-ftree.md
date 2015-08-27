# Finding good Factorization Trees

## Motivation

Previous work on Factorized Databases (**REFERENCE HERE**) provides searching for a good factorization tree upon a database based on asymptotic bounds and the size of the input. It has been proven to be optimal, many times generating exponentially more compressed representations than normal flat relational databases.

Although complexity bounds are nice, there are a lot of cases where they are not sufficient and we need to delve a bit deeper. For example, given a database, the existing work might find that the optimal factorization tree has an s(Q) = 2 and that there are multiple trees with this property. But the question is which of those f-trees having s(Q)=2 is better ? At the moment, the implementation just uses the _first_ factorization tree that has the optimal s(Q). 

What we really want to investigate is how to find an even better factorization tree, using more refined parameters, that will also depend on the _data_ we want to factorize and not depend only on the f-tree structure which completely ignores data (except relation sizes). The reason why we believe this is an important part of the project is that in a distributed system, as I will show later in the experiments, the biggest bottleneck is communication and data distribution. Therefore, although s(Q) provides optimal trees we wanted to minimize our communication, thus requiring an f-tree that results in the smallest factorization size possible.

## Contribution

My contribution described in this chapter is a _COST_ function that given a Factorization Tree (f-tree) and some specific estimates (explained below) returns an estimation of the total Factorization size that would occur if our database was factorized based on the given f-tree.

Additionally, I provide a way to calculate the aforementioned estimates given as input any Factorization of our database.


## Idea

As I said before, we wanted a cost function that would take into account the real data of the database instance we have in order to be able to compare in a more precise manner f-trees that are asymptotically optimal.

Let's start with some facts about FDB factorizations:

1. each union has its values ordered in ascending order
2. each union has unique value, thus each value appears only once
3. a factorization may have many relation dependencies and each dependency forces attributes to be in a single path in the f-tree (in style of a linear linked list)
4. some attributes belong to many relations, thus many dependencies

Considering the above facts, it was obvious that we wanted to use the number of unique values per union, thus easily finding unique values per attribute. Additionally, the dependencies matter a lot since especially in complex queries like _triangles_ or _squares_ we have all the attributes in a single path, forming a single linked list and each level down the path affects the factorization size.

### Initial ideas

![alt text][cost_ftree]
[cost_ftree]: cost-tree.png "Simple Factorization Tree"
**Figure X.1 - a simple factorization tree.**

![alt text][cost_frep]
[cost_frep]: cost-rep.png "Simple Factorization"
**Figure X.2 - a simple data factorization.**

We first decided to use an f-tree as a reference tree and based on the estimates calculated on this reference tree we would calculate the factorization estimated size for any other arbitrary f-tree.

Given an f-tree and its factorization (figure X.2), we calculate for each attribute the average children unique values under any of its ancestor attributes.
For example, assuming the f-tree in figure X.1 and its factorization (figure X.2), we have the following estimates (averages to be precise):

**Notation** 

1. I use _XuY_ to denote the average number of unique values of attribute X _under_ attribute Y, thus Y is an ancestor of X.
2. I use _uniq(X)_ to denote the average unique number of values among all the unions of attribute X

```
uniq(A), uniq(B), uniq(C), uniq(D), uniq(E), uniq(F)
BuA, CuA, CuB, DuA, DuB, EuA, FuA, FuE
```

Having these estimates calculated, given any other f-tree _T_ we would estimate the size of the factorization by calculating the estimated number of nodes for each attribute. To calculate this we initially thought of finding a path between an attribute X and its parent inside the reference tree and then multiplying all the pair-wise estimates together to get an estimation for the number of values of X.

This method seemed logical but was quickly to be wrong and because of high usage of estimates it over-estimated the factorization size making it unusable and unreliable.

### Proposed idea

After many iterations we ended up using the same intuition but in a more precise and more accurate way. Instead of depending on estimates of a reference tree which lead to artificial estimation, we would calculate estimates such that we can use them with any f-tree, regardless of how the estimates were calculated. Recall that our _cost_ function should be able to accept an arbitrary f-tree and return the estimation size as accurate as possible.

As a result, we decided to use the following properties during estimation:

1. average number of unique values of attribute any X under attribute any Y, again denoted as _XuY_, where Y is an ancestor of X
2. average unique number of values among all union nodes for each attribute, again denoted as _uniq(X)_ where X is an attribute
3. flat size of the database

Another important observation we did is that the number of nodes for each attribute in the factorization is related to it _all_ of its ancestor attributes and not only to its parent. For example, in figure X.1, the number of nodes for attribute C depend both on B _and_ A, therefore we somehow had to incorporate them in our estimation for attribute C.

In the following formula _COST(X)_ denotes the estimated number of value nodes for attribute X in the result factorization.

```
Input: 
    a) factorization tree T
    b) averages as described above (XuY)
    c) flat factorization size

COST(X) = uniq(X)       if attribute X is root in the given f-tree T
COST(X) = MIN( COST(parent(X)) * MIN_AVERAGE(X, T),  FLAT_SIZE )

    where MIN_AVERAGE(X, T) = the minimum average XuY, where Y is an ancestor of X along the path from X to the root of f-tree T, that also belongs to a common relation with X (dependency)
```

The above formula gives an estimation for the number of value nodes for a given attribute in a given factorization tree. To get the total size we just sum the costs for all the attributes in our factorization tree.

It is important to note that we take into consideration dependencies too and only use _XuY_ averages for the attributes that are in a common relation with attribute X since we do not know the relationship of X with attributes in other relations.

### Algorithm

In this section I will provide the pseudocode for the complete factorization size estimation procedure that implements the _COST_ function described above.












