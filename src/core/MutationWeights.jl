module MutationWeightsModule

import ..MutationsModule:
    AbstractMutation,
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
    default_mutations

using StatsBase: StatsBase

"""
    MutationWeights(;kws...)

This defines how often different mutations occur. These weightings
will be normalized to sum to 1.0 after initialization.

!!! warning
    `MutationWeights` is deprecated. Pass weighted mutation instances through
    `Options(; mutations=...)`.

# Arguments

- `mutate_constant::Float64`: How often to mutate a constant.
- `mutate_operator::Float64`: How often to mutate an operator.
- `mutate_feature::Float64`: How often to mutate which feature a variable node references.
- `swap_operands::Float64`: How often to swap the operands of a binary operator.
- `rotate_tree::Float64`: How often to perform a tree rotation at a random node.
- `add_node::Float64`: How often to append a node to the tree.
- `insert_node::Float64`: How often to insert a node into the tree.
- `delete_node::Float64`: How often to delete a node from the tree.
- `simplify::Float64`: How often to simplify the tree.
- `randomize::Float64`: How often to create a random tree.
- `do_nothing::Float64`: How often to do nothing.
- `optimize::Float64`: How often to optimize the constants in the tree, as a mutation.
    Note that this is different from `optimizer_probability`, which is
    performed at the end of an iteration for all individuals.
- `backsolve::Float64`: How often to backsolve and rewrite a random subtree
    by inverting the evaluation path and fitting a replacement expression.
    **Experimental:** this mutation will change in minor version increments.
- `form_connection::Float64`: **Only used for `GraphNode`, not regular `Node`**.
    Otherwise, this will automatically be set to 0.0. How often to form a
    connection between two nodes.
- `break_connection::Float64`: **Only used for `GraphNode`, not regular `Node`**.
    Otherwise, this will automatically be set to 0.0. How often to break a
    connection between two nodes.

# See Also

- [`AbstractMutation`](@ref): Use to define custom mutation types.
"""
mutable struct MutationWeights
    mutate_constant::Float64
    mutate_operator::Float64
    mutate_feature::Float64
    swap_operands::Float64
    rotate_tree::Float64
    add_node::Float64
    insert_node::Float64
    delete_node::Float64
    simplify::Float64
    randomize::Float64
    do_nothing::Float64
    optimize::Float64
    backsolve::Float64
    form_connection::Float64
    break_connection::Float64
end

const mutations = fieldnames(MutationWeights)

# For some reason it's much faster to write out the fields explicitly:
let contents = [Expr(:., :w, QuoteNode(field)) for field in mutations]
    @eval begin
        function Base.convert(::Type{Vector}, w::MutationWeights)::Vector{Float64}
            return $(Expr(:vect, contents...))
        end
        function Base.copy(w::MutationWeights)
            return $(Expr(:call, :MutationWeights, contents...))
        end
    end
end

const _MUTATION_FROM_SYMBOL = Dict{Symbol,AbstractMutation}(
    :mutate_constant => ConstantMutation(),
    :mutate_operator => OperatorMutation(),
    :mutate_feature => FeatureMutation(),
    :swap_operands => SwapOperandsMutation(),
    :rotate_tree => RotateTreeMutation(),
    :add_node => AddNodeMutation(),
    :insert_node => InsertNodeMutation(),
    :delete_node => DeleteNodeMutation(),
    :simplify => SimplifyMutation(),
    :randomize => RandomizeMutation(),
    :do_nothing => DoNothingMutation(),
    :optimize => OptimizeMutation(),
    :backsolve => BacksolveMutation(),
    :form_connection => FormConnectionMutation(),
    :break_connection => BreakConnectionMutation(),
)

function _mutation_weights(; kws...)
    unknown = setdiff(keys(kws), mutations)
    isempty(unknown) ||
        throw(ArgumentError("Unknown mutation weight: `$(first(unknown))`."))

    defaults = Dict(
        typeof(mutation) => weight for (mutation, weight) in default_mutations()
    )
    values = map(mutations) do name
        Float64(get(kws, name, defaults[typeof(_MUTATION_FROM_SYMBOL[name])]))
    end
    return MutationWeights(values...)
end

function MutationWeights(; kws...)
    Base.depwarn(
        "`MutationWeights` is deprecated. Pass weighted mutation instances through `Options(; mutations=...)`.",
        :MutationWeights,
    )
    return _mutation_weights(; kws...)
end

"""
    _mutations_from_weights(w) -> Vector{Pair{AbstractMutation,Float64}}

Convert built-in mutation weights to the mutation list used by `Options`.
"""
function _mutations_from_weights(w::MutationWeights)
    return Pair{AbstractMutation,Float64}[
        _MUTATION_FROM_SYMBOL[k] => Float64(getfield(w, k)) for k in fieldnames(typeof(w))
    ]
end

using DispatchDoctor: @unstable

"""
    sample_mutation(mutations) -> AbstractMutation

Pick a mutation kind by weight. Returns the singleton instance.

Marked `@unstable` because the return type is `AbstractMutation` — the
concrete subtype is selected at runtime by weighted sampling. The caller
hands the result to `mutate!`, which dispatches per concrete type, so the
instability is contained.
"""
@unstable function sample_mutation(
    mutations::AbstractVector{<:Pair{<:AbstractMutation,<:Real}},  # COV_EXCL_LINE
)
    idx = StatsBase.sample(eachindex(mutations), StatsBase.Weights(map(last, mutations)))
    return mutations[idx].first
end

end
