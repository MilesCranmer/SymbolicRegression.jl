using Random: shuffle!

# Pass through the population several times, replacing the oldest
# with the fittest of a small subsample
function regEvolCycle(X::AbstractMatrix{T}, y::AbstractVector{T},
                      baseline::T, pop::Population, temperature::T, curmaxsize::Integer,
                      frequencyComplexity::AbstractVector{T},
                      options::Options)::Population where {T<:Real}
    # Batch over each subsample. Can give 15% improvement in speed; probably moreso for large pops.
    # but is ultimately a different algorithm than regularized evolution, and might not be
    # as good.
    if options.fast_cycle
        shuffle!(pop.members)
        n_evol_cycles = round(Integer, pop.n/options.ns)
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
            babies[i] = iterate(X, y, baseline, allstar, temperature,
                                curmaxsize, frequencyComplexity, options)
        end

        # Replace the n_evol_cycles-oldest members of each population
        @inbounds for i=1:n_evol_cycles
            oldest = argmin([pop.members[member].birth for member=1:pop.n])
            pop.members[oldest] = babies[i]
        end
    else
        for i=1:round(Integer, pop.n/options.ns)
            allstar = bestOfSample(pop, options)
            baby = iterate(X, y, baseline, allstar, temperature,
                           curmaxsize, frequencyComplexity, options)
            #printTree(baby.tree)
            oldest = argmin([pop.members[member].birth for member=1:pop.n])
            pop.members[oldest] = baby
        end
    end

    return pop
end
