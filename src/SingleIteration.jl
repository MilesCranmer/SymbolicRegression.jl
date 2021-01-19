# Cycle through regularized evolution many times,
# printing the fittest equation every 10% through
function SRCycle(X::Array{Float32, 2}, y::Array{Float32, 1}, baseline::Float32, 
        pop::Population,
        ncycles::Integer,
        curmaxsize::Integer,
        frequencyComplexity::Array{Float32, 1};
        verbosity::Integer=0,
        options::Options
       )::Population

    allT = LinRange(1.0f0, 0.0f0, ncycles)
    for iT in 1:size(allT)[1]
        if options.annealing
            pop = regEvolCycle(X, y, baseline, pop, allT[iT], curmaxsize, frequencyComplexity, options)
        else
            pop = regEvolCycle(X, y, baseline, pop, 1.0f0, curmaxsize, frequencyComplexity, options)
        end

        if verbosity > 0 && (iT % verbosity == 0)
            bestPops = bestSubPop(pop)
            bestCurScoreIdx = argmin([bestPops.members[member].score for member=1:bestPops.n])
            bestCurScore = bestPops.members[bestCurScoreIdx].score
            debug(verbosity, bestCurScore, " is the score for ", stringTree(bestPops.members[bestCurScoreIdx].tree, options))
        end
    end

    return pop
end
