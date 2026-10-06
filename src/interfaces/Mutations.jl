module MutationsModule

"""
    AbstractMutation

A mutation kind is a struct (often `Base.@kwdef` for per-mutation config)
subtyping `AbstractMutation`. The engine dispatches the per-cycle `mutate!`
method on the mutation's type; weight sampling, plugin observation hooks,
and `condition_mutation_weights!` all key off the type.

To add a new mutation kind, define a struct + a `mutate!` method:

```julia
struct MyMutation <: AbstractMutation end

function SymbolicRegression.mutate!(
    new_tree, parent_member, ::MyMutation, options; kws...
)
    # ... modify new_tree ...
    return SymbolicRegression.MutationResult{
        typeof(new_tree),typeof(parent_member)
    }(; tree=new_tree)
end
```

Then include it in `Options(; mutations = [MyMutation() => 0.1])`. An explicit
mutation replaces a default of the same type; new mutation types are added.
Pass `default_mutations=()` to disable every automatic default.

!!! warning "Experimental"
"""
abstract type AbstractMutation end

"""
    ConstantMutation(; perturbation_factor=0.086, probability_negate=0.01)

Perturb a random constant. `perturbation_factor` scales the magnitude;
`probability_negate` is the chance of flipping the constant's sign.

Plugins can scale the perturbation magnitude per call by mutating
[`ConstantMutationContext`](@ref) inside `condition_mutation!`.
"""
Base.@kwdef struct ConstantMutation <: AbstractMutation
    perturbation_factor::Float64 = 0.086
    probability_negate::Float64 = 0.01
end

"""
    ConstantMutationContext(; scale=1.0)

Per-call mutable companion of [`ConstantMutation`](@ref), built by
`prepare_mutation_context` and conditioned by plugins via
`condition_mutation!`. `scale` multiplies the mutation's
`perturbation_factor` for this call only; plugins compose by multiplying
in tuple order.

!!! warning "Experimental"
"""
Base.@kwdef mutable struct ConstantMutationContext
    scale::Float64 = 1.0
end

"""Swap a random operator for another of the same arity."""
struct OperatorMutation <: AbstractMutation end

"""Reassign a random variable leaf to a different input feature."""
struct FeatureMutation <: AbstractMutation end

"""Swap the operands of a random binary operator."""
struct SwapOperandsMutation <: AbstractMutation end

"""Append a random new operator (with fresh leaves) at a random leaf."""
struct AddNodeMutation <: AbstractMutation end

"""Insert a random new operator between an existing node and its parent."""
struct InsertNodeMutation <: AbstractMutation end

"""Delete a random non-leaf node, replacing it with one of its children."""
struct DeleteNodeMutation <: AbstractMutation end

"""Form a shared-subtree connection between two nodes (graph-mode only)."""
struct FormConnectionMutation <: AbstractMutation end

"""Break a shared-subtree connection by deep-copying one of the references."""
struct BreakConnectionMutation <: AbstractMutation end

"""Rotate a random subtree (rebalancing the AST)."""
struct RotateTreeMutation <: AbstractMutation end

"""
    BacksolveMutation(; max_library_size=500, max_terms=8, min_improvement=1e-3, node_attempts=8)

Invert a random non-root node by solving for its target values, then replace
it with a sparse-expression fit to those values, built by greedy forward
selection under the current complexity budget (`curmaxsize`), so proposed
rewrites respect the search's size constraint by construction.

The inversion is row-masked, so rows where the surrounding context is not
invertible are excluded from the fit instead of failing the whole mutation.
The subtree being replaced is included in the fit's library (so it can be
retained when already useful). Each mutation event tries up to
`node_attempts` random nodes and only returns a child whose cost improves on
the parent's; otherwise the mutation is reported as failed.

- `max_library_size`: maximum number of basis terms in the library.
- `max_terms`: maximum number of selected terms in the fitted weighted sum.
- `min_improvement`: minimum relative reduction of the residual norm required
  to add another term.

!!! warning
    Experimental. May change in minor version increments.
"""
Base.@kwdef struct BacksolveMutation <: AbstractMutation
    max_library_size::Int = 500
    max_terms::Int = 8
    min_improvement::Float64 = 1e-3
    node_attempts::Int = 8
end

"""Algebraically simplify the tree (e.g. fold constants)."""
struct SimplifyMutation <: AbstractMutation end

"""Replace the tree with a freshly generated random tree."""
struct RandomizeMutation <: AbstractMutation end

"""Run gradient-based constant optimization on the tree (reads optimizer settings from `options`)."""
struct OptimizeMutation <: AbstractMutation end

"""No-op mutation: copy the parent unchanged (acts as a sampling weight reserve)."""
struct DoNothingMutation <: AbstractMutation end

const BUILTIN_MUTATION_TYPES = (
    ConstantMutation,
    OperatorMutation,
    FeatureMutation,
    SwapOperandsMutation,
    AddNodeMutation,
    InsertNodeMutation,
    DeleteNodeMutation,
    FormConnectionMutation,
    BreakConnectionMutation,
    RotateTreeMutation,
    BacksolveMutation,
    SimplifyMutation,
    RandomizeMutation,
    OptimizeMutation,
    DoNothingMutation,
)

"""
    default_mutations() -> Vector{Pair{AbstractMutation,Float64}}

Default weighted mutation list. The deprecated `MutationWeights()` constructor
derives its defaults from this list.
"""
function default_mutations()
    return Pair{AbstractMutation,Float64}[
        ConstantMutation() => 0.0353,
        OperatorMutation() => 3.63,
        FeatureMutation() => 0.1,
        SwapOperandsMutation() => 0.00608,
        RotateTreeMutation() => 1.42,
        AddNodeMutation() => 0.0771,
        InsertNodeMutation() => 2.44,
        DeleteNodeMutation() => 0.369,
        SimplifyMutation() => 0.00148,
        RandomizeMutation() => 0.00695,
        DoNothingMutation() => 0.431,
        OptimizeMutation() => 0.0,
        BacksolveMutation() => 0.0,
        FormConnectionMutation() => 0.5,
        BreakConnectionMutation() => 0.1,
    ]
end

end  # module MutationsModule
