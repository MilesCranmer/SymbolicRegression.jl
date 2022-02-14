using FromFile
using Random: shuffle!
@from "Core.jl" import Options, Dataset, RecordType, stringTree
@from "LossFunctions.jl" import scoreFunc, scoreFuncBatch
@from "PopMember.jl" import PopMember
@from "Population.jl" import Population, bestOfSample
@from "CheckConstraints.jl" import check_constraints
@from "Mutate.jl" import nextGeneration
@from "MutationFunctions.jl" import crossoverTrees
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
    if options.crossoverProbability > 0.0
        @recorder error("You cannot have the recorder on when using crossover")
    end

    if options.fast_cycle

        # These options are not implemented for fast_cycle:
        @recorder error("You cannot have the recorder and fast_cycle set to true at the same time!")
        @assert options.probPickFirst == 1.0
        @assert options.crossoverProbability == 0.0

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
            if rand() > options.crossoverProbability
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
                
            else # Crossover
                allstar1 = bestOfSample(pop, options)
                allstar2 = bestOfSample(pop, options)
                tree1 = allstar1.tree
                tree2 = allstar2.tree

                # We breed these until constraints are no longer violated:
                child_tree1, child_tree2 = crossoverTrees(tree1, tree2)
                num_tries = 1
                max_tries = 10
                while true 
                    # Both trees satisfy constraints
                    if check_constraints(child_tree1, options, curmaxsize) && check_constraints(child_tree2, options, curmaxsize)
                        break
                    end
                    if num_tries > max_tries
                        return pop  # Fail.
                    end
                    child_tree1, child_tree2 = crossoverTrees(tree1, tree2)
                    num_tries += 1
                end
                if options.batching
                    afterLoss1 = scoreFuncBatch(dataset, baseline, child_tree1, options)
                    afterLoss2 = scoreFuncBatch(dataset, baseline, child_tree2, options)
                else
                    afterLoss1 = scoreFunc(dataset, baseline, child_tree1, options)
                    afterLoss2 = scoreFunc(dataset, baseline, child_tree2, options)
                end

                baby1 = PopMember(child_tree1, afterLoss1, parent=allstar1.ref)
                baby2 = PopMember(child_tree2, afterLoss2, parent=allstar2.ref)

                # Replace old members with new ones:
                oldest = argmin([pop.members[member].birth for member=1:pop.n])
                pop.members[oldest] = baby1
                oldest = argmin([pop.members[member].birth for member=1:pop.n])
                pop.members[oldest] = baby2
            end
        end
    end

    return pop
end
