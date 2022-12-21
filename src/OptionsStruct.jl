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
@generated function MutationWeights(;
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
    return :(MutationWeights($(mutations...)))
end

"""Convert MutationWeights to a vector."""
@generated function Base.convert(
    ::Type{Vector}, weightings::MutationWeights
)::Vector{Float64}
    fields = [:(weightings.$(mut)) for mut in mutations]
    return :([$(fields...)])
end

"""Copy MutationWeights."""
@generated function Base.copy(weightings::MutationWeights)
    fields = [:(weightings.$(mut)) for mut in mutations]
    return :(MutationWeights($(fields...)))
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

struct Options{CT}
    operators::AbstractOperatorEnum
    bin_constraints::Vector{Tuple{Int,Int}}
    una_constraints::Vector{Int}
    complexity_mapping::ComplexityMapping{CT}
    tournament_selection_n::Int
    tournament_selection_p::Float32
    parsimony::Float32
    alpha::Float32
    maxsize::Int
    maxdepth::Int
    fast_cycle::Bool
    turbo::Bool
    migration::Bool
    hof_migration::Bool
    should_optimize_constants::Bool
    output_file::String
    npopulations::Int
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
    npop::Int
    ncycles_per_iteration::Int
    fraction_replaced::Float32
    fraction_replaced_hof::Float32
    topn::Int
    verbosity::Int
    save_to_file::Bool
    probability_negate_constant::Float32
    nuna::Int
    nbin::Int
    seed::Union{Int,Nothing}
    elementwise_loss::Union{SupervisedLoss,Function}
    loss_function::Union{Function,Nothing}
    progress::Bool
    terminal_width::Union{Int,Nothing}
    optimizer_algorithm::String
    optimizer_probability::Float32
    optimizer_nrestarts::Int
    optimizer_options::Optim.Options
    recorder::Bool
    recorder_file::String
    prob_pick_first::Float32
    early_stop_condition::Union{Function,Nothing}
    return_state::Bool
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
        """Options(
    # Operators:
        binops=$(options.operators.binops), unaops=$(options.operators.unaops),
    # Loss:
        loss=$(options.elementwise_loss),
    # Complexity Management:
        maxsize=$(options.maxsize), maxdepth=$(options.maxdepth), bin_constraints=$(options.bin_constraints), una_constraints=$(options.una_constraints), use_frequency=$(options.use_frequency), use_frequency_in_tournament=$(options.use_frequency_in_tournament), parsimony=$(options.parsimony), warmup_maxsize_by=$(options.warmup_maxsize_by), 
    # Search Size:
        npopulations=$(options.npopulations), ncycles_per_iteration=$(options.ncycles_per_iteration), npop=$(options.npop), 
    # Migration:
        migration=$(options.migration), hof_migration=$(options.hof_migration), fraction_replaced=$(options.fraction_replaced), fraction_replaced_hof=$(options.fraction_replaced_hof),
    # Tournaments:
        prob_pick_first=$(options.prob_pick_first), tournament_selection_n=$(options.tournament_selection_n), topn=$(options.topn), 
    # Constant tuning:
        perturbation_factor=$(options.perturbation_factor), probability_negate_constant=$(options.probability_negate_constant), should_optimize_constants=$(options.should_optimize_constants), optimizer_algorithm=$(options.optimizer_algorithm), optimizer_probability=$(options.optimizer_probability), optimizer_nrestarts=$(options.optimizer_nrestarts), optimizer_iterations=$(options.optimizer_options.iterations),
    # Mutations:
        mutation_weights=$(options.mutation_weights), crossover_probability=$(options.crossover_probability), skip_mutation_failures=$(options.skip_mutation_failures)
    # Annealing:
        annealing=$(options.annealing), alpha=$(options.alpha), 
    # Speed Tweaks:
        batching=$(options.batching), batch_size=$(options.batch_size), fast_cycle=$(options.fast_cycle), 
    # Logistics:
        output_file=$(options.output_file), verbosity=$(options.verbosity), seed=$(options.seed), progress=$(options.progress),
    # Early Exit:
        early_stop_condition=$(options.early_stop_condition), timeout_in_seconds=$(options.timeout_in_seconds),
)""",
    )
end
Base.show(io::IO, options::Options) = Base.print(io, options)

end
