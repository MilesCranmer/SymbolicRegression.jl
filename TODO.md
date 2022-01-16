# TODO

- [ ] Randomly create a new tree once in a while.
- [ ] Kill tasks if exited early.
- [ ] Generate populations in parallel.
- [ ] Create quantitative profiler - measure profiler over time.
- [ ] Show speed by # of mutations total, and # mutations per individual.
- [ ] Is scoreFuncBatch called when creating PopMember, when batching turned on??
    - Should I run optimizeConstants with batching? e.g., a single little batch.
- [ ] Introduce new constraint checker that limits how many times an operator can be nested.
    e.g., it is fine to nest +, *, etc., but BAD to nest cos/sin/etc.
    - Maybe this is too much prior knowledge?
- [ ] Allow parts of a function to be frozen. Then the mutations will skip them.
    - [ ] Extend this: allow users to pass a SymbolicUtils equality with some function `f`, and features x0 (y), x1, x2, x3, .... This will allow one to find an equation to fit some pre-defined formula.

## Feature ideas

- [x] Other default losses (e.g., abs, other likelihoods, or just allow user to pass this as a string).
- [ ] Cross-validation
- [ ] Hierarchical model, so can re-use functional forms. Output of one equation goes into second equation?
- [ ] Add function to plot equations?
- [ ] Add ability to save state from python
- [ ] Additional degree operators?
- [ ] Multi targets (vector ops). Idea 1: Node struct contains argument for which registers it is applied to. Then, can work with multiple components simultaneously. Though this may be tricky to get right. Idea 2: each op is defined by input/output space. Some operators are flexible, and the spaces should be adjusted automatically. Otherwise, only consider ops that make a tree possible. But will need additional ops here to get it to work. Idea 3: define each equation in 2 parts: one part that is shared between all outputs, and one that is different between all outputs. Maybe this could be an array of nodes corresponding to each output. And those nodes would define their functions.
    - Much easier option: simply flatten the output vector, and set the index as another input feature. The equation learned will be a single equation containing indices as a feature.
- [ ] Tree crossover? I.e., can take as input a part of the same equation, so long as it is the same level or below?
- [ ] Enable derivative operators. These would differentiate their right argument wrt their left argument, some input variable.

## Algorithmic performance ideas:

- [ ] When an equation gives NaN or Inf, just skip that generation entirely, rather than duplicating its parent.
- [ ] NDSA-II
- [ ] When doing equation warmup, only migrate those equations with almost the same complexity. Rather than having to consider simple equations later in the game.
- [ ] Right now we only update the score based on some. Need to update score based on entire data! Note that optimizer only is used sometimes.
- [ ] Idea: use gradient of equation with respect to each operator (perhaps simply add to each operator) to tell which part is the most "sensitive" to changes. Then, perhaps insert/delete/mutate on that part of the tree?
- [ ] Start populations staggered; so that there is more frequent printing (and pops that start a bit later get hall of fame already)?
- [ ] Consider adding mutation for constant<->variable
- [ ] Implement more parts of the original Eureqa algorithms: https://www.creativemachineslab.com/eureqa.html
- [ ] Experiment with freezing parts of model; then we only append/delete at end of tree.
- [ ] Use NN to generate weights over all probability distribution conditional on error and existing equation, and train on some randomly-generated equations
- [ ] For hierarchical idea: after running some number of iterations, do a search for "most common pattern". Then, turn that subtree into its own operator.
- [ ] Calculate feature importances based on features we've already seen, then weight those features up in all random generations.
- [ ] Calculate feature importances of future mutations, by looking at correlation between residual of model, and the features.
    - Store feature importances of future, and periodically update it.
- [ ] Punish depth rather than size, as depth really hurts during optimization.


## Code performance ideas:

- [ ] Bottleneck is still the equation evaluation. So: move to the GPU!!
- [ ] Compute min-memory traversal of tree before execution.
    - Should theoretically be possible to do the entire tree with a single array. How hard to get this working?
        - One option is to traverse the tree from inside a loop over the array. Is that crazy?
- [ ] How hard is it to turn the recursive array evaluation into a for loop?
    - Difficulty in getting efficient allocations... Will try more later
- [ ] Try defining a binary tree as an array, rather than a linked list. See https://stackoverflow.com/a/6384714/2689923
    - Want to move all tree arguments to be inline functions:
        - .l, .r, etc.
        - Then, can have an alternate type that simply replaces the .l, .r functions with indices to an array.
        - Also replace the = operator to be .set() or something.
            - And make .set() for an entire node type.
- [ ] Performance: try inling things?
- [ ] Try storing things like number nodes in a tree; then can iterate instead of counting

```julia
mutable struct Tree
    degree::Array{Integer, 1}
    val::Array{Float32, 1}
    constant::Array{Bool, 1}
    op::Array{Integer, 1}
    Tree(s::Integer) = new(zeros(Integer, s), zeros(Float32, s), zeros(Bool, s), zeros(Integer, s))
end
```

- Then, we could even work with trees on the GPU, since they are all pre-allocated arrays.
- A population could be a Tree, but with degree 2 on all the degrees. So a slice of population arrays forms a tree.
- How many operations can we do via matrix ops? Mutate node=>easy.
- Can probably batch and do many operations at once across a population.
    - Or, across all populations! Mutate operator: index 2D array and set it to random vector? But the indexing might hurt.
