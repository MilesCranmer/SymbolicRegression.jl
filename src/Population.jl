module PopulationModule

using StatsBase: StatsBase
import Random: randperm
import DynamicExpressions: string_tree
import ..CoreModule: Options, Dataset, RecordType
import ..ComplexityModule: compute_complexity
import ..LossFunctionsModule: score_func, update_baseline_loss!
import ..AdaptiveParsimonyModule: RunningSearchStatistics
import ..MutationFunctionsModule: gen_random_tree
import ..PopMemberModule: PopMember
# A list of members of the population, with easy constructors,
#  which allow for random generation of new populations
mutable struct Population{T<:Real}
    members::Array{PopMember{T},1}
    n::Int
end
"""
    Population(pop::Array{PopMember{T}, 1})

Create population from list of PopMembers.
"""
Population(pop::Array{PopMember{T},1}) where {T<:Real} = Population{T}(pop, size(pop, 1))
"""
    Population(dataset::Dataset{T};
               npop::Int, nlength::Int=3, options::Options,
               nfeatures::Int)

Create random population and score them on the dataset.
"""
function Population(
    dataset::Dataset{T}; npop::Int, nlength::Int=3, options::Options, nfeatures::Int
) where {T<:Real}
    return Population{T}(
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
               options::Options, nfeatures::Int)

Create random population and score them on the dataset.
"""
function Population(
    X::AbstractMatrix{T},
    y::AbstractVector{T};
    npop::Int,
    nlength::Int=3,
    options::Options,
    nfeatures::Int,
) where {T<:Real}
    dataset = Dataset(X, y)
    update_baseline_loss!(dataset, options)
    return Population(dataset; npop=npop, options=options, nfeatures=nfeatures)
end

# Sample random members of the population, and make a new one
function sample_pop(pop::Population{T}, options::Options)::Population{T} where {T}
    return Population(StatsBase.sample(pop.members, options.ns; replace=false))
end

# Sample the population, and get the best member from that sample
function best_of_sample(
    pop::Population{T},
    running_search_statistics::RunningSearchStatistics,
    options::Options{A,B,p,ns},
)::PopMember where {T<:Real,A,B,p,ns}
    sample = sample_pop(pop, options)

    if options.useFrequencyInTournament
        # Score based on frequency of that size occuring.
        # In the end, all sizes should be just as common in the population.
        frequency_scaling = 20
        # e.g., for 100% occupied at one size, exp(-20*1) = 2.061153622438558e-9; which seems like a good punishment for dominating the population.

        scores = Vector{T}(undef, ns)
        for (i, member) in enumerate(sample.members)
            size = compute_complexity(member.tree, options)
            frequency = if (size <= options.maxsize)
                running_search_statistics.normalized_frequencies[size]
            else
                T(0)
            end
            scores[i] = member.score * exp(frequency_scaling * frequency)
        end
    else
        scores = [member.score for member in sample.members]
    end

    if p == 1.0
        chosen_idx = argmin(scores)
    else
        # First, decide what place we take (usually 1st place wins):
        tournament_winner = sample_tournament(Val(p), Val(ns))
        # Then, find the member that won that place, given
        # their fitness:
        chosen_idx = partialsortperm(scores, tournament_winner)
    end
    return sample.members[chosen_idx]
end

# This will compile the tournament probabilities, so it's a bit faster:
@generated function sample_tournament(::Val{p}, ::Val{ns})::Int where {p,ns}
    k = collect(0:(ns - 1))
    prob_each = p * ((1 - p) .^ k)
    indexes = collect(1:(ns))
    weights = StatsBase.Weights(prob_each, sum(prob_each))
    return quote
        StatsBase.sample($indexes, $weights)
    end
end

function finalize_scores(
    dataset::Dataset{T}, pop::Population, options::Options
)::Tuple{Population,Float64} where {T<:Real}
    need_recalculate = options.batching
    num_evals = 0.0
    if need_recalculate
        for member in 1:(pop.n)
            score, loss = score_func(dataset, pop.members[member].tree, options)
            pop.members[member].score = score
            pop.members[member].loss = loss
        end
        num_evals += pop.n * (options.batchSize / dataset.n)
    end
    return (pop, num_evals)
end

# Return best 10 examples
function best_sub_pop(pop::Population; topn::Int=10)::Population
    best_idx = sortperm([pop.members[member].score for member in 1:(pop.n)])
    return Population(pop.members[best_idx[1:topn]])
end

function record_population(pop::Population{T}, options::Options)::RecordType where {T<:Real}
    return RecordType(
        "population" => [
            RecordType(
                "tree" => string_tree(member.tree, options.operators),
                "loss" => member.loss,
                "score" => member.score,
                "complexity" => compute_complexity(member.tree, options),
                "birth" => member.birth,
                "ref" => member.ref,
                "parent" => member.parent,
            ) for member in pop.members
        ],
        "time" => time(),
    )
end

end
