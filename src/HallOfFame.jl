using FromFile
@from "Core.jl" import CONST_TYPE, maxdegree, Node, Options, Dataset
@from "EquationUtils.jl" import stringTree
@from "PopMember.jl" import PopMember
@from "LossFunctions.jl" import EvalLoss
using Printf: @sprintf

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
            betterThanAllSmaller = all([
                (!(hallOfFame.exists[i])
                 || curMSE < EvalLoss(hallOfFame.members[i].tree, dataset, options)*1.001)
                for i=1:(size-1)
            ])
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

function string_dominating_pareto_curve(hallOfFame, baselineMSE,
                                        dataset, options,
                                        avgy)
    output = ""
    curMSE = baselineMSE
    lastMSE = curMSE
    lastComplexity = 0
    output *= "Hall of Fame:\n"
    output *= "-----------------------------------------\n"
    output *= @sprintf("%-10s  %-8s   %-8s  %-8s\n", "Complexity", "Loss", "Score", "Equation")

    #TODO - call pareto function!
    actualMaxsize = options.maxsize + maxdegree
    for size=1:actualMaxsize
        if hallOfFame.exists[size]
            member = hallOfFame.members[size]
            curMSE = EvalLoss(member.tree, dataset, options)
            betterThanAllSmaller = all([
                    (
                         !(hallOfFame.exists[i])
                         || curMSE < EvalLoss(hallOfFame.members[i].tree, dataset, options)*1.001
                    ) for i=1:(size-1)
               ])
            if betterThanAllSmaller
                delta_c = size - lastComplexity
                delta_l_mse = log(curMSE/lastMSE)
                score = convert(Float32, -delta_l_mse/delta_c)
                output *= @sprintf("%-10d  %-8.3e  %-8.3e  %-s\n" , size, curMSE, score, stringTree(member.tree, options, varMap=dataset.varMap))
                lastMSE = curMSE
                lastComplexity = size
            end
        end
    end
    output *= "\n"
    return output
end
