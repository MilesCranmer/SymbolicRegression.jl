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
               npop::Int, nlength::Int=3, options::Options,
               nfeatures::Int)

Create random population and score them on the dataset.
"""
function Population(
    dataset::Dataset{T,L}; npop::Int, nlength::Int=3, options::Options, nfeatures::Int
) where {T<:DATA_TYPE,L<:LOSS_TYPE}
    return Population{T,L}(
        [
            PopMember(
                dataset,
                gen_random_tree(nlength, options, nfeatures, T),
                options;
                parent=-1,
                deterministic=options.deterministic,
            ) for i in 1:npop
        ],
        npop,
    )
end
"""
    Population(X::AbstractMatrix{T}, y::AbstractVector{T};
               npop::Int, nlength::Int=3,
               options::Options, nfeatures::Int,
               loss_type::Type=Nothing)

Create random population and score them on the dataset.
"""
function Population(
    X::AbstractMatrix{T},
    y::AbstractVector{T};
    npop::Int,
    nlength::Int=3,
    options::Options,
    nfeatures::Int,
    loss_type::Type=Nothing,
) where {T<:DATA_TYPE}
    dataset = Dataset(X, y; loss_type=loss_type)
    update_baseline_loss!(dataset, options)
    return Population(dataset; npop=npop, options=options, nfeatures=nfeatures)
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
    options::Options{CT},
)::PopMember{T,L} where {T<:DATA_TYPE,L<:LOSS_TYPE,CT}
    sample = sample_pop(pop, options)

    p = options.tournament_selection_p
    tournament_selection_n = options.tournament_selection_n

    if options.use_frequency_in_tournament
        # Score based on frequency of that size occuring.
        # In the end, all sizes should be just as common in the population.
        adaptive_parsimony_scaling = L(options.adaptive_parsimony_scaling)
        # e.g., for 100% occupied at one size, exp(-20*1) = 2.061153622438558e-9; which seems like a good punishment for dominating the population.

        scores = Vector{L}(undef, tournament_selection_n)
        for (i, member) in enumerate(sample.members)
            size = compute_complexity(member, options)
            frequency = if (0 < size <= options.maxsize)
                running_search_statistics.normalized_frequencies[size]
            else
                L(0)
            end
            scores[i] = member.score * exp(adaptive_parsimony_scaling * frequency)
        end
    else
        scores = [member.score for member in sample.members]
    end

    if p == 1.0
        chosen_idx = argmin(scores)
    else
        # First, decide what place we take (usually 1st place wins):
        tournament_winner = sample_tournament(Val(p), Val(tournament_selection_n))
        # Then, find the member that won that place, given
        # their fitness:
        chosen_idx = partialsortperm(scores, tournament_winner)
    end
    return sample.members[chosen_idx]
end

# This will compile the tournament probabilities, so it's a bit faster:
@generated function sample_tournament(
    ::Val{p}, ::Val{tournament_selection_n}
)::Int where {p,tournament_selection_n}
    k = collect(0:(tournament_selection_n - 1))
    prob_each = p * ((1 - p) .^ k)
    indexes = collect(1:(tournament_selection_n))
    weights = StatsBase.Weights(prob_each, sum(prob_each))
    return quote
        StatsBase.sample($indexes, $weights)
    end
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
                "tree" => string_tree(member.tree, options.operators),
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
