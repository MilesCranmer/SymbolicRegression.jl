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

Define a custom mutation by subtyping `AbstractMutation`, implementing `mutate!`,
and passing it with a weight through `Options(; mutations=...)`.

Here is a mutation that replaces a random subtree with a single variable:

```julia
using SymbolicRegression
using SymbolicRegression: AbstractMutation, MutationResult
using DynamicExpressions: get_contents, with_contents, AbstractExpression, AbstractExpressionNode

struct PruneMutation <: AbstractMutation end

function SymbolicRegression.mutate!(
    new_tree::N, parent_member::P, ::PruneMutation, options; nfeatures, kws...
) where {N<:AbstractExpression,P}
    tree = get_contents(new_tree)
    # Find a random non-leaf node and replace it with a variable
    nodes = filter(n -> n.degree > 0, collect(tree))
    if !isempty(nodes)
        target = rand(nodes)
        target.degree = 0
        target.feature = rand(1:nfeatures)
    end
    return MutationResult{N,P}(; tree=new_tree)
end
```

Pass it to `Options` with a weight. New mutation types are added alongside the
defaults; to replace or remove a default, pass `default_mutations=()`:

```julia
model = SRRegressor(
    binary_operators=[+, -, *, /],
    unary_operators=[cos],
    mutations=[PruneMutation() => 0.1],
)
```

```@docs
mutate!
AbstractMutation
condition_mutation_weights!
sample_mutation
MutationResult
```

## Custom Crossovers

Define a custom crossover by subtyping `AbstractCrossover`, implementing
`crossover`, and passing it with a weight through `Options(; crossovers=...)`.
Whenever the engine selects crossover (via `crossover_probability`), it samples
one crossover kind by weight from `options.crossovers` and retries it on
constraint failures, up to an attempt limit.

Here is a crossover that, instead of swapping subtrees, combines both parents
wholesale under a random binary operator (so `x + y` and `cos(x)` might produce
`(x + y) * cos(x)`):

```julia
using SymbolicRegression
using SymbolicRegression: AbstractCrossover, CrossoverResult
using DynamicExpressions: get_contents, with_contents

struct RootCrossover <: AbstractCrossover end

function SymbolicRegression.crossover(
    member1::P, member2::P, ::RootCrossover, options; kws...
) where {T,L,N,P<:PopMember{T,L,N}}
    t1 = get_contents(member1.tree)
    t2 = get_contents(member2.tree)
    op1, op2 = rand(1:length(options.operators.binops), 2)
    child1 = with_contents(member1.tree, Node(; op=op1, l=copy(t1), r=copy(t2)))
    child2 = with_contents(member2.tree, Node(; op=op2, l=copy(t2), r=copy(t1)))
    return CrossoverResult{N}(; child1, child2)
end
```

Pass it to `Options` with a weight. New crossover types are added alongside the
default `SubtreeCrossover`; to remove the default, pass `default_crossovers=()`:

```julia
model = SRRegressor(
    binary_operators=[+, -, *, /],
    unary_operators=[cos],
    crossovers=[RootCrossover() => 0.2],
)
```

The engine retries the sampled crossover when the children violate constraints,
passing a 1-based `attempt` keyword each time. A crossover that is expensive to
run (e.g. one backed by an external model) can check `attempt` and return
copies of the parents' trees on retries instead of re-running.

```@docs
crossover
AbstractCrossover
CrossoverResult
```

## Custom Expressions

You can create your own expression types by defining a new type that extends `AbstractExpression`.

```@docs
AbstractExpression
```

The interface is fairly flexible, and permits you define specific functional forms,
extra parameters, etc. See the documentation of DynamicExpressions.jl for more details on what
methods you need to implement. You can test the implementation of a given interface by using
`ExpressionInterface` which makes use of `Interfaces.jl`:

```@docs
ExpressionInterface
```

Then, for SymbolicRegression.jl, you would
pass `expression_type` to the `Options` constructor, as well as any
`expression_options` you need (as a `NamedTuple`).

If needed, you may need to overload `SymbolicRegression.ExpressionsModule.ExpressionBuilderModule.extra_init_params` in
case your expression needs additional parameters. See `src/expressions/TemplateExpression.jl` for an example.

You can also look at `src/expressions/TemplateExpression.jl` for a custom expression type used by
SymbolicRegression.jl.

## Plugins

See the [Plugins](plugins.md) page for how to hook into the search loop
with custom lifecycle callbacks, selection biases, and population seeding.

## Other Customizations

Other internal abstract types include the following:

```@docs
AbstractRuntimeOptions
AbstractSearchState
```

These let you include custom state variables and runtime options.
