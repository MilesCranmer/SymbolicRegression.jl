
#TODO - eventually move some of these
# into the SR call itself, rather than
# passing huge options at once.

struct Options

    una_constraints
    bin_constraints
    binops
    unaops
    n
    parsimony::Float32
    alpha::Float32
    maxsize::Int
    maxdepth::Int
    fast_cycle::Bool
    migration::Bool
    hofMigration::Bool
    fractionReplacedHof::Float32
    shouldOptimizeConstants::Bool
    hofFile::String
    nprocs::Int
    npopulations::Int
    nrestarts::Int
    perturbationFactor::Float32
    annealing::Bool
    weighted::Bool
    batching::Bool
    batchSize::Int
    useVarMap::Bool
    mutationWeights::Array{Real}
    warmupMaxsize::Int
    limitPowComplexity::Bool
    useFrequency::Bool
    npop::Integer
    ncyclesperiteration::Integer
    fractionReplaced::Float32
    topn::Integer
    verbosity::Integer

end

function Options(;
    una_constraints=nothing,
    bin_constraints=nothing,
    binops=[div, plus, mult],
    unaops=[exp, cos],
    n=0,
    parsimony=0.000100f0,
    alpha=0.100000f0,
    maxsize=20,
    maxdepth=20,
    fast_cycle=false,
    migration=true,
    hofMigration=true,
    fractionReplacedHof=0.1f0,
    shouldOptimizeConstants=true,
    hofFile=nothing,
    nprocs=4,
    npopulations=4,
    nrestarts=3,
    perturbationFactor=1.000000f0,
    annealing=true,
    weighted=false,
    batching=false,
    batchSize=50,
    useVarMap=false,
    mutationWeights=[10.000000, 1.000000, 1.000000, 3.000000, 3.000000, 0.010000, 1.000000, 1.000000],
    warmupMaxsize=1,
    limitPowComplexity=false,
    useFrequency=true,
    npop=300,
    ncyclesperiteration=3000,
    fractionReplaced=0.1f0,
    topn=10,
    verbosity=0
   )

    if hofFile == nothing
        hofFile = "hall_of_fame.csv" #TODO - put in date/time string here
    end

    if una_constraints == nothing
        una_constraints = [-1 for i=1:length(unaops)]
    end
    if bin_constraints == nothing
        bin_constraints = [(-1, -1) for i=1:length(binops)]
    end

    Options(una_constraints, bin_constraints, binops, unaops, n, parsimony, alpha, maxsize, maxdepth, fast_cycle, migration, hofMigration, fractionReplacedHof, shouldOptimizeConstants, hofFile, nprocs, npopulations, nrestarts, perturbationFactor, annealing, weighted, batching, batchSize, useVarMap, mutationWeights, warmupMaxsize, limitPowComplexity, useFrequency, npop, ncyclesperiteration, fractionReplaced, topn, verbosity)
end

# @inline function BINOP!(x::Array{Float32, 1}, y::Array{Float32, 1}, i::Int, clen::Int)
    # if i === 1
        # @inbounds @simd for j=1:clen
            # x[j] = div(x[j], y[j])
        # end
    # elseif i === 2
        # @inbounds @simd for j=1:clen
            # x[j] = plus(x[j], y[j])
        # end
    # elseif i === 3
        # @inbounds @simd for j=1:clen
            # x[j] = mult(x[j], y[j])
        # end
    # end
# end

# @inline function UNAOP!(x::Array{Float32, 1}, i::Int, clen::Int)
    # if i === 1
        # @inbounds @simd for j=1:clen
            # x[j] = sin(x[j])
        # end
    # elseif i === 2
        # @inbounds @simd for j=1:clen
            # x[j] = cos(x[j])
        # end
    # end
# end


