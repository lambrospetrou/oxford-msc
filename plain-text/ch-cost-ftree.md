# Finding good Factorization Trees

## Motivation

Previous work on Factorized Databases (**REFERENCE HERE**) provides searching for a good factorization tree (f-tree) upon a database based on asymptotic bounds and the size of the input. It has been proven to be optimal, many times generating exponentially more compressed representations than normal flat relational databases.

Although complexity bounds are nice, there are a lot of cases where they are not sufficient and we need more explicit properties. For example, given a database Q, the previous work might find that the optimal f-tree has parameter s(Q) = 2, where s(Q) is the cost measurement function, and that there are multiple trees with this property. But the question is which of those f-trees having parameter s(Q) = 2 is better ? At the moment, the implementation just uses the _first_ f-tree that has the optimal parameter s(Q). 

What we really want to investigate is how to find a good f-tree, using more refined parameters, that will also depend on the _data_ we want to factorize and not only on the f-tree structure which ignores data (except relation sizes). The reason why this is an important part of the project is that in a distributed system, **see discussion in experiments Section X.Y**, the biggest bottleneck is communication and data distribution. Therefore, although s(Q) provides optimal trees we want to minimize communication cost, thus requiring an f-tree that results in the smallest factorization size possible.

For example, In real-world scenarios it can happen that two f-trees have the same s(Q) parameter, let's say 2, but they might differ in size with a factor of 4x. More precisely, f-tree A can produce a factorization with 1 million singletons (value nodes) where f-tree B can produce a factorization of 4 million singletons. Asymptotically, we cannot discriminate the two, but in real life using f-tree B will result in excessive data distribution thus increasing our communication cost a lot, so it does matter in the end-to-end processing.

## Contribution

This chapter's contribution is a _COST_ function that given an f-tree and certain statistics (number of unique values per attribute, number of unique values per attribute under any other attribute of the f-tree) returns an estimation of the total factorization size (number of singletons, value nodes) that would occur if our database (factorization) was factorized based on that given f-tree.

## Idea

The requirement is to have a cost function that would take into account the actual values of a database instance in order to be able to compare in a more precise manner f-trees that are asymptotically optimal.

Let's start with some facts about FDB factorizations:

1. each union has its values ordered in ascending order
2. each union has unique values
3. a factorization may have many relation dependencies and each dependency forces its attributes to exist along a single path in the f-tree (like a linear linked list)
4. some attributes belong to many relations, thus have many dependencies

Considering the above facts, we used the number of unique values per union, therefore easily finding unique values per attribute. Additionally, the dependencies matter a lot since in complex queries like _triangles_ or _squares_, see Figure X.3,  we have all the attributes in a single path, forming a single linked list and each level down the path affects the factorization size.

![alt text][cost_ftree]
[cost_ftree]: cost-tree.png "Simple Factorization Tree"
**Figure X.1 - a simple factorization tree.**

![alt text][cost_frep]
[cost_frep]: cost-rep.png "Simple Factorization"
**Figure X.2 - a simple data factorization.**

![alt text][cost_ftree-tr-sq]
[cost_ftree-tr-sq]: ftree-triangle-square.png "Triangle and Square queries"
**Figure X.3 - f-trees for triangle and square queries.**

We define _cost_ of a factorization the total number of value nodes or singletons, thus the sum of the number of value nodes for each attribute. For example the factorization in **Figure X.2** has 20 value nodes (black nodes) so the cost for that f-tree is 20.

### Initial ideas

A first idea was to use an f-tree as a reference tree and based on some statistics calculated on this reference tree we would calculate the factorization estimated size for any other arbitrary f-tree.

Given an f-tree and its factorization, we calculate for each attribute the average number of unique values (children of a union) under any of its ancestor attributes. The average is taken over all the ancestor's children values.

**Notation** 

1. _XuY_ denotes the average number of unique values of attribute X _under_ a single value of attribute Y, where Y is an ancestor of X.
2. _uniq(X)_ denotes the average unique number of values among all the unions of attribute X.

