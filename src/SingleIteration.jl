# Cycle through regularized evolution many times,
# printing the fittest equation every 10% through
function SRCycle(X::AbstractMatrix{T}, y::AbstractVector{T}, baseline::T, 
        pop::Population,
        ncycles::Integer,
        curmaxsize::Integer,
        frequencyComplexity::AbstractVector{T};
        verbosity::Integer=0,
        options::Options
        )::Population where {T<:Real}

    top = convert(T, 1.0)
    allT = LinRange(top, convert(T, 0.0), ncycles)
    for temperature in 1:size(allT)[1]
        if options.annealing
            pop = regEvolCycle(X, y, baseline, pop, allT[temperature], curmaxsize, frequencyComplexity, options)
        else
            pop = regEvolCycle(X, y, baseline, pop, top, curmaxsize, frequencyComplexity, options)
        end

        if verbosity > 0 && (temperature % verbosity == 0)
            bestPops = bestSubPop(pop)
            bestCurScoreIdx = argmin([bestPops.members[member].score for member=1:bestPops.n])
            bestCurScore = bestPops.members[bestCurScoreIdx].score
            debug(verbosity, bestCurScore, " is the score for ", stringTree(bestPops.members[bestCurScoreIdx].tree, options))
        end
    end

    return pop
end
