# Types

## Equations

Equations are specified as binary trees with the `Node` type. Operators
defined in `Base` are re-defined for Node types, so that one can
use, e.g., `t=Node("x1") * 3f0` to create a tree, so long as
`*` was specified as a binary operator.

```@docs
Node{T<:Real}
Node(; val::Real=nothing, feature::Integer=nothing)
Node(op::Int, l::Node)
Node(op::Int, l::Node, r::Node)
Node(var_string::String)
convert(::Type{Node{T1}}, tree::Node{T2}) where {T1, T2}
```

## Population

Groups of equations are given as a population, which is
an array of trees tagged with score, loss, and birthdate---these
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
PopMember(t::Node{T}, score::T, loss::T) where {T<:Real}
PopMember(dataset::Dataset{T}, baseline::T, t::Node{T}, options::Options) where {T<:Real}
```

## Hall of Fame

```@docs
HallOfFame(options::Options, ::Type{T}) where {T<:Real}
```

## Dataset

```@docs
Dataset(X::AbstractMatrix{T},
        y::AbstractVector{T};
        weights::Union{AbstractVector{T}, Nothing}=nothing,
        varMap::Union{Array{String, 1}, Nothing}=nothing
       ) where {T<:Real}
```
