module MutationWeightsModule

using StatsBase: StatsBase

"""
    AbstractMutationWeights

An abstract type that defines the interface for mutation weight structures in the symbolic regression framework. Subtypes of `AbstractMutationWeights` specify how often different mutation operations occur during the mutation process.

You can create custom mutation weight types by subtyping `AbstractMutationWeights` and defining your own mutation operations. Additionally, you can overload the `sample_mutation` function to handle sampling from your custom mutation types.

# Usage

To create a custom mutation weighting scheme with new mutation types, define a new subtype of `AbstractMutationWeights` and implement the necessary fields. Here's an example using `Base.@kwdef` to define the struct with default values:

```julia
using SymbolicRegression: AbstractMutationWeights

# Define custom mutation weights with default values
Base.@kwdef struct MyMutationWeights <: AbstractMutationWeights
    mutate_constant::Float64 = 0.1
    mutate_operator::Float64 = 0.2
    custom_mutation::Float64 = 0.7
end
```

Next, overload the `sample_mutation` function to include your custom mutation types:

```julia
# Define the list of mutation names (symbols)
const MY_MUTATIONS = [
    :mutate_constant,
    :mutate_operator,
    :custom_mutation
]

# Import the `sample_mutation` function to overload it
import SymbolicRegression: sample_mutation
using StatsBase: StatsBase

# Overload the `sample_mutation` function
function sample_mutation(w::MyMutationWeights)
    weights = [
        w.mutate_constant,
        w.mutate_operator,
        w.custom_mutation
    ]
    weights = weights ./ sum(weights)  # Normalize weights to sum to 1.0
    return StatsBase.sample(MY_MUTATIONS, StatsBase.Weights(weights))
end

# Pass it when defining `Options`:
using SymbolicRegression: Options
options = Options(mutation_weights=MyMutationWeights())
```

This allows you to customize the mutation sampling process to include your custom mutations according to their specified weights.

To integrate your custom mutations into the mutation process, ensure that the mutation functions corresponding to your custom mutation types are defined and properly registered with the symbolic regression framework. You may need to define methods for `mutate!` that handle your custom mutation types.

# See Also

- [`MutationWeights`](@ref): A concrete implementation of `AbstractMutationWeights` that defines default mutation weightings.
- [`sample_mutation`](@ref): Function to sample a mutation based on current mutation weights.
- [`mutate!`](@ref): Function to apply a mutation to an expression tree.
- [`AbstractOptions`](@ref): See how to extend abstract types for customizing options.
"""
abstract type AbstractMutationWeights end

"""
    MutationWeights(;kws...) <: AbstractMutationWeights

This defines how often different mutations occur. These weightings
will be normalized to sum to 1.0 after initialization.

# Arguments

- `mutate_constant::Float64`: How often to mutate a constant.
- `mutate_operator::Float64`: How often to mutate an operator.
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
- `form_connection::Float64`: **Only used for `GraphNode`, not regular `Node`**.
    Otherwise, this will automatically be set to 0.0. How often to form a
    connection between two nodes.
- `break_connection::Float64`: **Only used for `GraphNode`, not regular `Node`**.
    Otherwise, this will automatically be set to 0.0. How often to break a
    connection between two nodes.

# See Also

- [`AbstractMutationWeights`](@ref): Use to define custom mutation weight types.
"""
Base.@kwdef mutable struct MutationWeights <: AbstractMutationWeights
    mutate_constant::Float64 = 0.048
    mutate_operator::Float64 = 0.47
    swap_operands::Float64 = 0.1
    rotate_tree::Float64 = 0.3
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
function sample_mutation(w::AbstractMutationWeights)
    weights = convert(Vector, w)
    return StatsBase.sample(v_mutations, StatsBase.Weights(weights))
end

end
