# API

## EquationSearch

```@docs
EquationSearch(X::AbstractMatrix{T}, y::AbstractMatrix{T};
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
Options(;)
MutationWeights(;)
```

## Printing

```@docs
string_tree(tree::Node, options::Options; kws...)
```

## Evaluation

```@docs
eval_tree_array(tree::Node, X::AbstractMatrix, options::Options; kws...)
```

## Derivatives

`SymbolicRegression.jl` can automatically and efficiently compute derivatives
of expressions with respect to variables or constants. This is done using
either `eval_diff_tree_array`, to compute derivative with respect to a single
variable, or with `eval_grad_tree_array`, to compute the gradient with respect
all variables (or, all constants). Both use forward-mode automatic, but use
`Zygote.jl` to compute derivatives of each operator, so this is very efficient.

```@docs
eval_diff_tree_array(tree::Node, X::AbstractMatrix, options::Options, direction::Int)
eval_grad_tree_array(tree::Node, X::AbstractMatrix, options::Options; kws...)
```

## SymbolicUtils.jl interface

```@docs
node_to_symbolic(tree::Node, options::Options; 
                     varMap::Union{Array{String, 1}, Nothing}=nothing,
                     index_functions::Bool=false)
```

## Pareto frontier

```@docs
calculate_pareto_frontier(X::AbstractMatrix{T}, y::AbstractVector{T},
                        hallOfFame::HallOfFame{T}, options::Options;
                        weights=nothing, varMap=nothing) where {T<:Real}
calculate_pareto_frontier(dataset::Dataset{T}, hallOfFame::HallOfFame{T},
                          options::Options) where {T<:Real}
```
