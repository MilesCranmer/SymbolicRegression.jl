module MutationWeightsModule

using StatsBase: StatsBase

"""
    MutationWeights(;kws...)

This defines how often different mutations occur. These weightings
will be normalized to sum to 1.0 after initialization.
# Arguments
- `mutate_constant::Float64`: How often to mutate a constant.
- `mutate_operator::Float64`: How often to mutate an operator.
- `swap_operands::Float64`: How often to swap the operands of a binary operator.
- `add_node::Float64`: How often to append a node to the tree.
- `insert_node::Float64`: How often to insert a node into the tree.
- `delete_node::Float64`: How often to delete a node from the tree.
- `simplify::Float64`: How often to simplify the tree.
- `randomize::Float64`: How often to create a random tree.
- `do_nothing::Float64`: How often to do nothing.
- `optimize::Float64`: How often to optimize the constants in the tree, as a mutation.
   Note that this is different from `optimizer_probability`, which is
   performed at the end of an iteration for all individuals.
- `form_connection::Float64`: **Only used for `GraphNode`, not regular `Node`**.
   Otherwise, this will automatically be set to 0.0. How often to form a
   connection between two nodes.
- `break_connection::Float64`: **Only used for `GraphNode`, not regular `Node`**.
   Otherwise, this will automatically be set to 0.0. How often to break a
   connection between two nodes.
"""
Base.@kwdef mutable struct MutationWeights
    mutate_constant::Float64 = 0.048
    mutate_operator::Float64 = 0.47
    swap_operands::Float64 = 0.1
    add_node::Float64 = 0.79
    insert_node::Float64 = 5.1
    delete_node::Float64 = 1.7
    simplify::Float64 = 0.0020
    randomize::Float64 = 0.00023
    do_nothing::Float64 = 0.21
    optimize::Float64 = 0.0
    form_connection::Float64 = 0.5
    break_connection::Float64 = 0.1
end

const mutations = fieldnames(MutationWeights)
const v_mutations = Symbol[mutations...]

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

"""Sample a mutation, given the weightings."""
function sample_mutation(w::MutationWeights)
    weights = convert(Vector, w)
    return StatsBase.sample(v_mutations, StatsBase.Weights(weights))
end

end
