# Customization

Many parts of SymbolicRegression.jl are designed to be customizable.

The normal way to do this in Julia is to define a new type that subtypes
an abstract type from a package, and then define new methods for the type,
extending internal methods on that type.

## Custom Options

For example, you can define a custom options type:

```@docs
AbstractOptions
```

Any function in SymbolicRegression.jl you can generally define a new method
on your custom options type, to define custom behavior.

## Custom Mutations

You can define custom mutation operators by defining a new method on
`mutate!`, as well as subtyping `AbstractMutationWeights`:

```@docs
mutate!
AbstractMutationWeights
condition_mutation_weights!
sample_mutation
MutationResult
```

## Custom Expressions

You can create your own expression types by defining a new type that extends `AbstractExpression`.

```@docs
AbstractExpression
ExpressionInterface
```

The interface is fairly flexible, and permits you define specific functional forms,
extra parameters, etc. See the documentation of DynamicExpressions.jl for more details on what
methods you need to implement. Then, for SymbolicRegression.jl, you would
pass `expression_type` to the `Options` constructor, as well as any
`expression_options` you need (as a `NamedTuple`).

If needed, you may need to overload `SymbolicRegression.ExpressionBuilder.extra_init_params` in
case your expression needs additional parameters. See the method for `ParametricExpression`
as an example.

You can look at the files `src/ParametricExpression.jl` and `src/TemplateExpression.jl`
for more examples of custom expression types, though note that `ParametricExpression` itself
is defined in DynamicExpressions.jl, while that file just overloads some methods for
SymbolicRegression.jl.

## Other Customizations

Other internal abstract types include the following:

```@docs
AbstractRuntimeOptions
AbstractSearchState
```

These let you include custom state variables and runtime options.
