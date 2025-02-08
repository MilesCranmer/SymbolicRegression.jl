# Types

## Equations

Equations are specified as binary trees with the `Node` type, defined
as follows.

```@docs
Node
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
set_node!
```

You can create a copy of a node with `copy_node`:

```@docs
copy_node(tree::Node)
```

## Expressions

Expressions are represented using the `Expression` type, which combines the raw `Node` type with an `OperatorEnum`.

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

You can use the `@template` macro as an easy way to create a `TemplateExpressionSpec`:

```@docs
@template
```

Composable expressions are used internally by `TemplateExpression` and allow you to combine multiple expressions together.

```@docs
ComposableExpression
```

### Parametric Expressions

Parametric expressions are a type of expression that includes parameters which can be optimized during the search.

```@docs
ParametricExpression
ParametricNode
ParametricExpressionSpec
```

These types allow you to define expressions with parameters that can be tuned to fit the data better. You can specify the maximum number of parameters using the `expression_options` argument in `SRRegressor`.

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
```

## Dataset

```@docs
Dataset
update_baseline_loss!
```