For example, assuming the f-tree in Figure X.1 and its factorization (see Figure X.2), we have the following statistics:

```
number unique values per attribute: uniq(A), uniq(B), uniq(C), uniq(D), uniq(E), uniq(F)
number of unique values per attribute under an ancestor: BuA, CuA, CuB, DuA, DuB, EuA, FuA, FuE
```

Having the above statistics calculated, given any other f-tree _T_ the estimated size of the factorization would be calculated by summing the estimated number of nodes for each attribute. To calculate the cost for an attribute X, a path between X and its parent in T should be found inside the reference tree, followed by the multiplication of all the pair-wise averages (XuY) along the path to get an estimation for the number of values of X.

This approach quickly turned out to be wrong and over-estimating because of the excessive usage of estimates when we multiplied them for all the attribute pairs along the path.

### Proposed idea

The final solution is based on the same intuition but in a more precise and more accurate way. Instead of depending on estimates of a reference tree which lead to artificial over-estimation, statistics such that we can use them with any f-tree should be calculated, regardless of the input f-tree. Recall that our _cost_ function should be able to accept an arbitrary f-tree and return the estimation size as accurate as possible.

As a result, the following properties (statistics) are used during estimation:

1. average number of unique values of attribute X under any attribute Y (single value of Y), again denoted as _XuY_, where Y is an ancestor of X.
2. average unique number of values among all union nodes for each attribute, again denoted as _uniq(X)_ where X is an attribute.
3. flat size of the database (number of tuples)

Another important observation is that the number of nodes for each attribute in the factorization is related to _all_ of its ancestor attributes and not only to its parent. For example, in figure X.1, the number of nodes for attribute C depend both on B _and_ A, therefore we somehow have to incorporate them in our estimation for attribute C.

In the following formula _COST(X)_ denotes the estimated number of value nodes (singletons) for attribute X in the result factorization.

```
Input: 
    a) f-tree T
    b) (XuY) and uniq(X), as described above
    c) flat factorization size

Estimation Formula:

COST(X) = uniq(X),       if attribute X is root in the given f-tree T
COST(X) = MIN( COST(parent(X)) * MIN_AVERAGE(X, T),  FLAT_SIZE ),   if X is not root attribute
    where MIN_AVERAGE(X, T) = the minimum average XuY, where Y is an ancestor of X along the path from X to the root of f-tree T. Y should also exist in a  common relation with X (dependency)
```
    
The above formula gives an estimation for the number of value nodes for a given attribute in a given factorization tree. The total size of the factorization is the sum of the individual cost for each attribute.

It is important that we take into consideration dependencies and only use _XuY_ averages for the ancestor attributes that are in a common relation with attribute X since we do not know the relationship of X with attributes in other relations.

Additionally, we restrict the estimation size of the number of values per attribute to the flat size of the representation since that is the maximum amount of singletons we can have for each attribute, which is the worst case where each tuple is a separate path in the factorization.

## Algorithms

In this section the pseudocode for the complete factorization size estimation procedure is provided that implements the _COST_ function described above.

### Estimate Factorization Size

The algorithm is an iteration over the attributes in the factorization tree in a BFS-traversal order memoizing the estimations of already visited attributes to use in their descendants cost calculation.

