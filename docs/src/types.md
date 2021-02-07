# Types

## Equations (`Node`)

```@doc
Node(val::CONST_TYPE)
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
```@doc
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
```@doc
PopMember(tree::Node, score::T, birth::Int) where {T<:Real}
PopMember(t::Node, score::T) where {T<:Real}
PopMember(dataset::Dataset{T}, baseline::T, t::Node)
```

## Hall of Fame

```@doc
HallOfFame(options::Options)
HallOfFame(members::Array{PopMember, 1}, exists::Array{Bool, 1})
```
