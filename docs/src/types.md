# Types

## Equations

Equations are specified as binary trees with the `Node` type. Operators
defined in `Base` are re-defined for Node types, so that one can
use, e.g., `t=Node(1) * 3f0` to create a tree.

```@docs
Node(val::AbstractFloat)
Node(feature::Int)
Node(var_string::String)
Node(var_string::String, varMap::Array{String, 1})
Node(op::Int, l::Node)
Node(op::Int, l::Union{AbstractFloat, Int})
Node(op::Int, l::Node, r::Node)
Node(op::Int, l::Union{AbstractFloat, Int}, r::Node)
Node(op::Int, l::Node, r::Union{AbstractFloat, Int})
Node(op::Int, l::Union{AbstractFloat, Int}, r::Union{AbstractFloat, Int})
```

## Population

Groups of equations are given as a population, which is
an array of trees tagged with score and birthdate---these
values are given in the `PopMember`.

```@docs
Population(pop::Array{PopMember{T}, 1}) where {T<:Real}
Population(dataset::Dataset{T}, baseline::T;
           npop::Int, nlength::Int=3,
           options::Options,
           nfeatures::Int) where {T<:Real}
Population(X::AbstractMatrix{T}, y::AbstractVector{T}, baseline::T;
           npop::Int, nlength::Int=3,
           options::Options,
           nfeatures::Int) where {T<:Real}
```

## Population members
```@docs
PopMember(t::Node, score::T) where {T<:Real}
PopMember(dataset::Dataset{T}, baseline::T, t::Node, options::Options) where {T<:Real}
```

## Hall of Fame

```@docs
HallOfFame(options::Options)
```

## Dataset

```@docs
Dataset(X::AbstractMatrix{T},
        y::AbstractVector{T};
        weights::Union{AbstractVector{T}, Nothing}=nothing,
        varMap::Union{Array{String, 1}, Nothing}=nothing
       ) where {T<:Real}
```