```
// @fTree: the factorization tree we want to estimate the size for if we factorize our data based on it
// @FLATSIZE: the flat size in number of tuples for the input database instance
double estimate_size(FactorizationTree *fTree, unsigned int FLATSIZE) {
    // our queue to be used in BFS - holds pairs of attribute IDs <parentID, childID>
    queue<pair<int, int>> Q;
    // memoization array of the costs estimated - size = number of attributes
    vector<double> costs;

    // cost for the root
    rootID = fTree->root->ID;
    costs[rootID] = uniq(rootID);
    // add root's children in queue
    for each child attribute CA in fTree->root->children {
        Q.push_back({rootID, CA->ID});
    }

    // do the BFS traversal
    while (!Q.empty()) {
        // pop the next pair from queue
        parent_child = Q.pop_front();
        parentID = parent_child->first;
        childID = parent_child->second;
        
        // calculate the minimum of all averages XuY where X = childID and 
        // Y is every ancestor of X in the fTree that also belongs to a common
        // relation (dependency) with X.
        double min_est = min_average(fTree, childID);
        // calculate the cost for this attribute
        // COST(X) = min(COST(parent(X)) * min(all averages XuY), FLAT_SIZE)
        costs[childID] = min((costs[parentID] * min_est), FLATSIZE);

        // add the attribute's children to the BFS queue
        for each child attribute CA in fTree->node(childID)->children {
            Q.push_back({childID, CA->ID});
        }
    }

    // the total cost estimation is the total number of value nodes
    // which is the sum of all the value nodes for each attribute
    return sum(costs);
}
```

The above algorithm calculates the estimated size of the representation that will be created based on the input factorization tree. The algorithm assumes that the averages are already calculated and are ready to be used. This is common in the databases-world where some properties are calculated off-line in order to be used during runtime (value histograms, unique values, selectivity, etc.).

The complexity of the algorithm is quadratic to the number of attributes in the factorization tree, **O(N^2)** since we visit each attribute exactly once and for each attribute we call the *min_average()* function which has linear complexity, or more precisely its complexity depends on the longest root-to-leaf path (we visit each attribute's ancestor in the f-tree).

For the sake of completion the pseudocode for the *min_averages()* function is provided below.

```
// @fTree: the factorization tree we currently estimate the size
// @attributeID: the ID of the attribute we are calculating the estimated number of nodes
double min_average(FactorizationTree *fTree, attributeID) {
    // get the attribute node
    cN = fTree->node(attributeID);

    // the maximum average for each attribute is the unique number of values of it
    double min_est = uniq(attributeID);

    // we now traverse the path from the current attribute up to the root
    // and check the average of children with each ancestor
    // ONLY if it belongs to common relation/dependency (hyperedge)
    while (cN != NULL) {
        if (same_hyperedge(attributeID, cN->ID)) {
            min_est = min(min_est, XuY(attributeID, cN->ID));
        }
        cN = cN->parent;
    }
    return min_est;
}
```

The complexity of the above pseudocode is linear in the longest path from an attribute node to the root and it finds the minimum average number of children (unique values) of the current attribute under any ancestor attribute in the current f-tree. 

The maximum amount of children (unique values) of any attribute under any other attribute is the amount its unique values since we have unique values in our union nodes.

### Calculate averages

The previous algorithm that estimates factorization size assumes existence of the averages _XuY_ for each pair of attributes in the same hyperedge (relation/dependency). A procedure was implemented that calculates this but it is code-specific to be included in the thesis so we only provide a pseudocode for it showing the idea behind it.

The function returns a two-dimensional matrix with size (N x N), where is the number of attributes.
Matrix[X][Y] corresponds to the notation used above, XuY, which means that cell located at row X and column Y has the average number of children (unique values) among all unions of attribute X which are located below each value of the attribute Y.

```
// @fTree: the factorization tree used for the representation '@fRep'
// @fRep: an input factorization of the database instance we examine
void calculate_averages(FactorizationTree *fTree, FRepresentation *fRep) {
    double matrix[fTree->number_of_attributes()][fTree->number_of_attributes()];
    for each attribute A in fTree->nodes {
        // make the current attribute A root of the factorization
        make_root_attribute(A, fRep, fTree);
        
        // traverse the factorization in either DFS or BFS mode and calculate
        // all the averages where attribute A is the parent since now all
        // other attributes are below attribute A
        averages = calculate_averages_for_root(A, fRep);

        // update estimates matrix
        update_matrix(matrix, averages);
    }
    return matrix;
}
```

The above algorithm's runtime could be improved but it is orthogonal to the project and only used during the off-line pre-processing of the database instance to generate the averages, thus its suboptimality is not a serious concern. 

The real need was to provide a fast cost function that during runtime could determine the size of the factorization given an arbitrary f-tree.






