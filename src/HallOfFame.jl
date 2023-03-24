module HallOfFameModule

import DynamicExpressions: Node, string_tree
import ..CoreModule: MAX_DEGREE, Options, Dataset, DATA_TYPE, LOSS_TYPE
import ..ComplexityModule: compute_complexity
import ..PopMemberModule: PopMember, copy_pop_member
import ..LossFunctionsModule: eval_loss
using Printf: @sprintf

"""
HallOfFame{T<:DATA_TYPE,L<:LOSS_TYPE}

List of the best members seen all time in `.members`, with `.members[c]` being
the best member seen at complexity c. Including only the members which actually
have been set, you can run `.members[exists]`.

# Fields

- `members::Array{PopMember{T,L},1}`: List of the best members seen all time.
    These are ordered by complexity, with `.members[1]` the member with complexity 1.
- `exists::Array{Bool,1}`: Whether the member at the given complexity has been set.
"""
mutable struct HallOfFame{T<:DATA_TYPE,L<:LOSS_TYPE}
    members::Array{PopMember{T,L},1}
    exists::Array{Bool,1} #Whether it has been set
end

"""
    HallOfFame(options::Options, ::Type{T}, ::Type{L}) where {T<:DATA_TYPE,L<:LOSS_TYPE}

Create empty HallOfFame. The HallOfFame stores a list
of `PopMember` objects in `.members`, which is enumerated
by size (i.e., `.members[1]` is the constant solution).
`.exists` is used to determine whether the particular member
has been instantiated or not.

Arguments:
- `options`: Options containing specification about deterministic.
- `T`: Type of Nodes to use in the population. e.g., `Float64`.
- `L`: Type of loss to use in the population. e.g., `Float64`.
"""
function HallOfFame(
    options::Options, ::Type{T}, ::Type{L}
) where {T<:DATA_TYPE,L<:LOSS_TYPE}
    actualMaxsize = options.maxsize + MAX_DEGREE
    return HallOfFame{T,L}(
        [
            PopMember(
                Node(; val=convert(T, 1)),
                L(0),
                L(Inf);
                parent=-1,
                deterministic=options.deterministic,
            ) for i in 1:actualMaxsize
        ],
        [false for i in 1:actualMaxsize],
    )
end

function copy_hall_of_fame(
    hof::HallOfFame{T,L}
)::HallOfFame{T,L} where {T<:DATA_TYPE,L<:LOSS_TYPE}
    return HallOfFame(
        [copy_pop_member(member) for member in hof.members],
        [exists for exists in hof.exists],
    )
end

"""
    calculate_pareto_frontier(hallOfFame::HallOfFame{T,L}) where {T<:DATA_TYPE,L<:LOSS_TYPE}
"""
function calculate_pareto_frontier(hallOfFame::HallOfFame{T,L})::Vector{PopMember{T,L}} where {T<:DATA_TYPE,L<:LOSS_TYPE}
    # TODO - remove dataset from args.
    # Dominating pareto curve - must be better than all simpler equations
    dominating = PopMember{T,L}[]
    actualMaxsize = length(hallOfFame.members)
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

function string_dominating_pareto_curve(
    hallOfFame, dataset, options; width::Union{Integer,Nothing}=nothing
)
    twidth = (width === nothing) ? 100 : max(100, width::Integer)
    output = ""
    curMSE = Float64(@atomic dataset.baseline_loss.value)
    lastMSE = curMSE
    lastComplexity = 0
    output *= "Hall of Fame:\n"
    # TODO: Get user's terminal width.
    output *= "-"^(twidth - 1) * "\n"
    output *= @sprintf(
        "%-10s  %-8s   %-8s  %-8s\n", "Complexity", "Loss", "Score", "Equation"
    )

    dominating = calculate_pareto_frontier(hallOfFame)
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
        eqn_string = string_tree(member.tree, options.operators; varMap=dataset.varMap)
        base_string_length = length(@sprintf("%-10d  %-8.3e  %8.3e  ", 1, 1.0, 1.0))

        dots = "..."
        equation_width = (twidth - 1) - base_string_length - length(dots)

        output *= @sprintf("%-10d  %-8.3e  %-8.3e  ", complexity, curMSE, score,)

        split_eqn = split_string(eqn_string, equation_width)
        print_pad = false
        while length(split_eqn) > 1
            cur_piece = popfirst!(split_eqn)
            output *= " "^(print_pad * base_string_length) * cur_piece * dots * "\n"
            print_pad = true
        end
        output *= " "^(print_pad * base_string_length) * split_eqn[1] * "\n"

        lastMSE = curMSE
        lastComplexity = complexity
    end
    output *= "-"^(twidth - 1)
    return output
end

"""
    split_string(s::String, n::Integer)

```jldoctest
split_string("abcdefgh", 3)

# output

["abc", "def", "gh"]
```
"""
function split_string(s::String, n::Integer)
    length(s) <= n && return [s]
    return [s[i:min(i + n - 1, end)] for i in 1:n:length(s)]
end

end
