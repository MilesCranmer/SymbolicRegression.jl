module SingleIterationModule

import ..CoreModule: Options, Dataset, RecordType, string_tree
import ..EquationUtilsModule: compute_complexity
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
)::Tuple{Population,HallOfFame,Float64} where {T<:Real}
    max_temp = T(1.0)
    min_temp = T(0.0)
    if !options.annealing
        min_temp = max_temp
    end
    all_temperatures = LinRange(max_temp, min_temp, ncycles)
    best_examples_seen = HallOfFame(options)
    num_evals = 0.0

    for temperature in all_temperatures
        pop, tmp_num_evals = reg_evol_cycle(
            dataset,
            baseline,
            pop,
            temperature,
            curmaxsize,
            frequencyComplexity,
            options,
            record,
        )
        num_evals += tmp_num_evals
        for member in pop.members
            size = compute_complexity(member.tree, options)
            score = member.score
            if !best_examples_seen.exists[size] ||
                score < best_examples_seen.members[size].score
                best_examples_seen.exists[size] = true
                best_examples_seen.members[size] = copy_pop_member(member)
            end
        end
    end

    return (pop, best_examples_seen, num_evals)
end

function optimize_and_simplify_population(
    dataset::Dataset{T},
    baseline::T,
    pop::Population,
    options::Options,
    curmaxsize::Int,
    record::RecordType,
)::Tuple{Population,Float64} where {T<:Real}
    array_num_evals = zeros(Float64, pop.n)
    @inbounds @simd for j in 1:(pop.n)
        pop.members[j].tree = simplify_tree(pop.members[j].tree, options)
        pop.members[j].tree = combine_operators(pop.members[j].tree, options)
        if rand() < options.optimize_probability && options.shouldOptimizeConstants
            pop.members[j], array_num_evals[j] = optimize_constants(
                dataset, baseline, pop.members[j], options
            )
        end
    end
    num_evals = sum(array_num_evals)
    pop, tmp_num_evals = finalize_scores(dataset, baseline, pop, options)
    num_evals += tmp_num_evals
    return (pop, num_evals)
end

end
