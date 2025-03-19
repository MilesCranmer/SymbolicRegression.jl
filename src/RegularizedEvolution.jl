module RegularizedEvolutionModule

using DynamicExpressions: string_tree
using ..CoreModule: AbstractOptions, Dataset, RecordType, DATA_TYPE, LOSS_TYPE
using ..PopulationModule: Population, best_of_sample
using ..AdaptiveParsimonyModule: RunningSearchStatistics
using ..MutateModule: next_generation, crossover_generation
using ..RecorderModule: @recorder
using ..UtilsModule: argmin_fast

function setup_member_recording!(record::RecordType, members, options::AbstractOptions)
    if !haskey(record, "mutations")
        record["mutations"] = RecordType()
    end

    for member in members
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
end

"""
    handle_mutation!(pop, dataset, running_search_statistics, options, record, temperature, curmaxsize)

Perform mutation on a selected member and replace the oldest population member with the result.
Returns the number of evaluations performed.
"""
function handle_mutation!(
    pop::P,
    dataset::Dataset{T,L},
    running_search_statistics::RunningSearchStatistics,
    options::AbstractOptions,
    record::RecordType,
    temperature,
    curmaxsize::Int,
) where {T<:DATA_TYPE,L<:LOSS_TYPE,P<:Population{T,L}}
    # Select best member from tournament
    allstar = best_of_sample(pop, running_search_statistics, options)

    # Perform mutation
    mutation_recorder = RecordType()
    baby, mutation_accepted, num_evals = next_generation(
        dataset,
        allstar,
        temperature,
        curmaxsize,
        running_search_statistics,
        options;
        tmp_recorder=mutation_recorder,
    )

    # Skip if mutation failed and we're configured to skip failures
    if !mutation_accepted && options.skip_mutation_failures
        return num_evals
    end

    # Find oldest member to replace
    oldest = argmin_fast([pop.members[member].birth for member in 1:(pop.n)])

    # Record mutation events
    @recorder begin
        members_to_record = [allstar, baby, pop.members[oldest]]
        setup_member_recording!(record, members_to_record, options)

        mutate_event = RecordType(
            "type" => "mutate",
            "time" => time(),
            "child" => baby.ref,
            "mutation" => mutation_recorder,
        )
        death_event = RecordType("type" => "death", "time" => time())

        push!(record["mutations"]["$(allstar.ref)"]["events"], mutate_event)
        push!(record["mutations"]["$(pop.members[oldest].ref)"]["events"], death_event)
    end

    # Replace the oldest member with the new baby
    pop.members[oldest] = baby

    return num_evals
end

"""
    handle_crossover!(pop, dataset, running_search_statistics, options, record, curmaxsize)

Perform crossover between two selected members and replace the two oldest population members with the results.
Returns the number of evaluations performed.
"""
function handle_crossover!(
    pop::P,
    dataset::Dataset{T,L},
    running_search_statistics::RunningSearchStatistics,
    options::AbstractOptions,
    record::RecordType,
    curmaxsize::Int,
) where {T<:DATA_TYPE,L<:LOSS_TYPE,P<:Population{T,L}}
    # Select the two parents
    allstar1 = best_of_sample(pop, running_search_statistics, options)
    allstar2 = best_of_sample(pop, running_search_statistics, options)

    # Perform crossover
    crossover_recorder = RecordType()
    baby1, baby2, crossover_accepted, num_evals = crossover_generation(
        allstar1, allstar2, dataset, curmaxsize, options; recorder=crossover_recorder
    )

    # Skip if crossover failed and we're configured to skip failures
    if !crossover_accepted && options.skip_mutation_failures
        return num_evals
    end

    # Find the two oldest members to replace
    oldest1 = argmin_fast([pop.members[member].birth for member in 1:(pop.n)])
    BT = typeof(first(pop.members).birth)
    oldest2 = argmin_fast([
        i == oldest1 ? typemax(BT) : pop.members[i].birth for i in 1:(pop.n)
    ])

    # Record crossover events
    @recorder begin
        members_to_record = [
            allstar1, allstar2, baby1, baby2, pop.members[oldest1], pop.members[oldest2]
        ]
        setup_member_recording!(record, members_to_record, options)

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
        push!(record["mutations"]["$(pop.members[oldest1].ref)"]["events"], death_event1)
        push!(record["mutations"]["$(pop.members[oldest2].ref)"]["events"], death_event2)
    end

    # Replace old members with new ones
    pop.members[oldest1] = baby1
    pop.members[oldest2] = baby2

    return num_evals
end

"""
    reg_evol_cycle(dataset, pop, temperature, curmaxsize, running_search_statistics, options, record)

Pass through the population several times, replacing the oldest with the fittest
members from a small subsample based on tournament selection.

This implements the regularized evolution algorithm, alternating between mutation and
crossover operations based on the crossover probability.
"""
function reg_evol_cycle(
    dataset::Dataset{T,L},
    pop::P,
    temperature,
    curmaxsize::Int,
    running_search_statistics::RunningSearchStatistics,
    options::AbstractOptions,
    record::RecordType,
)::Tuple{P,Float64} where {T<:DATA_TYPE,L<:LOSS_TYPE,P<:Population{T,L}}
    num_evals = 0.0

    # Calculate number of evolution cycles based on population size and tournament size
    n_evol_cycles = ceil(Int, pop.n / options.tournament_selection_n)

    # Perform multiple cycles of selection and replacement
    for _ in 1:n_evol_cycles
        if rand() > options.crossover_probability
            # Mutation case
            num_evals += handle_mutation!(
                pop,
                dataset,
                running_search_statistics,
                options,
                record,
                temperature,
                curmaxsize,
            )
        else
            # Crossover case
            num_evals += handle_crossover!(
                pop, dataset, running_search_statistics, options, record, curmaxsize
            )
        end
    end

    return (pop, num_evals)
end

end
