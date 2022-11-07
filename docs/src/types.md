# Types

## Equations

Equations are specified as binary trees with the `Node` type, defined
as follows:

```@docs
Node{T<:Real}
```

There are a variety of constructors for `Node` objects, including:

```@docs
Node(; val::Real=nothing, feature::Integer=nothing)
Node(op::Int, l::Node)
Node(op::Int, l::Node, r::Node)
Node(var_string::String)
```

When you create an `Options` object, the operators
passed are also re-defined for `Node` types.
This allows you use, e.g., `t=Node(; feature=1) * 3f0` to create a tree, so long as
`*` was specified as a binary operator. This works automatically for
operators defined in `Base`, although you can also get this to work
for user-defined operators by using `@extend_operators`:

```@docs
@extend_operators options
```

When using these node constructors, types will automatically be promoted.
You can convert the type of a node using `convert`:

```@docs
convert(::Type{Node{T1}}, tree::Node{T2}) where {T1, T2}
```

You can set a `tree` (in-place) with `set_node!`:

```@docs
set_node!(tree::Node{T}, new_tree::Node{T}) where {T}
```

You can create a copy of a node with `copy_node`:

```@docs
copy_node(tree::Node)
```

## Population

Groups of equations are given as a population, which is
an array of trees tagged with score, loss, and birthdate---these
values are given in the `PopMember`.

```@docs
Population(pop::Array{PopMember{T}, 1}) where {T<:Real}
Population(dataset::Dataset{T};
           npop::Int, nlength::Int=3,
           options::Options,
           nfeatures::Int) where {T<:Real}
Population(X::AbstractMatrix{T}, y::AbstractVector{T};
           npop::Int, nlength::Int=3,
           options::Options,
           nfeatures::Int) where {T<:Real}
```

## Population members

```@docs
PopMember(t::Node{T}, score::T, loss::T) where {T<:Real}
PopMember(dataset::Dataset{T}, t::Node{T}, options::Options) where {T<:Real}
```

## Hall of Fame

```@docs
HallOfFame(options::Options, ::Type{T}) where {T<:Real}
```

## Dataset

```@docs
Dataset{T<:Real}
Dataset(X::AbstractMatrix{T},
        y::AbstractVector{T};
        weights::Union{AbstractVector{T}, Nothing}=nothing,
        varMap::Union{Array{String, 1}, Nothing}=nothing
       ) where {T<:Real}
update_baseline_loss!(dataset::Dataset{T}, options::Options) where {T<:Real}
```
