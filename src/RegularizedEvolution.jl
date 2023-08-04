module RegularizedEvolutionModule

import Random: shuffle!
import DynamicExpressions: string_tree
import ..CoreModule: Options, Dataset, RecordType, DATA_TYPE, LOSS_TYPE
import ..PopMemberModule: PopMember
import ..PopulationModule: Population, best_of_sample
import ..AdaptiveParsimonyModule: RunningSearchStatistics
import ..MutateModule: next_generation, crossover_generation
import ..RecorderModule: @recorder
import ..UtilsModule: argmin_fast

# Pass through the population several times, replacing the oldest
# with the fittest of a small subsample
function reg_evol_cycle(
    dataset::Dataset{T,L},
    pop::Population{T,L},
    temperature,
    curmaxsize::Int,
    running_search_statistics::RunningSearchStatistics,
    options::Options,
    record::RecordType,
)::Tuple{Population{T,L},Float64} where {T<:DATA_TYPE,L<:LOSS_TYPE}
    # Batch over each subsample. Can give 15% improvement in speed; probably moreso for large pops.
    # but is ultimately a different algorithm than regularized evolution, and might not be
    # as good.
    if options.crossover_probability > 0.0
        @recorder error("You cannot have the recorder on when using crossover")
    end

    num_evals = 0.0
    n_evol_cycles = ceil(Int, pop.n / options.tournament_selection_n)

    for i in 1:n_evol_cycles
        if rand() > options.crossover_probability
            allstar = best_of_sample(pop, running_search_statistics, options)
            mutation_recorder = RecordType()
            baby, mutation_accepted, tmp_num_evals = next_generation(
                dataset,
                allstar,
                temperature,
                curmaxsize,
                running_search_statistics,
                options;
                tmp_recorder=mutation_recorder,
            )
            num_evals += tmp_num_evals

            if !mutation_accepted && options.skip_mutation_failures
                # Skip this mutation rather than replacing oldest member with unchanged member
                continue
            end

            oldest = argmin_fast([pop.members[member].birth for member in 1:(pop.n)])

            @recorder begin
                if !haskey(record, "mutations")
                    record["mutations"] = RecordType()
                end
                for member in [allstar, baby, pop.members[oldest]]
                    if !haskey(record["mutations"], "$(member.ref)")
                        record["mutations"]["$(member.ref)"] = RecordType(
                            "events" => Vector{RecordType}(),
                            "tree" => string_tree(member.tree, options),
                            "score" => member.score,
                            "loss" => member.loss,
                            "parent" => member.parent,
                        )
                    end
                end
                mutate_event = RecordType(
                    "type" => "mutate",
                    "time" => time(),
                    "child" => baby.ref,
                    "mutation" => mutation_recorder,
                )
                death_event = RecordType("type" => "death", "time" => time())

                # Put in random key rather than vector; otherwise there are collisions!
                push!(record["mutations"]["$(allstar.ref)"]["events"], mutate_event)
                push!(
                    record["mutations"]["$(pop.members[oldest].ref)"]["events"], death_event
                )
            end

            pop.members[oldest] = baby

        else # Crossover
            allstar1 = best_of_sample(pop, running_search_statistics, options)
            allstar2 = best_of_sample(pop, running_search_statistics, options)

            baby1, baby2, crossover_accepted, tmp_num_evals = crossover_generation(
                allstar1, allstar2, dataset, curmaxsize, options
            )
            num_evals += tmp_num_evals

            if !crossover_accepted && options.skip_mutation_failures
                continue
            end

            # Replace old members with new ones:
            oldest = argmin_fast([pop.members[member].birth for member in 1:(pop.n)])
            pop.members[oldest] = baby1
            oldest = argmin_fast([pop.members[member].birth for member in 1:(pop.n)])
            pop.members[oldest] = baby2
        end
    end

    return (pop, num_evals)
end

end
