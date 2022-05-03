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
    max_temp = T(1.0)
    min_temp = T(0.0)
    all_temperatures = LinRange(max_temp, min_temp, ncycles)
    best_examples_seen = HallOfFame(options)

    for temperature in all_temperatures
        pop = reg_evol_cycle(
            dataset,
            baseline,
            pop,
            options.annealing ? temperature : max_temp,
            curmaxsize,
            frequencyComplexity,
            options,
            record,
        )
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
