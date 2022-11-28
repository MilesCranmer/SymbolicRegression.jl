module SingleIterationModule

import DynamicExpressions: string_tree, simplify_tree, combine_operators
import ..CoreModule: Options, Dataset, RecordType
import ..ComplexityModule: compute_complexity
import ..UtilsModule: debug
import ..PopMemberModule: copy_pop_member, generate_reference
import ..PopulationModule: Population, finalize_scores, best_sub_pop
import ..HallOfFameModule: HallOfFame
import ..AdaptiveParsimonyModule: RunningSearchStatistics
import ..RegularizedEvolutionModule: reg_evol_cycle
import ..ConstantOptimizationModule: optimize_constants
import ..RecorderModule: @recorder

# Cycle through regularized evolution many times,
# printing the fittest equation every 10% through
function s_r_cycle(
    dataset::Dataset{T},
    pop::Population,
    ncycles::Int,
    curmaxsize::Int,
    running_search_statistics::RunningSearchStatistics;
    verbosity::Int=0,
    options::Options,
    record::RecordType,
)::Tuple{Population{T},HallOfFame{T},Float64} where {T<:Real}
    max_temp = T(1.0)
    min_temp = T(0.0)
    if !options.annealing
        min_temp = max_temp
    end
    all_temperatures = LinRange(max_temp, min_temp, ncycles)
    best_examples_seen = HallOfFame(options, T)
    num_evals = 0.0

    for temperature in all_temperatures
        pop, tmp_num_evals = reg_evol_cycle(
            dataset,
            pop,
            temperature,
            curmaxsize,
            running_search_statistics,
            options,
            record,
        )
        num_evals += tmp_num_evals
        for member in pop.members
            size = compute_complexity(member.tree, options)
            score = member.score
            if 0 < size <= options.maxsize && (
                !best_examples_seen.exists[size] ||
                score < best_examples_seen.members[size].score
            )
                best_examples_seen.exists[size] = true
                best_examples_seen.members[size] = copy_pop_member(member)
            end
        end
    end

    return (pop, best_examples_seen, num_evals)
end

function optimize_and_simplify_population(
    dataset::Dataset{T},
    pop::Population,
    options::Options,
    curmaxsize::Int,
    record::RecordType,
)::Tuple{Population,Float64} where {T<:Real}
    array_num_evals = zeros(Float64, pop.n)
    do_optimization = rand(pop.n) .< options.optimizer_probability
    for j in 1:(pop.n)
        pop.members[j].tree = simplify_tree(pop.members[j].tree, options.operators)
        pop.members[j].tree = combine_operators(pop.members[j].tree, options.operators)
        if options.should_optimize_constants && do_optimization[j]
            pop.members[j], array_num_evals[j] = optimize_constants(
                dataset, pop.members[j], options
            )
        end
    end
    num_evals = sum(array_num_evals)
    pop, tmp_num_evals = finalize_scores(dataset, pop, options)
    num_evals += tmp_num_evals

    # Now, we create new references for every member,
    # and optionally record which operations occurred.
    for j in 1:(pop.n)
        old_ref = pop.members[j].ref
        new_ref = generate_reference()
        pop.members[j].parent = old_ref
        pop.members[j].ref = new_ref

        @recorder begin
            # Same structure as in RegularizedEvolution.jl,
            # except we assume that the record already exists.
            @assert haskey(record, "mutations")
            member = pop.members[j]
            if !haskey(record["mutations"], "$(member.ref)")
                record["mutations"]["$(member.ref)"] = RecordType(
                    "events" => Vector{RecordType}(),
                    "tree" => string_tree(member.tree, options.operators),
                    "score" => member.score,
                    "loss" => member.loss,
                    "parent" => member.parent,
                )
            end
            optimize_and_simplify_event = RecordType(
                "type" => "tuning",
                "time" => time(),
                "child" => new_ref,
                "mutation" => RecordType(
                    "type" =>
                        if (do_optimization[j] && options.should_optimize_constants)
                            "simplification_and_optimization"
                        else
                            "simplification"
                        end,
                ),
            )
            death_event = RecordType("type" => "death", "time" => time())

            push!(record["mutations"]["$(old_ref)"]["events"], optimize_and_simplify_event)
            push!(record["mutations"]["$(old_ref)"]["events"], death_event)
        end
    end
    return (pop, num_evals)
end

end
