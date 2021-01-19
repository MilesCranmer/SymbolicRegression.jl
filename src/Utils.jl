using Printf: @printf

function id(x::Float32)::Float32
    x
end

function debug(verbosity, string...)
    verbosity > 0 ? println(string...) : nothing
end

function getTime()::Integer
    return round(Integer, 1e3*(time()-1.6e9))
end


# Check for errors before they happen
function testConfiguration(options::Options)
    test_input = LinRange(-100f0, 100f0, 99)

    try
        for left in test_input
            for right in test_input
                for binop in options.binops
                    test_output = binop.(left, right)
                end
            end
            for unaop in options.unaops
                test_output = unaop.(left)
            end
        end
    catch error
        @printf("\n\nYour configuration is invalid - one of your operators is not well-defined over the real line.\n\n\n")
        throw(error)
    end
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

