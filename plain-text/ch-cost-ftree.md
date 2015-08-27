# Finding good Factorization Trees

## Motivation

Previous work on Factorized Databases (**REFERENCE HERE**) provides search for a good factorization tree upon a database based on asymptotic bounds and the size of the input. It has been proven to be optimal, many times generating exponentially more compressed representations than normal flat relational databases.

Although complexity bounds are nice, there are a lot of cases where they are not sufficient and we need to delve a bit deeper. For example, given a database, the existing work might find that the optimal factorization tree has an s(Q) = 2 and that there are multiple trees with this property. But the question is which of those f-trees having s(Q)=2 is better ? At the moment, the implementation just uses the _first_ factorization tree that has the optimal s(Q). 

What we really want to investigate is how to find an even better factorization tree, using more refined parameters, that will also depend on the _data_ we want to factorize and not depend only on the f-tree structure which completely ignores data (except relation sizes). The reason why we believe this is an important part of the project is that in a distributed system, as I will show later in the experiments, the biggest bottleneck is communication and data distribution. Therefore, although s(Q) provides optimal trees we wanted to minimize our communication, thus requiring an f-tree that results in the smallest factorization size possible.

## Contribution

My contribution described in this chapter is a _COST_ function that given a Factorization Tree (f-tree) and some specific estimates (explained below) returns an estimation of the total Factorization size that would occur if our database was factorized based on the given f-tree.

Additionally, I provide a way to calculate the aforementioned estimates given as input any Factorization of our database.



