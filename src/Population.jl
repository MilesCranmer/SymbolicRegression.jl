module PopulationModule

import Random: randperm
import ..CoreModule: Options, Dataset, RecordType, stringTree
import ..EquationUtilsModule: countNodes
import ..LossFunctionsModule: scoreFunc
import ..MutationFunctionsModule: genRandomTree
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
    Population(dataset::Dataset{T}, baseline::T;
               npop::Int, nlength::Int=3, options::Options,
               nfeatures::Int)

Create random population and score them on the dataset.
"""
function Population(
    dataset::Dataset{T},
    baseline::T;
    npop::Int,
    nlength::Int=3,
    options::Options,
    nfeatures::Int,
) where {T<:Real}
    return Population(
        [
            PopMember(
                dataset, baseline, genRandomTree(nlength, options, nfeatures), options
            ) for i in 1:npop
        ],
        npop,
    )
end
"""
    Population(X::AbstractMatrix{T}, y::AbstractVector{T},
               baseline::T; npop::Int, nlength::Int=3,
               options::Options, nfeatures::Int)

Create random population and score them on the dataset.
"""
function Population(
    X::AbstractMatrix{T},
    y::AbstractVector{T},
    baseline::T;
    npop::Int,
    nlength::Int=3,
    options::Options,
    nfeatures::Int,
) where {T<:Real}
    return Population(
        Dataset(X, y), baseline; npop=npop, options=options, nfeatures=nfeatures
    )
end

# Sample 10 random members of the population, and make a new one
function samplePop(pop::Population, options::Options)::Population
    idx = randperm(pop.n)[1:(options.ns)]
    return Population(pop.members[idx])
end

# Sample the population, and get the best member from that sample
function bestOfSample(
    pop::Population, frequencyComplexity::AbstractVector{T}, options::Options
)::PopMember where {T<:Real}
    sample = samplePop(pop, options)

    if options.useFrequencyInTournament
        # Score based on frequency of that size occuring.
        # In the end, all sizes should be just as common in the population.
        frequency_scaling = 20
        # e.g., for 100% occupied at one size, exp(-20*1) = 2.061153622438558e-9; which seems like a good punishment for dominating the population.

        scores = [
            sample.members[member].score * exp(
                frequency_scaling *
                frequencyComplexity[countNodes(sample.members[member].tree)],
            ) for member in 1:(options.ns)
        ]
    else
        scores = [sample.members[member].score for member in 1:(options.ns)]
    end

    p = options.probPickFirst

    if p == 1.0
        chosen_idx = argmin(scores)
    else
        sort_idx = sortperm(scores)
        # scores[sort_idx] would put smallest first.

        k = collect(0:(options.ns - 1))
        prob_each = p * (1 - p) .^ k
        prob_each /= sum(prob_each)
        cumprob = cumsum(prob_each)
        raw_chosen_idx = findfirst(cumprob .> rand())

        # Sometimes, due to precision issues, we might have cumprob[end] < 1,
        # so we must check for nothing returned:
        if raw_chosen_idx === nothing
            chosen_idx = sort_idx[end]
        else
            chosen_idx = sort_idx[raw_chosen_idx]
        end
    end
    return sample.members[chosen_idx]
end

function finalizeScores(
    dataset::Dataset{T}, baseline::T, pop::Population, options::Options
)::Population where {T<:Real}
    need_recalculate = options.batching
    if need_recalculate
        @inbounds @simd for member in 1:(pop.n)
            score, loss = scoreFunc(dataset, baseline, pop.members[member].tree, options)
            pop.members[member].score = score
            pop.members[member].loss = loss
        end
    end
    return pop
end

# Return best 10 examples
function bestSubPop(pop::Population; topn::Int=10)::Population
    best_idx = sortperm([pop.members[member].score for member in 1:(pop.n)])
    return Population(pop.members[best_idx[1:topn]])
end

function record_population(pop::Population{T}, options::Options)::RecordType where {T<:Real}
    return RecordType(
        "population" => [
            RecordType(
                "tree" => stringTree(member.tree, options),
                "loss" => member.loss,
                "score" => member.score,
                "complexity" => countNodes(member.tree),
                "birth" => member.birth,
                "ref" => member.ref,
                "parent" => member.parent,
            ) for member in pop.members
        ],
        "time" => time(),
    )
end

end
