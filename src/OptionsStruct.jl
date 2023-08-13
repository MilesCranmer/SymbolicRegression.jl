module OptionsStructModule

using Optim: Optim
using StatsBase: StatsBase
import DynamicExpressions: AbstractOperatorEnum
import LossFunctions: SupervisedLoss

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
    )
end

"""Sample a mutation, given the weightings."""
function sample_mutation(weightings::MutationWeights)
    weights = convert(Vector, weightings)
    return StatsBase.sample(mutations, StatsBase.Weights(weights))
end

"""This struct defines how complexity is calculated."""
struct ComplexityMapping{T<:Real}
    use::Bool  # Whether we use custom complexity, or just use 1 for everythign.
    binop_complexities::Vector{T}  # Complexity of each binary operator.
    unaop_complexities::Vector{T}  # Complexity of each unary operator.
    variable_complexity::T  # Complexity of using a variable.
    constant_complexity::T  # Complexity of using a constant.
end

Base.eltype(::ComplexityMapping{T}) where {T} = T

function ComplexityMapping(use::Bool)
    return ComplexityMapping{Int}(use, zeros(Int, 0), zeros(Int, 0), 1, 1)
end

"""Promote type when defining complexity mapping."""
function ComplexityMapping(;
    binop_complexities::Vector{T1},
    unaop_complexities::Vector{T2},
    variable_complexity::T3,
    constant_complexity::T4,
) where {T1<:Real,T2<:Real,T3<:Real,T4<:Real}
    promoted_T = promote_type(T1, T2, T3, T4)
    return ComplexityMapping{promoted_T}(
        true,
        binop_complexities,
        unaop_complexities,
        variable_complexity,
        constant_complexity,
    )
end

struct Options{CT,OP<:AbstractOperatorEnum,use_recorder,OPT<:Optim.Options,W}
    operators::OP
    bin_constraints::Vector{Tuple{Int,Int}}
    una_constraints::Vector{Int}
    complexity_mapping::ComplexityMapping{CT}
    tournament_selection_n::Int
    tournament_selection_p::Float32
    tournament_selection_weights::W
    parsimony::Float32
    dimensional_constraint_penalty::Union{Float32,Nothing}
    alpha::Float32
    maxsize::Int
    maxdepth::Int
    turbo::Bool
    migration::Bool
    hof_migration::Bool
    should_simplify::Bool
    should_optimize_constants::Bool
    output_file::String
    populations::Int
    perturbation_factor::Float32
    annealing::Bool
    batching::Bool
    batch_size::Int
    mutation_weights::MutationWeights
    crossover_probability::Float32
    warmup_maxsize_by::Float32
    use_frequency::Bool
    use_frequency_in_tournament::Bool
    adaptive_parsimony_scaling::Float64
    population_size::Int
    ncycles_per_iteration::Int
    fraction_replaced::Float32
    fraction_replaced_hof::Float32
    topn::Int
    verbosity::Union{Int,Nothing}
    print_precision::Int
    save_to_file::Bool
    probability_negate_constant::Float32
    nuna::Int
    nbin::Int
    seed::Union{Int,Nothing}
    elementwise_loss::Union{SupervisedLoss,Function}
    loss_function::Union{Nothing,Function}
    progress::Union{Bool,Nothing}
    terminal_width::Union{Int,Nothing}
    optimizer_algorithm::String
    optimizer_probability::Float32
    optimizer_nrestarts::Int
    optimizer_options::OPT
    recorder_file::String
    prob_pick_first::Float32
    early_stop_condition::Union{Function,Nothing}
    return_state::Union{Bool,Nothing}
    timeout_in_seconds::Union{Float64,Nothing}
    max_evals::Union{Int,Nothing}
    skip_mutation_failures::Bool
    nested_constraints::Union{Vector{Tuple{Int,Int,Vector{Tuple{Int,Int,Int}}}},Nothing}
    deterministic::Bool
    define_helper_functions::Bool
end

function Base.print(io::IO, options::Options)
    return print(
        io,
        "Options(" *
        "binops=$(options.operators.binops), " *
        "unaops=$(options.operators.unaops), "
        # Fill in remaining fields automatically:
        *
        join(
            [
                if fieldname in (:optimizer_options, :mutation_weights)
                    "$(fieldname)=..."
                else
                    "$(fieldname)=$(getfield(options, fieldname))"
                end for
                fieldname in fieldnames(Options) if fieldname ∉ [:operators, :nuna, :nbin]
            ],
            ", ",
        ) *
        ")",
    )
end
Base.show(io::IO, ::MIME"text/plain", options::Options) = Base.print(io, options)

end
