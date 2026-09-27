# Types

## Equations

Equations are specified as binary trees with the `Node` type, defined
as follows.

```@docs
Node
```

When you create an [`Options`](@ref) object, the operators
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
set_node!
```

You can create a copy of a node with `copy_node`:

```@docs
copy_node(tree::Node)
```

## Generic Node Accessors

For accessing and modifying the children of a node:

```@docs
get_child
set_child!
get_children
set_children!
```

## Expressions

Expressions are represented using the [`Expression`](@ref) type, which combines the raw [`Node`](@ref) type with an `OperatorEnum`.

```@docs
Expression
ExpressionSpec
```

These types allow you to define and manipulate expressions with a clear separation between the structure and the operators used.

### Template Expressions

Template expressions allow you to specify predefined structures and constraints for your expressions.
These use `ComposableExpressions` as their internal expression type, which makes them
flexible for creating a structure out of a single function.

These use the `TemplateStructure` type to define how expressions should be combined and evaluated.

```@docs
TemplateExpression
TemplateStructure
TemplateExpressionSpec
```

You can use the `@template_spec` macro as an easy way to create a `TemplateExpressionSpec`:

```@docs
@template_spec
```

Composable expressions are used internally by `TemplateExpression` and allow you to combine multiple expressions together.

```@docs
ComposableExpression
```

## Population

Groups of equations are given as a population, which is
an array of trees tagged with cost, loss, and birthdate---these
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
```

## Dataset

```@docs
Dataset
update_baseline_loss!
```
