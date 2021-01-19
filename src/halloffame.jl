# List of the best members seen all time
mutable struct HallOfFame
    members::Array{PopMember, 1}
    exists::Array{Bool, 1} #Whether it has been set

    # Arranged by complexity - store one at each.
end

function HallOfFame(options::Options)
    actualMaxsize = options.maxsize + maxdegree
    HallOfFame([PopMember(Node(1f0), 1f9) for i=1:actualMaxsize], [false for i=1:actualMaxsize])
end

function calculateParetoFrontier(X::Array{Float32, 2}, y::Array{Float32, 1},
                                 hallOfFame::HallOfFame, options::Options)
    # Dominating pareto curve - must be better than all simpler equations
    dominating = PopMember[]
    actualMaxsize = options.maxsize + maxdegree
    for size=1:actualMaxsize
        if hallOfFame.exists[size]
            member = hallOfFame.members[size]
            if options.weighted
                curMSE = MSE(evalTreeArray(member.tree, X, options), y, weights)
                member.score = curMSE
            else
                curMSE = MSE(evalTreeArray(member.tree, X, options), y)
                member.score = curMSE
            end
            numberSmallerAndBetter = 0
            for i=1:(size-1)
                if options.weighted
                    hofMSE = MSE(evalTreeArray(hallOfFame.members[i].tree, X, options), y, weights)
                else
                    hofMSE = MSE(evalTreeArray(hallOfFame.members[i].tree, X, options), y)
                end
                if (hallOfFame.exists[size] && curMSE > hofMSE)
                    numberSmallerAndBetter += 1
                end
            end
            betterThanAllSmaller = (numberSmallerAndBetter == 0)
            if betterThanAllSmaller
                push!(dominating, member)
            end
        end
    end
    return dominating
end

