module HallOfFameModule

import DynamicExpressions: Node, string_tree
import ..CoreModule: MAX_DEGREE, Options, Dataset
import ..ComplexityModule: compute_complexity
import ..PopMemberModule: PopMember, copy_pop_member
import ..LossFunctionsModule: eval_loss
using Printf: @sprintf

""" List of the best members seen all time in `.members` """
mutable struct HallOfFame{T<:Real}
    members::Array{PopMember{T},1}
    exists::Array{Bool,1} #Whether it has been set

    # Arranged by complexity - store one at each.
end

"""
    HallOfFame(options::Options, ::Type{T}) where {T<:Real}

Create empty HallOfFame. The HallOfFame stores a list
of `PopMember` objects in `.members`, which is enumerated
by size (i.e., `.members[1]` is the constant solution).
`.exists` is used to determine whether the particular member
has been instantiated or not.

Arguments:
- `options`: Options containing specification about deterministic.
- `T`: Type of Nodes to use in the population. e.g., `Float64`.
"""
function HallOfFame(options::Options, ::Type{T}) where {T<:Real}
    actualMaxsize = options.maxsize + MAX_DEGREE
    return HallOfFame(
        [
            PopMember(
                Node(; val=convert(T, 1)),
                T(0),
                T(Inf);
                parent=-1,
                deterministic=options.deterministic,
            ) for i in 1:actualMaxsize
        ],
        [false for i in 1:actualMaxsize],
    )
end

function copy_hall_of_fame(hof::HallOfFame{T})::HallOfFame{T} where {T<:Real}
    return HallOfFame(
        [copy_pop_member(member) for member in hof.members],
        [exists for exists in hof.exists],
    )
end

"""
    calculate_pareto_frontier(dataset::Dataset{T}, hallOfFame::HallOfFame{T},
                            options::Options) where {T<:Real}
"""
function calculate_pareto_frontier(
    dataset::Dataset{T}, hallOfFame::HallOfFame{T}, options::Options
)::Vector{PopMember{T}} where {T<:Real}
    # TODO - remove dataset from args.
    # Dominating pareto curve - must be better than all simpler equations
    dominating = PopMember{T}[]
    actualMaxsize = options.maxsize + MAX_DEGREE
    for size in 1:actualMaxsize
        if !hallOfFame.exists[size]
            continue
        end
        member = hallOfFame.members[size]
        # We check if this member is better than all members which are smaller than it and
        # also exist.
        betterThanAllSmaller = true
        for i in 1:(size - 1)
            if !hallOfFame.exists[i]
                continue
            end
            simpler_member = hallOfFame.members[i]
            if member.loss >= simpler_member.loss
                betterThanAllSmaller = false
                break
            end
        end
        if betterThanAllSmaller
            push!(dominating, copy_pop_member(member))
        end
    end
    return dominating
end

"""
    calculate_pareto_frontier(X::AbstractMatrix{T}, y::AbstractVector{T},
                            hallOfFame::HallOfFame{T}, options::Options;
                            weights=nothing, varMap=nothing) where {T<:Real}

Compute the dominating Pareto frontier for a given hallOfFame. This
is the list of equations where each equation has a better loss than all
simpler equations.
"""
function calculate_pareto_frontier(
    X::AbstractMatrix{T},
    y::AbstractVector{T},
    hallOfFame::HallOfFame{T},
    options::Options;
    weights=nothing,
    varMap=nothing,
)::Vector{PopMember{T}} where {T<:Real}
    return calculate_pareto_frontier(
        Dataset(X, y; weights=weights, varMap=varMap), hallOfFame, options
    )
end

function string_dominating_pareto_curve(hallOfFame, dataset, options)
    output = ""
    curMSE = Float64(dataset.baseline_loss)
    lastMSE = curMSE
    lastComplexity = 0
    output *= "Hall of Fame:\n"
    output *= "-----------------------------------------\n"
    output *= @sprintf(
        "%-10s  %-8s   %-8s  %-8s\n", "Complexity", "Loss", "Score", "Equation"
    )

    dominating = calculate_pareto_frontier(dataset, hallOfFame, options)
    for member in dominating
        complexity = compute_complexity(member.tree, options)
        if member.loss < 0.0
            throw(
                DomainError(
                    member.loss,
                    "Your loss function must be non-negative. To do this, consider wrapping your loss inside an exponential, which will not affect the search (unless you are using annealing).",
                ),
            )
        end
        curMSE = member.loss

        delta_c = complexity - lastComplexity
        ZERO_POINT = 1e-10
        delta_l_mse = log(abs(curMSE / lastMSE) + ZERO_POINT)
        score = convert(Float32, -delta_l_mse / delta_c)
        output *= @sprintf(
            "%-10d  %-8.3e  %-8.3e  %-s\n",
            complexity,
            curMSE,
            score,
            string_tree(member.tree, options.operators, varMap=dataset.varMap)
        )
        lastMSE = curMSE
        lastComplexity = complexity
    end
    output *= "\n"
    return output
end

end
