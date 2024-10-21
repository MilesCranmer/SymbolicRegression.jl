module HallOfFameModule

using DynamicExpressions: AbstractExpression, string_tree
using ..UtilsModule: split_string, include_splits_on_newlines
using ..CoreModule:
    MAX_DEGREE, AbstractOptions, Dataset, DATA_TYPE, LOSS_TYPE, relu, create_expression
using ..ComplexityModule: compute_complexity
using ..PopMemberModule: PopMember
using ..InterfaceDynamicExpressionsModule: format_dimensions, WILDCARD_UNIT_STRING
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
struct HallOfFame{T<:DATA_TYPE,L<:LOSS_TYPE,N<:AbstractExpression{T}}
    members::Array{PopMember{T,L,N},1}
    exists::Array{Bool,1} #Whether it has been set
end
function Base.show(io::IO, mime::MIME"text/plain", hof::HallOfFame{T,L,N}) where {T,L,N}
    println(io, "HallOfFame{...}:")
    for i in eachindex(hof.members, hof.exists)
        s_member, s_exists = if hof.exists[i]
            sprint((io, m) -> show(io, mime, m), hof.members[i]), "true"
        else
            "undef", "false"
        end
        println(io, " "^4 * ".exists[$i] = $s_exists")
        print(io, " "^4 * ".members[$i] =")
        splitted = split(strip(s_member), '\n')
        if length(splitted) == 1
            println(io, " " * s_member)
        else
            println(io)
            foreach(line -> println(io, " "^8 * line), splitted)
        end
    end
    return nothing
end

"""
    HallOfFame(options::AbstractOptions, dataset::Dataset{T,L}) where {T<:DATA_TYPE,L<:LOSS_TYPE}

Create empty HallOfFame. The HallOfFame stores a list
of `PopMember` objects in `.members`, which is enumerated
by size (i.e., `.members[1]` is the constant solution).
`.exists` is used to determine whether the particular member
has been instantiated or not.

Arguments:
- `options`: AbstractOptions containing specification about deterministic.
- `dataset`: Dataset containing the input data.
"""
function HallOfFame(
    options::AbstractOptions, dataset::Dataset{T,L}
) where {T<:DATA_TYPE,L<:LOSS_TYPE}
    base_tree = create_expression(zero(T), options, dataset)

    return HallOfFame{T,L,typeof(base_tree)}(
        [
            PopMember(
                copy(base_tree),
                L(0),
                L(Inf),
                options;
                parent=-1,
                deterministic=options.deterministic,
            ) for i in 1:(options.maxsize)
        ],
        [false for i in 1:(options.maxsize)],
    )
end

function Base.copy(hof::HallOfFame)
    return HallOfFame(
        [copy(member) for member in hof.members], [exists for exists in hof.exists]
    )
end

"""
    calculate_pareto_frontier(hallOfFame::HallOfFame{T,L,P}) where {T<:DATA_TYPE,L<:LOSS_TYPE}
"""
function calculate_pareto_frontier(hallOfFame::HallOfFame{T,L,N}) where {T,L,N}
    # TODO - remove dataset from args.
    P = PopMember{T,L,N}
    # Dominating pareto curve - must be better than all simpler equations
    dominating = P[]
    for size in eachindex(hallOfFame.members)
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
            push!(dominating, copy(member))
        end
    end
    return dominating
end

function string_dominating_pareto_curve(
    hallOfFame, dataset, options; width::Union{Integer,Nothing}=nothing
)
    twidth = (width === nothing) ? 100 : max(100, width::Integer)
    output = ""
    output *= "Hall of Fame:\n"
    # TODO: Get user's terminal width.
    output *= "-"^(twidth - 1) * "\n"
    output *= @sprintf(
        "%-10s  %-8s   %-8s  %-8s\n", "Complexity", "Loss", "Score", "Equation"
    )

    formatted = format_hall_of_fame(hallOfFame, options)
    for (tree, score, loss, complexity) in
        zip(formatted.trees, formatted.scores, formatted.losses, formatted.complexities)
        eqn_string = string_tree(
            tree,
            options;
            display_variable_names=dataset.display_variable_names,
            X_sym_units=dataset.X_sym_units,
            y_sym_units=dataset.y_sym_units,
            raw=false,
        )
        y_prefix = dataset.y_variable_name
        unit_str = format_dimensions(dataset.y_sym_units)
        y_prefix *= unit_str
        if dataset.y_sym_units === nothing && dataset.X_sym_units !== nothing
            y_prefix *= WILDCARD_UNIT_STRING
        end
        eqn_string = y_prefix * " = " * eqn_string
        stats_columns_string = @sprintf("%-10d  %-8.3e  %-8.3e  ", complexity, loss, score)
        left_cols_width = length(stats_columns_string)
        output *= stats_columns_string
        output *= wrap_equation_string(eqn_string, left_cols_width, twidth)
    end
    output *= "-"^(twidth - 1)
    return output
end

function wrap_equation_string(eqn_string, left_cols_width, twidth)
    dots = "..."
    equation_width = (twidth - 1) - left_cols_width - length(dots)
    output = ""

    split_eqn = split_string(eqn_string, equation_width)
    split_eqn = include_splits_on_newlines(split_eqn)
    print_pad = false
    while length(split_eqn) > 1
        cur_piece = popfirst!(split_eqn)
        output *= " "^(print_pad * left_cols_width) * cur_piece * dots * "\n"
        print_pad = true
    end
    output *= " "^(print_pad * left_cols_width) * only(split_eqn) * "\n"
    return output
end

function format_hall_of_fame(hof::HallOfFame{T,L}, options) where {T,L}
    dominating = calculate_pareto_frontier(hof)
    foreach(dominating) do member
        if member.loss < 0.0
            throw(
                DomainError(
                    member.loss,
                    "Your loss function must be non-negative. To do this, consider wrapping your loss inside an exponential, which will not affect the search (unless you are using annealing).",
                ),
            )
        end
    end

    ZERO_POINT = eps(L)
    cur_loss = typemax(L)
    last_loss = cur_loss
    last_complexity = 0

    trees = [member.tree for member in dominating]
    losses = [member.loss for member in dominating]
    complexities = [compute_complexity(member, options) for member in dominating]
    scores = Array{L}(undef, length(dominating))

    for i in 1:length(dominating)
        complexity = complexities[i]
        cur_loss = losses[i]
        delta_c = complexity - last_complexity
        delta_l_mse = log(relu(cur_loss / last_loss) + ZERO_POINT)

        scores[i] = relu(-delta_l_mse / delta_c)
        last_loss = cur_loss
        last_complexity = complexity
    end
    return (; trees, scores, losses, complexities)
end
function format_hall_of_fame(hof::AbstractVector{<:HallOfFame}, options)
    outs = [format_hall_of_fame(h, options) for h in hof]
    return (;
        trees=[out.trees for out in outs],
        scores=[out.scores for out in outs],
        losses=[out.losses for out in outs],
        complexities=[out.complexities for out in outs],
    )
end
# TODO: Re-use this in `string_dominating_pareto_curve`

end
