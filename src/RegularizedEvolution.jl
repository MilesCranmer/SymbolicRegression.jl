module RegularizedEvolutionModule

using BorrowChecker: OrBorrowed, @take
using DynamicExpressions: string_tree
using ..CoreModule: AbstractOptions, Dataset, RecordType, DATA_TYPE, LOSS_TYPE
using ..PopulationModule: Population, best_of_sample
using ..AdaptiveParsimonyModule: RunningSearchStatistics
using ..MutateModule: next_generation, crossover_generation
using ..RecorderModule: @recorder
using ..UtilsModule: argmin_fast

# Pass through the population several times, replacing the oldest
# with the fittest of a small subsample
function reg_evol_cycle(
    dataset::OrBorrowed{Dataset{T,L}},
    pop::P,
    temperature,
    curmaxsize::Int,
    running_search_statistics::RunningSearchStatistics,
    options::OrBorrowed{AbstractOptions},
    record::RecordType,
)::Tuple{P,Float64} where {T<:DATA_TYPE,L<:LOSS_TYPE,P<:Population{T,L}}
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

            if !mutation_accepted && @take(options.skip_mutation_failures)
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
                            "cost" => member.cost,
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

            crossover_recorder = RecordType()
            baby1, baby2, crossover_accepted, tmp_num_evals = crossover_generation(
                allstar1,
                allstar2,
                dataset,
                curmaxsize,
                options;
                recorder=crossover_recorder,
            )
            num_evals += tmp_num_evals

            if !crossover_accepted && @take(options.skip_mutation_failures)
                continue
            end

            # Find the oldest members to replace:
            oldest1 = argmin_fast([pop.members[member].birth for member in 1:(pop.n)])
            BT = typeof(first(pop.members).birth)
            oldest2 = argmin_fast([
                i == oldest1 ? typemax(BT) : pop.members[i].birth for i in 1:(pop.n)
            ])

            @recorder begin
                if !haskey(record, "mutations")
                    record["mutations"] = RecordType()
                end
                for member in [
                    allstar1,
                    allstar2,
                    baby1,
                    baby2,
                    pop.members[oldest1],
                    pop.members[oldest2],
                ]
                    if !haskey(record["mutations"], "$(member.ref)")
                        record["mutations"]["$(member.ref)"] = RecordType(
                            "events" => Vector{RecordType}(),
                            "tree" => string_tree(member.tree, options),
                            "cost" => member.cost,
                            "loss" => member.loss,
                            "parent" => member.parent,
                        )
                    end
                end
                crossover_event = RecordType(
                    "type" => "crossover",
                    "time" => time(),
                    "parent1" => allstar1.ref,
                    "parent2" => allstar2.ref,
                    "child1" => baby1.ref,
                    "child2" => baby2.ref,
                    "details" => crossover_recorder,
                )
                death_event1 = RecordType("type" => "death", "time" => time())
                death_event2 = RecordType("type" => "death", "time" => time())

                push!(record["mutations"]["$(allstar1.ref)"]["events"], crossover_event)
                push!(record["mutations"]["$(allstar2.ref)"]["events"], crossover_event)
                push!(
                    record["mutations"]["$(pop.members[oldest1].ref)"]["events"],
                    death_event1,
                )
                push!(
                    record["mutations"]["$(pop.members[oldest2].ref)"]["events"],
                    death_event2,
                )
            end

            # Replace old members with new ones:
            pop.members[oldest1] = baby1
            pop.members[oldest2] = baby2
        end
    end

    return (pop, num_evals)
end

end
