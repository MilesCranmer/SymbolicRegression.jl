# A list of members of the population, with easy constructors,
#  which allow for random generation of new populations
mutable struct Population{T<:AbstractFloat}
    members::Array{PopMember{T}, 1}
    n::Integer
end

function Population(pop::Array{PopMember{T}, 1}) where {T<:AbstractFloat}
    Population{T}(pop, size(pop)[1])
end

function Population(pop::Array{PopMember{T}, 1}, npop::Integer) where {T<:AbstractFloat}
    Population{T}(pop, npop)
end

function Population(X::AbstractMatrix{T}, y::AbstractVector{T},
                    baseline::T, npop::Integer, options::Options,
                    nfeatures::Int) where {T<:AbstractFloat}
    Population([PopMember(X, y, baseline, genRandomTree(3, options, nfeatures), options) for i=1:npop], npop)
end

function Population(X::AbstractMatrix{T}, y::AbstractVector{T},
                    baseline::T, npop::Integer, nlength::Integer,
                    options::Options, nfeatures::Int) where {T<:AbstractFloat}
    Population([PopMember(X, y, baseline, genRandomTree(nlength, options, nfeatures), options) for i=1:npop], npop)
end

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

function finalizeScores(X::AbstractMatrix{T}, y::AbstractVector{T},
                        baseline::T, pop::Population,
                        options::Options)::Population where {T<:AbstractFloat}
    need_recalculate = options.batching
    if need_recalculate
        @inbounds @simd for member=1:pop.n
            pop.members[member].score = scoreFunc(X, y, baseline,
                                                  pop.members[member].tree,
                                                  options)
        end
    end
    return pop
end

# Return best 10 examples
function bestSubPop(pop::Population; topn::Integer=10)::Population
    best_idx = sortperm([pop.members[member].score for member=1:pop.n])
    return Population(pop.members[best_idx[1:topn]])
end