- The big advantage: can evaluate all new mutated trees at once; as massive matrix operation.
    - Can control depth, rather than maxsize. Then just pretend all trees are full and same depth. Then we really don't need to care about depth.

- [ ] Can we cache calculations, or does the compiler do that? E.g., I should only have to run exp(x0) once; after that it should be read from memory.
    - Done on caching branch. Currently am finding that this is quiet slow (presumably because memory allocation is the main issue).
- [ ] Add GPU capability?
     - Not sure if possible, as binary trees are the real bottleneck.
     - Could generate on CPU, evaluate score on GPU?



# Completed

- [x] Async threading, and have a server of equations. So that threads aren't waiting for others to finish.
- [x] Print out speed of equation evaluation over time. Measure time it takes per cycle
- [x] Add ability to pass an operator as an anonymous function string. E.g., `binary_operators=["g(x, y) = x+y"]`.
- [x] Add error bar capability (thanks Johannes Buchner for suggestion)
- [x] Why don't the constants continually change? It should optimize them every time the equation appears.
    - Restart the optimizer to help with this.
- [x] Add several common unary and binary operators; list these.
- [x] Try other initial conditions for optimizer
- [x] Make scaling of changes to constant a hyperparameter
- [x] Make deletion op join deleted subtree to parent
- [x] Update hall of fame every iteration?
    - Seems to overfit early if we do this.
- [x] Consider adding mutation to pass an operator in through a new binary operator (e.g., exp(x3)->plus(exp(x3), ...))
    - (Added full insertion operator
- [x] Add a node at the top of a tree
- [x] Insert a node at the top of a subtree
- [x] Record very best individual in each population, and return at end.
- [x] Write our own tree copy operation; deepcopy() is the slowest operation by far.
- [x] Hyperparameter tune
- [x] Create a benchmark for accuracy
- [x] Add interface for either defining an operation to learn, or loading in arbitrary dataset.
    - Could just write out the dataset in julia, or load it.
- [x] Create a Python interface
- [x] Explicit constant optimization on hall-of-fame
    - Create method to find and return all constants, from left to right
    - Create method to find and set all constants, in same order
    - Pull up some optimization algorithm and add it. Keep the package small!
- [x] Create a benchmark for speed
- [x] Simplify subtrees with only constants beneath them. Or should I? Maybe randomly simplify sometimes?
- [x] Record hall of fame
- [x] Optionally (with hyperparameter) migrate the hall of fame, rather than current bests
- [x] Test performance of reduced precision integers
    - No effect
- [x] Create struct to pass through all hyperparameters, instead of treating as constants
    - Make sure doesn't affect performance
- [x] Rename package to avoid trademark issues
    - PySR?
- [x] Put on PyPI
- [x] Treat baseline as a solution.
- [x] Print score alongside MSE: \delta \log(MSE)/\delta \log(complexity)
- [x] Calculating the loss function - there is duplicate calculations happening.
- [x] Declaration of the weights array every iteration
- [x] Sympy evaluation
- [x] Threaded recursion
- [x] Test suite
- [x] Performance: - Use an enum for functions instead of storing them?
    - Gets ~40% speedup on small test.
- [x] Use @fastmath
- [x] Try @spawn over each sub-population. Do random sort, compute mutation for each, then replace 10% oldest.
- [x] Control max depth, rather than max number of nodes?
- [x] Allow user to pass names for variables - use these when printing
- [x] Check for domain errors in an equation quickly before actually running the entire array over it. (We do this now recursively - every single equation is checked for nans/infs when being computed.)
- [x] read the docs page
- [x] Create backup csv file so always something to copy from for `PySR`. Also use random hall of fame file by default. Call function to read from csv after running, so dont need to run again. Dump scores alongside MSE to .csv (and return with Pandas).
- [x] Better cleanup of zombie processes after <ctl-c>
- [x] Consider printing output sorted by score, not by complexity.
- [x] Increase max complexity slowly over time up to the actual max.
- [x] Record density over complexity. Favor equations that have a density we have not explored yet. Want the final density to be evenly distributed.
- [x] Do printing from Python side. Then we can do simplification and pretty-printing.
- [x] Sympy printing
- [x] Use generic types - should pass type to option, and this will set up everything.
- [x] Create mechanism to convert back and forth between Julia expression and Node()
    - Then, we can use the Julia simplification library!
    - Just need to run an eval() on `stringTree`.
- [x] Add back weighted
    - Use "data" struct?
- [x] Use SymbolicRegression.jl in Python frontend
- [x] Other dtypes available
- [-] Refresh screen rather than dumping to stdout? (not done)
- [x] Create flexible way of providing "simplification recipes." I.e., plus(plus(T, C), C) => plus(T, +(C, C)). The user could pass these.
- [x] Add true multi-node processing, with MPI, or just file sharing. Multiple populations per core.
    - Ongoing in cluster branch
- [-] Use package compiler and compile sr.jl into a standalone binary that can be used by pysr.
- [x] Fuse operations for bin(op; op) triplets! There aren't that many, so probably worth it.
- [x] Make serial version of code. Also to help benchmarking.
- [x] Consider allowing multi-threading turned off, for faster testing (cache issue on travis). Or could simply fix the caching issue there.
- [x] Consider returning only the equation of interest; rather than all equations.
- [x] Sort these todo lists by priority
    - Not done.
- [x] Are some workers getting too many populations, and other not enough? Is this why the load is low?