using FromFile
using Random: shuffle!
@from "Core.jl" import Options, Dataset, RecordType
@from "EquationUtils.jl" import stringTree
@from "PopMember.jl" import PopMember
@from "Population.jl" import Population, bestOfSample
@from "Mutate.jl" import nextGeneration
@from "Recorder.jl" import @recorder

# Pass through the population several times, replacing the oldest
# with the fittest of a small subsample
function regEvolCycle(dataset::Dataset{T},
                      baseline::T, pop::Population, temperature::T, curmaxsize::Int,
                      frequencyComplexity::AbstractVector{T},
                      options::Options,
                      record::RecordType)::Population where {T<:Real}
    # Batch over each subsample. Can give 15% improvement in speed; probably moreso for large pops.
    # but is ultimately a different algorithm than regularized evolution, and might not be
    # as good.
    if options.fast_cycle

        # These options are not implemented for fast_cycle:
        @recorder error("You cannot have the recorder and fast_cycle set to true at the same time!")
        @assert options.probPickFirst == 1.0

        shuffle!(pop.members)
        n_evol_cycles = round(Int, pop.n/options.ns)
        babies = Array{PopMember}(undef, n_evol_cycles)

        # Iterate each ns-member sub-sample
        @inbounds Threads.@threads for i=1:n_evol_cycles
            best_score = Inf
            best_idx = 1+(i-1)*options.ns
            # Calculate best member of the subsample:
            for sub_i=1+(i-1)*options.ns:i*options.ns
                if pop.members[sub_i].score < best_score
                    best_score = pop.members[sub_i].score
                    best_idx = sub_i
                end
            end
            allstar = pop.members[best_idx]
            mutation_recorder = RecordType()
            babies[i] = nextGeneration(dataset, baseline, allstar, temperature,
                                       curmaxsize, frequencyComplexity, options,
                                       tmp_recorder=mutation_recorder)
        end

        # Replace the n_evol_cycles-oldest members of each population
        @inbounds for i=1:n_evol_cycles
            oldest = argmin([pop.members[member].birth for member=1:pop.n])
            pop.members[oldest] = babies[i]
        end
    else
        for i=1:round(Int, pop.n/options.ns)
            allstar = bestOfSample(pop, options)
            mutation_recorder = RecordType()
            baby = nextGeneration(dataset, baseline, allstar, temperature,
                                  curmaxsize, frequencyComplexity, options,
                                  tmp_recorder=mutation_recorder)

            oldest = argmin([pop.members[member].birth for member=1:pop.n])

            @recorder begin
                if !haskey(record, "mutations")
                    record["mutations"] = RecordType()
                end
                for member in [allstar, baby, pop.members[oldest]]
                    if !haskey(record["mutations"], "$(member.ref)")
                        record["mutations"]["$(member.ref)"] = RecordType("events"=>Vector{RecordType}(),
                                                                          "tree"=>stringTree(member.tree, options),
                                                                          "score"=>member.score,
                                                                          "parent"=>member.parent)
                    end
                end
                mutate_event = RecordType("type"=>"mutate", "time"=>time(), "child"=>baby.ref, "mutation"=>mutation_recorder)
                death_event  = RecordType("type"=>"death",  "time"=>time())

                # Put in random key rather than vector; otherwise there are collisions!
                push!(record["mutations"]["$(allstar.ref)"]["events"], mutate_event)
                push!(record["mutations"]["$(pop.members[oldest].ref)"]["events"], death_event)
            end

            pop.members[oldest] = baby
        end
    end

    return pop
end
