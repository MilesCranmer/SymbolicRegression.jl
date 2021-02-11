using FromFile
@from "Core.jl" import Options, Dataset
@from "Utils.jl" import debug
@from "EquationUtils.jl" import stringTree
@from "SimplifyEquation.jl" import simplifyTree, combineOperators, simplifyWithSymbolicUtils
@from "Population.jl" import Population, finalizeScores, bestSubPop
@from "RegularizedEvolution.jl" import regEvolCycle
@from "ConstantOptimization.jl" import optimizeConstants


# Cycle through regularized evolution many times,
# printing the fittest equation every 10% through
function SRCycle(dataset::Dataset{T}, baseline::T, 
        pop::Population,
        ncycles::Int,
        curmaxsize::Int,
        frequencyComplexity::AbstractVector{T};
        verbosity::Int=0,
        options::Options
        )::Population where {T<:Real}

    top = convert(T, 1)
    allT = LinRange(top, convert(T, 0), ncycles)
    for temperature in 1:size(allT, 1)
        if options.annealing
            pop = regEvolCycle(dataset, baseline, pop, allT[temperature], curmaxsize, frequencyComplexity, options)
        else
            pop = regEvolCycle(dataset, baseline, pop, top, curmaxsize, frequencyComplexity, options)
        end

        if verbosity > 0 && (temperature % verbosity == 0)
            bestPops = bestSubPop(pop)
            bestCurScoreIdx = argmin([bestPops.members[member].score for member=1:bestPops.n])
            bestCurScore = bestPops.members[bestCurScoreIdx].score
            debug(verbosity, bestCurScore, " is the score for ", stringTree(bestPops.members[bestCurScoreIdx].tree, options, varMap=dataset.varMap))
        end
    end

    return pop
end

function OptimizeAndSimplifyPopulation(
            dataset::Dataset{T}, baseline::T,
            pop::Population, options::Options
        )::Population where {T<:Real}
    @inbounds @simd for j=1:pop.n
        pop.members[j].tree = simplifyTree(pop.members[j].tree, options)
        pop.members[j].tree = combineOperators(pop.members[j].tree, options)
        pop.members[j].tree = simplifyWithSymbolicUtils(pop.members[j].tree, options)
        if rand() < 0.1 && options.shouldOptimizeConstants
            pop.members[j] = optimizeConstants(dataset, baseline, pop.members[j], options)
        end
    end
    pop = finalizeScores(dataset, baseline, pop, options)
    return pop
end
