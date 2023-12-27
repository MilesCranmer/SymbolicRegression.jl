module MutationWeightsModule

using StatsBase: StatsBase

mutable struct MutationWeights
    mutate_constant::Float64
    mutate_operator::Float64
    add_node::Float64
    insert_node::Float64
    delete_node::Float64
    simplify::Float64
    randomize::Float64
    do_nothing::Float64
    optimize::Float64
    form_connection::Float64
    break_connection::Float64
end

const mutations = [fieldnames(MutationWeights)...]

"""
    MutationWeights(;kws...)

This defines how often different mutations occur. These weightings
will be normalized to sum to 1.0 after initialization.
# Arguments
- `mutate_constant::Float64`: How often to mutate a constant.
- `mutate_operator::Float64`: How often to mutate an operator.
- `add_node::Float64`: How often to append a node to the tree.
- `insert_node::Float64`: How often to insert a node into the tree.
- `delete_node::Float64`: How often to delete a node from the tree.
- `simplify::Float64`: How often to simplify the tree.
- `randomize::Float64`: How often to create a random tree.
- `do_nothing::Float64`: How often to do nothing.
- `optimize::Float64`: How often to optimize the constants in the tree, as a mutation.
- `form_connection::Float64`: How often to form a connection between two nodes. If
  the node does not preserve sharing, this will automatically be set to 0.0.
- `break_connection::Float64`: How often to break a connection between two nodes. If
    the node does not preserve sharing, this will automatically be set to 0.0.
  Note that this is different from `optimizer_probability`, which is
  performed at the end of an iteration for all individuals.
"""
function MutationWeights(;
    mutate_constant=0.048,
    mutate_operator=0.47,
    add_node=0.79,
    insert_node=5.1,
    delete_node=1.7,
    simplify=0.0020,
    randomize=0.00023,
    do_nothing=0.21,
    optimize=0.0,
    form_connection=0.05,
    break_connection=0.05,
)
    return MutationWeights(
        mutate_constant,
        mutate_operator,
        add_node,
        insert_node,
        delete_node,
        simplify,
        randomize,
        do_nothing,
        optimize,
        form_connection,
        break_connection,
    )
end

"""Convert MutationWeights to a vector."""
function Base.convert(::Type{Vector}, w::MutationWeights)::Vector{Float64}
    return [
        w.mutate_constant,
        w.mutate_operator,
        w.add_node,
        w.insert_node,
        w.delete_node,
        w.simplify,
        w.randomize,
        w.do_nothing,
        w.optimize,
        w.form_connection,
        w.break_connection,
    ]
end

"""Copy MutationWeights."""
function Base.copy(weights::MutationWeights)
    return MutationWeights(
        weights.mutate_constant,
        weights.mutate_operator,
        weights.add_node,
        weights.insert_node,
        weights.delete_node,
        weights.simplify,
        weights.randomize,
        weights.do_nothing,
        weights.optimize,
        weights.form_connection,
        weights.break_connection,
    )
end

"""Sample a mutation, given the weightings."""
function sample_mutation(weightings::MutationWeights)
    weights = convert(Vector, weightings)
    return StatsBase.sample(mutations, StatsBase.Weights(weights))
end

end