module SingleIterationModule

import ..CoreModule: Options, Dataset, RecordType, stringTree
import ..EquationUtilsModule: countNodes
import ..UtilsModule: debug
import ..SimplifyEquationModule: simplifyTree, combineOperators
import ..PopMemberModule: copyPopMember
import ..PopulationModule: Population, finalizeScores, bestSubPop
import ..HallOfFameModule: HallOfFame
import ..RegularizedEvolutionModule: regEvolCycle
import ..ConstantOptimizationModule: optimizeConstants

# Cycle through regularized evolution many times,
# printing the fittest equation every 10% through
function SRCycle(
    dataset::Dataset{T},
    baseline::T,
    pop::Population,
    ncycles::Int,
    curmaxsize::Int,
    frequencyComplexity::AbstractVector{T};
    verbosity::Int=0,
    options::Options,
    record::RecordType,
)::Tuple{Population,HallOfFame} where {T<:Real}
    top = convert(T, 1)
    allT = LinRange(top, convert(T, 0), ncycles)
    best_examples_seen = HallOfFame(options)

    for temperature in 1:size(allT, 1)
        if options.annealing
            pop = regEvolCycle(
                dataset,
                baseline,
                pop,
                allT[temperature],
                curmaxsize,
                frequencyComplexity,
                options,
                record,
            )
        else
            pop = regEvolCycle(
                dataset,
                baseline,
                pop,
                top,
                curmaxsize,
                frequencyComplexity,
                options,
                record,
            )
        end
        for member in pop.members
            size = countNodes(member.tree)
            score = member.score
            if !best_examples_seen.exists[size] ||
                score < best_examples_seen.members[size].score
                best_examples_seen.exists[size] = true
                best_examples_seen.members[size] = copyPopMember(member)
            end
        end
    end

    return (pop, best_examples_seen)
end

function OptimizeAndSimplifyPopulation(
    dataset::Dataset{T},
    baseline::T,
    pop::Population,
    options::Options,
    curmaxsize::Int,
    record::RecordType,
)::Population where {T<:Real}
    @inbounds @simd for j in 1:(pop.n)
        pop.members[j].tree = simplifyTree(pop.members[j].tree, options)
        pop.members[j].tree = combineOperators(pop.members[j].tree, options)
        if rand() < options.optimize_probability && options.shouldOptimizeConstants
            pop.members[j] = optimizeConstants(dataset, baseline, pop.members[j], options)
        end
    end
    pop = finalizeScores(dataset, baseline, pop, options)
    return pop
end

end
