module PopulationModule

using StatsBase: StatsBase
using BorrowChecker: OrBorrowed, @take
using DispatchDoctor: @unstable
using DynamicExpressions: AbstractExpression, string_tree
using ..CoreModule: AbstractOptions, Options, Dataset, RecordType, DATA_TYPE, LOSS_TYPE
using ..ComplexityModule: compute_complexity
using ..LossFunctionsModule: eval_cost, update_baseline_loss!
using ..AdaptiveParsimonyModule: RunningSearchStatistics
using ..MutationFunctionsModule: gen_random_tree
using ..PopMemberModule: PopMember
using ..UtilsModule: bottomk_fast, argmin_fast, PerTaskCache
# A list of members of the population, with easy constructors,
#  which allow for random generation of new populations
struct Population{T<:DATA_TYPE,L<:LOSS_TYPE,N<:AbstractExpression{T}}
    members::Array{PopMember{T,L,N},1}
    n::Int
end
"""
    Population(pop::Array{PopMember{T,L}, 1})

Create population from list of PopMembers.
"""
function Population(pop::Vector{<:PopMember})
    return Population(pop, size(pop, 1))
end

"""
    Population(dataset::Dataset{T,L};
               population_size, nlength::Int=3, options::AbstractOptions,
               nfeatures::Int)

Create random population and evaluate them on the dataset.
"""
function Population(
    dataset::OrBorrowed{Dataset{T,L}};
    options::AbstractOptions,
    population_size=nothing,
    nlength::Int=3,
    nfeatures::Int,
    npop=nothing,
) where {T,L}
    @assert (population_size !== nothing) ⊻ (npop !== nothing)
    population_size = if npop === nothing
        population_size
    else
        npop
    end
    return Population(
        [
            PopMember(
                dataset,
                gen_random_tree(nlength, options, nfeatures, T),
                options;
                parent=-1,
                deterministic=options.deterministic,
            ) for _ in 1:population_size
        ],
        population_size,
    )
end
"""
    Population(X::AbstractMatrix{T}, y::AbstractVector{T};
               population_size, nlength::Int=3,
               options::AbstractOptions, nfeatures::Int,
               loss_type::Type=Nothing)

Create random population and score them on the dataset.
"""
@unstable function Population(
    X::AbstractMatrix{T},
    y::AbstractVector{T};
    population_size=nothing,
    nlength::Int=3,
    options::AbstractOptions,
    nfeatures::Int,
    loss_type::Type{L}=Nothing,
    npop=nothing,
) where {T<:DATA_TYPE,L}
    @assert (population_size !== nothing) ⊻ (npop !== nothing)
    population_size = if npop === nothing
        population_size
    else
        npop
    end
    dataset = Dataset(X, y, L)
    update_baseline_loss!(dataset, options)
    return Population(
        dataset; population_size=population_size, options=options, nfeatures=nfeatures
    )
end

function Base.copy(pop::P)::P where {T,L,N,P<:Population{T,L,N}}
    copied_members = Vector{PopMember{T,L,N}}(undef, pop.n)
    Threads.@threads for i in 1:(pop.n)
        copied_members[i] = copy(pop.members[i])
    end
    return Population(copied_members)
end

# Sample random members of the population, and make a new one
function sample_pop(pop::P, options::AbstractOptions)::P where {P<:Population}
    return Population(
        StatsBase.sample(pop.members, options.tournament_selection_n; replace=false)
    )
end

# Sample the population, and get the best member from that sample
function best_of_sample(
    pop::Population{T,L,N},
    running_search_statistics::RunningSearchStatistics,
    options::AbstractOptions,
) where {T,L,N}
    sample = sample_pop(pop, options)
    return copy(_best_of_sample(sample.members, running_search_statistics, options))
end
function _best_of_sample(
    members::Vector{P},
    running_search_statistics::RunningSearchStatistics,
    options::AbstractOptions,
) where {T,L,P<:PopMember{T,L}}
    p = options.tournament_selection_p
    n = length(members)  # == tournament_selection_n
    adjusted_costs = Vector{L}(undef, n)
    if options.use_frequency_in_tournament
        # Score based on frequency of that size occurring.
        # In the end, all sizes should be just as common in the population.
        adaptive_parsimony_scaling = L(options.adaptive_parsimony_scaling)
        # e.g., for 100% occupied at one size, exp(-20*1) = 2.061153622438558e-9; which seems like a good punishment for dominating the population.

        for i in 1:n
            member = members[i]
            size = compute_complexity(member, options)
            frequency = if (0 < size <= options.maxsize)
                L(running_search_statistics.normalized_frequencies[size])
            else
                L(0)
            end
            adjusted_costs[i] = member.cost * exp(adaptive_parsimony_scaling * frequency)
        end
    else
        map!(_get_cost, adjusted_costs, members)
    end

    chosen_idx = if p == 1.0
        argmin_fast(adjusted_costs)
    else
        # First, decide what place we take (usually 1st place wins):
        tournament_winner = StatsBase.sample(get_tournament_selection_weights(options))
        # Then, find the member that won that place, given
        # their fitness:
        if tournament_winner == 1
            argmin_fast(adjusted_costs)
        else
            bottomk_fast(adjusted_costs, tournament_winner)[2][end]
        end
    end
    return members[chosen_idx]
end
_get_cost(member::PopMember) = member.cost

const CACHED_WEIGHTS =
    let init_k = collect(0:5),
        init_prob_each = 0.5f0 * (1 - 0.5f0) .^ init_k,
        test_weights = StatsBase.Weights(init_prob_each, sum(init_prob_each))

        PerTaskCache{Dict{Tuple{Int,Float32},typeof(test_weights)}}()
    end

@unstable function get_tournament_selection_weights(@nospecialize(options::AbstractOptions))
    n = options.tournament_selection_n::Int
    p = options.tournament_selection_p::Float32
    # Computing the weights for the tournament becomes quite expensive,
    return get!(CACHED_WEIGHTS[], (n, p)) do
        k = collect(0:(n - 1))
        prob_each = p * ((1 - p) .^ k)

        return StatsBase.Weights(prob_each, sum(prob_each))
    end
end

function finalize_costs(
    dataset::Dataset{T,L}, pop::P, options::AbstractOptions
)::Tuple{P,Float64} where {T,L,P<:Population{T,L}}
    need_recalculate = options.batching
    num_evals = 0.0
    if need_recalculate
        for member in 1:(pop.n)
            cost, loss = eval_cost(dataset, pop.members[member], options)
            pop.members[member].cost = cost
            pop.members[member].loss = loss
        end
        num_evals += pop.n
    end
    return (pop, num_evals)
end

# Return best 10 examples
function best_sub_pop(pop::P; topn::Int=10)::P where {P<:Population}
    best_idx = sortperm([pop.members[member].cost for member in 1:(pop.n)])
    return Population(pop.members[best_idx[1:topn]])
end

function record_population(pop::Population, options::AbstractOptions)::RecordType
    return RecordType(
        "population" => [
            RecordType(
                "tree" => string_tree(member.tree, options; pretty=false),
                "loss" => member.loss,
                "cost" => member.cost,
                "complexity" => compute_complexity(member, options),
                "birth" => member.birth,
                "ref" => member.ref,
                "parent" => member.parent,
            ) for member in pop.members
        ],
        "time" => time(),
    )
end

end
