module PopulationModule

using StatsBase: StatsBase
import Random: randperm
import DynamicExpressions: string_tree
import ..CoreModule: Options, Dataset, RecordType, DATA_TYPE, LOSS_TYPE
import ..ComplexityModule: compute_complexity
import ..LossFunctionsModule: score_func, update_baseline_loss!
import ..AdaptiveParsimonyModule: RunningSearchStatistics
import ..MutationFunctionsModule: gen_random_tree
import ..PopMemberModule: PopMember, copy_pop_member
import ..UtilsModule: bottomk_fast, argmin_fast
# A list of members of the population, with easy constructors,
#  which allow for random generation of new populations
mutable struct Population{T<:DATA_TYPE,L<:LOSS_TYPE}
    members::Array{PopMember{T,L},1}
    n::Int
end
"""
    Population(pop::Array{PopMember{T,L}, 1})

Create population from list of PopMembers.
"""
function Population(
    pop::AP
) where {T<:DATA_TYPE,L<:LOSS_TYPE,AP<:AbstractArray{PopMember{T,L},1}}
    return Population{T,L}(pop, size(pop, 1))
end

"""
    Population(dataset::Dataset{T,L};
               population_size, nlength::Int=3, options::Options,
               nfeatures::Int)

Create random population and score them on the dataset.
"""
function Population(
    dataset::Dataset{T,L};
    population_size=nothing,
    nlength::Int=3,
    options::Options,
    nfeatures::Int,
    npop=nothing,
) where {T<:DATA_TYPE,L<:LOSS_TYPE}
    @assert (population_size !== nothing) ⊻ (npop !== nothing)
    population_size = if npop === nothing
        population_size
    else
        npop
    end
    return Population{T,L}(
        [
            PopMember(
                dataset,
                gen_random_tree(nlength, options, nfeatures, T),
                options;
                parent=-1,
                deterministic=options.deterministic,
            ) for i in 1:population_size
        ],
        population_size,
    )
end
"""
    Population(X::AbstractMatrix{T}, y::AbstractVector{T};
               population_size, nlength::Int=3,
               options::Options, nfeatures::Int,
               loss_type::Type=Nothing)

Create random population and score them on the dataset.
"""
function Population(
    X::AbstractMatrix{T},
    y::AbstractVector{T};
    population_size=nothing,
    nlength::Int=3,
    options::Options,
    nfeatures::Int,
    loss_type::Type=Nothing,
    npop=nothing,
) where {T<:DATA_TYPE}
    @assert (population_size !== nothing) ⊻ (npop !== nothing)
    population_size = if npop === nothing
        population_size
    else
        npop
    end
    dataset = Dataset(X, y; loss_type=loss_type)
    update_baseline_loss!(dataset, options)
    return Population(
        dataset; population_size=population_size, options=options, nfeatures=nfeatures
    )
end

function copy_population(pop::P)::P where {P<:Population}
    return Population([copy_pop_member(pm) for pm in pop.members])
end

# Sample random members of the population, and make a new one
function sample_pop(pop::P, options::Options)::P where {P<:Population}
    return Population(
        StatsBase.sample(pop.members, options.tournament_selection_n; replace=false)
    )
end

# Sample the population, and get the best member from that sample
function best_of_sample(
    pop::Population{T,L},
    running_search_statistics::RunningSearchStatistics,
    options::Options,
)::PopMember{T,L} where {T<:DATA_TYPE,L<:LOSS_TYPE}
    sample = sample_pop(pop, options)
    return _best_of_sample(sample.members, running_search_statistics, options)
end
function _best_of_sample(
    members::Vector{PopMember{T,L}},
    running_search_statistics::RunningSearchStatistics,
    options::Options,
) where {T,L}
    p = options.tournament_selection_p
    n = length(members)  # == tournament_selection_n
    scores = Vector{L}(undef, n)
    if options.use_frequency_in_tournament
        # Score based on frequency of that size occuring.
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
            scores[i] = member.score * exp(adaptive_parsimony_scaling * frequency)
        end
    else
        map!(member -> member.score, scores, members)
    end

    chosen_idx = if p == 1.0
        argmin_fast(scores)
    else
        # First, decide what place we take (usually 1st place wins):
        tournament_winner = StatsBase.sample(options.tournament_selection_weights)
        # Then, find the member that won that place, given
        # their fitness:
        if tournament_winner == 1
            argmin_fast(scores)
        else
            bottomk_fast(scores, tournament_winner)[2][end]
        end
    end
    return members[chosen_idx]
end

function finalize_scores(
    dataset::Dataset{T,L}, pop::Population{T,L}, options::Options
)::Tuple{Population{T,L},Float64} where {T<:DATA_TYPE,L<:LOSS_TYPE}
    need_recalculate = options.batching
    num_evals = 0.0
    if need_recalculate
        for member in 1:(pop.n)
            score, loss = score_func(dataset, pop.members[member], options)
            pop.members[member].score = score
            pop.members[member].loss = loss
        end
        num_evals += pop.n
    end
    return (pop, num_evals)
end

# Return best 10 examples
function best_sub_pop(pop::P; topn::Int=10)::P where {P<:Population}
    best_idx = sortperm([pop.members[member].score for member in 1:(pop.n)])
    return Population(pop.members[best_idx[1:topn]])
end

function record_population(pop::Population, options::Options)::RecordType
    return RecordType(
        "population" => [
            RecordType(
                "tree" => string_tree(member.tree, options),
                "loss" => member.loss,
                "score" => member.score,
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
