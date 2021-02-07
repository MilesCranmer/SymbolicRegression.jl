# A list of members of the population, with easy constructors,
#  which allow for random generation of new populations
mutable struct Population{T<:Real}
    members::Array{PopMember{T}, 1}
    n::Int
end
"""
    Population(pop::Array{PopMember{T}, 1})

Create population from list of PopMembers.
"""
Population(pop::Array{PopMember{T}, 1}) where {T<:Real} = Population{T}(pop, size(pop, 1))
"""
    Population(dataset::Dataset{T}, baseline::T;
               npop::Int, nlength::Int=3, options::Options,
               nfeatures::Int)

Create random population and score them on the dataset.
"""
Population(dataset::Dataset{T}, baseline::T;
           npop::Int, nlength::Int=3,
           options::Options,
           nfeatures::Int) where {T<:Real} = Population([PopMember(dataset, baseline, genRandomTree(nlength, options, nfeatures), options) for i=1:npop], npop)
"""
    Population(X::AbstractMatrix{T}, y::AbstractVector{T},
               baseline::T; npop::Int, nlength::Int=3,
               options::Options, nfeatures::Int)

Create random population and score them on the dataset.
"""
Population(X::AbstractMatrix{T}, y::AbstractVector{T}, baseline::T;
           npop::Int, nlength::Int=3,
           options::Options,
           nfeatures::Int) where {T<:Real} = Population(Dataset(X, y), baseline, npop=npop, options=options, nfeatures=nfeatures)

# Sample 10 random members of the population, and make a new one
function samplePop(pop::Population, options::Options)::Population
    idx = rand(1:pop.n, options.ns)
    return Population(pop.members[idx])
end

# Sample the population, and get the best member from that sample
function bestOfSample(pop::Population, options::Options)::PopMember
    sample = samplePop(pop, options)
    best_idx = argmin([sample.members[member].score for member=1:sample.n])
    return sample.members[best_idx]
end

function finalizeScores(dataset::Dataset{T},
                        baseline::T, pop::Population,
                        options::Options)::Population where {T<:Real}
    need_recalculate = options.batching
    if need_recalculate
        @inbounds @simd for member=1:pop.n
            pop.members[member].score = scoreFunc(dataset, baseline,
                                                  pop.members[member].tree,
                                                  options)
        end
    end
    return pop
end

# Return best 10 examples
function bestSubPop(pop::Population; topn::Int=10)::Population
    best_idx = sortperm([pop.members[member].score for member=1:pop.n])
    return Population(pop.members[best_idx[1:topn]])
end

# Return best 10 examples size that are pareto dominating
function bestSubPopParetoDominating(pop::Population{T}; topn::Int=10)::Population where {T<:Real}
    scores = [pop.members[member].score for member=1:pop.n]
    best_idx = sortperm(scores)

    sorted = pop.members[best_idx]
    score_sorted = scores[best_idx]
    sizes = [countNodes(sorted[i].tree) for i=1:pop.n]

    best = [1]
    for i=2:pop.n
        better_than_all_smaller = true
        for j=i-1:1
            if sizes[j] < sizes[i] #Another model is smaller AND better
                better_than_all_smaller = false
                break
            end
        end
        if better_than_all_smaller
            best = vcat(best, [i])
        end
        if length(best) == topn
            break
        end
    end
    return Population(sorted[best])
end


