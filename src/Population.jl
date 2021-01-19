# A list of members of the population, with easy constructors,
#  which allow for random generation of new populations
mutable struct Population
    members::Array{PopMember, 1}
    n::Integer

    Population(pop::Array{PopMember, 1}) = new(pop, size(pop)[1])
    Population(pop::Array{PopMember, 1}, npop::Integer) = new(pop, npop)

end

function Population(X::Array{Float32, 2}, y::Array{Float32, 1}, baseline::Float32, npop::Integer, options::Options, nfeatures::Int)
    Population([PopMember(X, y, baseline, genRandomTree(3, options, nfeatures), options) for i=1:npop], npop)
end

function Population(X::Array{Float32, 2}, y::Array{Float32, 1}, baseline::Float32, npop::Integer, nlength::Integer, options::Options, nfeatures::Int)
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

function finalizeScores(X::Array{Float32, 2}, y::Array{Float32, 1}, baseline::Float32, pop::Population, options::Options)::Population
    need_recalculate = options.batching
    if need_recalculate
        @inbounds @simd for member=1:pop.n
            pop.members[member].score = scoreFunc(X, y, baseline, pop.members[member].tree, options)
        end
    end
    return pop
end

# Return best 10 examples
function bestSubPop(pop::Population; topn::Integer=10)::Population
    best_idx = sortperm([pop.members[member].score for member=1:pop.n])
    return Population(pop.members[best_idx[1:topn]])
end

