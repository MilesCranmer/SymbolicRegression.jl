module SingleIterationModule

import ..CoreModule: Options, Dataset, RecordType, string_tree
import ..EquationUtilsModule: count_nodes
import ..UtilsModule: debug
import ..SimplifyEquationModule: simplify_tree, combine_operators
import ..PopMemberModule: copy_pop_member
import ..PopulationModule: Population, finalize_scores, best_sub_pop
import ..HallOfFameModule: HallOfFame
import ..RegularizedEvolutionModule: reg_evol_cycle
import ..ConstantOptimizationModule: optimize_constants

# Cycle through regularized evolution many times,
# printing the fittest equation every 10% through
function s_r_cycle(
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
            pop = reg_evol_cycle(
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
            pop = reg_evol_cycle(
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
            size = count_nodes(member.tree)
            score = member.score
            if !best_examples_seen.exists[size] ||
                score < best_examples_seen.members[size].score
                best_examples_seen.exists[size] = true
                best_examples_seen.members[size] = copy_pop_member(member)
            end
        end
    end

    return (pop, best_examples_seen)
end

function optimize_and_simplify_population(
    dataset::Dataset{T},
    baseline::T,
    pop::Population,
    options::Options,
    curmaxsize::Int,
    record::RecordType,
)::Population where {T<:Real}
    @inbounds @simd for j in 1:(pop.n)
        pop.members[j].tree = simplify_tree(pop.members[j].tree, options)
        pop.members[j].tree = combine_operators(pop.members[j].tree, options)
        if rand() < options.optimize_probability && options.shouldOptimizeConstants
            pop.members[j] = optimize_constants(dataset, baseline, pop.members[j], options)
        end
    end
    pop = finalize_scores(dataset, baseline, pop, options)
    return pop
end

end
