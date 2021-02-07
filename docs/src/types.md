# Types

## Dataset

```@docs
Dataset(X::AbstractMatrix{T},
        y::AbstractVector{T};
        weights::Union{AbstractVector{T}, Nothing}=nothing,
        varMap::Union{Array{String, 1}, Nothing}=nothing
       ) where {T<:Real}
```

## Equations

Equations are specified as binary trees with the `Node` type.

```@docs
Node(val::Float32)
Node(feature::Int)
Node(val::AbstractFloat)
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
Population(members::Array{PopMember{T}, 1}, n::Int) where {T<:Real}
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
PopMember(tree::Node, score::T, birth::Int) where {T<:Real}
PopMember(t::Node, score::T) where {T<:Real}
PopMember(dataset::Dataset{T}, baseline::T, t::Node) where {T<:Real}
```

## Hall of Fame

```@docs
HallOfFame(options::Options)
HallOfFame(members::Array{PopMember, 1}, exists::Array{Bool, 1})
```
