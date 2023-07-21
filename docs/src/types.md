# Types

## Equations

Equations are specified as binary trees with the `Node` type, defined
as follows:

```@docs
Node{T<:DATA_TYPE}
```

There are a variety of constructors for `Node` objects, including:

```@docs
Node(; val::DATA_TYPE=nothing, feature::Integer=nothing)
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
Population
```

## Population members

```@docs
PopMember
```

## Hall of Fame

```@docs
HallOfFame
HallOfFame(options::Options, ::Type{T}, ::Type{L}) where {T<:DATA_TYPE,L<:LOSS_TYPE}
```

## Dataset

```@docs
Dataset
Dataset(X::AbstractMatrix{T}, y::Union{AbstractVector{T},Nothing}=nothing;
        weights::Union{AbstractVector{T}, Nothing}=nothing,
        variable_names::Union{Array{String, 1}, Nothing}=nothing,
        y_variable_name::Union{String,Nothing}=nothing,
        extra::NamedTuple=NamedTuple(),
        loss_type::Type=Nothing,
        X_units::Union{AbstractVector, Nothing}=nothing,
        y_units=nothing,
) where {T<:DATA_TYPE}
update_baseline_loss!
```
