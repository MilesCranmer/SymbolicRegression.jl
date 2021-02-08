# API

## EquationSearch
```@docs
EquationSearch(X::AbstractMatrix{T}, y::AbstractVector{T};
        niterations::Int=10,
        weights::Union{AbstractVector{T}, Nothing}=nothing,
        varMap::Union{Array{String, 1}, Nothing}=nothing,
        options::Options=Options(),
        numprocs::Union{Int, Nothing}=nothing,
        procs::Union{Array{Int, 1}, Nothing}=nothing,
        runtests::Bool=true
       ) where {T<:Real}
```

## Options

```@docs
Options(;
    binary_operators::NTuple{nbin, Any}=(div, plus, mult),
    unary_operators::NTuple{nuna, Any}=(exp, cos),
    bin_constraints=nothing,
    una_constraints=nothing,
    ns=10, #1 sampled from every ns per mutation
    topn=10, #samples to return per population
    parsimony=0.000100f0,
    alpha=0.100000f0,
    maxsize=20,
    maxdepth=nothing,
    fast_cycle=false,
    migration=true,
    hofMigration=true,
    fractionReplacedHof=0.1f0,
    shouldOptimizeConstants=true,
    hofFile=nothing,
    npopulations=nothing,
    nrestarts=3,
    perturbationFactor=1.000000f0,
    annealing=true,
    batching=false,
    batchSize=50,
    mutationWeights=[10.000000, 1.000000, 1.000000, 3.000000, 3.000000, 0.010000, 1.000000, 1.000000],
    warmupMaxsize=0,
    useFrequency=false,
    npop=1000,
    ncyclesperiteration=300,
    fractionReplaced=0.1f0,
    verbosity=convert(Int, 1e9),
    probNegate=0.01f0,
    seed=nothing
   ) where {nuna,nbin}
```

## Printing and Evaluation

```@docs
stringTree(tree::Node, options::Options)
```

```@docs
evalTreeArray(tree::Node, cX::AbstractMatrix{T}, options::Options) where {T<:Real}
```

## SymbolicUtils.jl interface

```@docs
node_to_symbolic(tree::Node, options::Options; 
                     varMap::Union{Array{String, 1}, Nothing}=nothing,
                     evaluate_functions::Bool=false,
                     index_functions::Bool=false)
```

## Pareto frontier


```@docs
calculateParetoFrontier(X::AbstractMatrix{T}, y::AbstractVector{T},
                        hallOfFame::HallOfFame, options::Options;
                        weights=nothing, varMap=nothing) where {T<:Real}
calculateParetoFrontier(dataset::Dataset{T}, hallOfFame::HallOfFame,
                        options::Options) where {T<:Real}
```
