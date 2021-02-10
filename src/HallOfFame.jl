using FromFile
@from "Core.jl" import CONST_TYPE, maxdegree, Node, Options, Dataset
@from "PopMember.jl" import PopMember
@from "LossFunctions.jl" import EvalLoss

""" List of the best members seen all time in `.members` """
mutable struct HallOfFame
    members::Array{PopMember, 1}
    exists::Array{Bool, 1} #Whether it has been set

    # Arranged by complexity - store one at each.
end

"""
    HallOfFame(options::Options)

Create empty HallOfFame. The HallOfFame stores a list
of `PopMember` objects in `.members`, which is enumerated
by size (i.e., `.members[1]` is the constant solution).
`.exists` is used to determine whether the particular member
has been instantiated or not.
"""
function HallOfFame(options::Options)
    actualMaxsize = options.maxsize + maxdegree
    HallOfFame([PopMember(Node(convert(CONST_TYPE, 1)), 1f9) for i=1:actualMaxsize], [false for i=1:actualMaxsize])
end


"""
    calculateParetoFrontier(dataset::Dataset{T}, hallOfFame::HallOfFame,
                            options::Options) where {T<:Real}
"""
function calculateParetoFrontier(dataset::Dataset{T},
                                 hallOfFame::HallOfFame,
                                 options::Options)::Array{PopMember, 1} where {T<:Real}
    # Dominating pareto curve - must be better than all simpler equations
    dominating = PopMember[]
    actualMaxsize = options.maxsize + maxdegree
    for size=1:actualMaxsize
        if hallOfFame.exists[size]
            member = hallOfFame.members[size]
            curMSE = EvalLoss(member.tree, dataset, options)
            member.score = curMSE
            numberSmallerAndBetter = 0
            for i=1:(size-1)
                hofMSE = EvalLoss(hallOfFame.members[i].tree, dataset, options)
                if (hallOfFame.exists[size] && curMSE > hofMSE)
                    numberSmallerAndBetter += 1
                    break
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

"""
    calculateParetoFrontier(X::AbstractMatrix{T}, y::AbstractVector{T},
                            hallOfFame::HallOfFame, options::Options;
                            weights=nothing, varMap=nothing) where {T<:Real}

Compute the dominating Pareto frontier for a given hallOfFame. This
is the list of equations where each equation has a better loss than all
simpler equations.
"""
function calculateParetoFrontier(X::AbstractMatrix{T},
                                 y::AbstractVector{T},
                                 hallOfFame::HallOfFame,
                                 options::Options;
                                 weights=nothing,
                                 varMap=nothing) where {T<:Real}
    calculateParetoFrontier(Dataset(X, y, weights=weights, varMap=varMap), hallOfFame, options)
end

