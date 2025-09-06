module HallOfFameModule

using StyledStrings: @styled_str
using DynamicExpressions: AbstractExpression, string_tree
using ..UtilsModule: split_string, AnnotatedIOBuffer, dump_buffer
using ..CoreModule:
    AbstractOptions, Dataset, DATA_TYPE, LOSS_TYPE, relu, create_expression, init_value
using ..ComplexityModule: compute_complexity
using ..PopMemberModule: AbstractPopMember, PopMember
import ..PopMemberModule: popmember_type
using ..InterfaceDynamicExpressionsModule: format_dimensions, WILDCARD_UNIT_STRING
using Printf: @sprintf

"""
    HallOfFame{T<:DATA_TYPE,L<:LOSS_TYPE,N<:AbstractExpression{T},PM<:AbstractPopMember{T,L,N}}

List of the best members seen all time in `.members`, with `.members[c]` being
the best member seen at complexity c. Including only the members which actually
have been set, you can run `.members[exists]`.

# Fields

- `members::Array{PM,1}`: List of the best members seen all time.
    These are ordered by complexity, with `.members[1]` the member with complexity 1.
- `exists::Array{Bool,1}`: Whether the member at the given complexity has been set.
"""
struct HallOfFame{
    T<:DATA_TYPE,L<:LOSS_TYPE,N<:AbstractExpression{T},PM<:AbstractPopMember{T,L,N}
}
    members::Array{PM,1}
    exists::Array{Bool,1} #Whether it has been set
end
function Base.show(
    io::IO, mime::MIME"text/plain", hof::HallOfFame{T,L,N,PM}
) where {T,L,N,PM}
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
function Base.eltype(::Union{HOF,Type{HOF}}) where {T,L,N,PM,HOF<:HallOfFame{T,L,N,PM}}
    return PM
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
    base_tree = create_expression(init_value(T), options, dataset)

    return HallOfFame{T,L,typeof(base_tree),PopMember{T,L,typeof(base_tree)}}(
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
function calculate_pareto_frontier(hallOfFame::HallOfFame{T,L,N,PM}) where {T,L,N,PM}
    # TODO - remove dataset from args.
    # Dominating pareto curve - must be better than all simpler equations
    dominating = PM[]
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

let header_parts = (
        rpad(styled"{bold:{underline:Complexity}}", 10),
        rpad(styled"{bold:{underline:Loss}}", 9),
        rpad(styled"{bold:{underline:Score}}", 9),
        styled"{bold:{underline:Equation}}",
    )
    @eval const HEADER = join($(header_parts), "  ")
    @eval const HEADER_WITHOUT_SCORE = join($(header_parts[[1, 2, 4]]), "  ")
end

show_score_column(options::AbstractOptions) = options.loss_scale == :log

function string_dominating_pareto_curve(
    hallOfFame, dataset, options; width::Union{Integer,Nothing}=nothing, pretty::Bool=true
)
    terminal_width = (width === nothing) ? 100 : max(100, width::Integer)
    buffer = AnnotatedIOBuffer(IOBuffer())
    println(buffer, '─'^(terminal_width - 1))
    if show_score_column(options)
        println(buffer, HEADER)
    else
        println(buffer, HEADER_WITHOUT_SCORE)
    end

    formatted = format_hall_of_fame(hallOfFame, options)
    for (tree, score, loss, complexity) in
        zip(formatted.trees, formatted.scores, formatted.losses, formatted.complexities)
        eqn_string = string_tree(
            tree,
            options;
            display_variable_names=dataset.display_variable_names,
            X_sym_units=dataset.X_sym_units,
            y_sym_units=dataset.y_sym_units,
            pretty,
        )
        prefix = make_prefix(tree, options, dataset)
        eqn_string = prefix * eqn_string
        stats_columns_string = if show_score_column(options)
            @sprintf("%-10d  %-8.3e  %-8.3e  ", complexity, loss, score)
        else
            @sprintf("%-10d  %-8.3e  ", complexity, loss)
        end
        left_cols_width = length(stats_columns_string)
        print(buffer, stats_columns_string)
        print(
            buffer,
            wrap_equation_string(
                eqn_string, left_cols_width + length(prefix), terminal_width
            ),
        )
    end
    print(buffer, '─'^(terminal_width - 1))
    return dump_buffer(buffer)
end
function make_prefix(::AbstractExpression, ::AbstractOptions, dataset::Dataset)
    y_prefix = dataset.y_variable_name
    unit_str = format_dimensions(dataset.y_sym_units)
    y_prefix *= unit_str
    if dataset.y_sym_units === nothing && dataset.X_sym_units !== nothing
        y_prefix *= WILDCARD_UNIT_STRING
    end
    return y_prefix * " = "
end

function wrap_equation_string(eqn_string, left_cols_width, terminal_width)
    dots = "..."
    equation_width = (terminal_width - 1) - left_cols_width - length(dots)

    buffer = AnnotatedIOBuffer(IOBuffer())

    forced_split_eqn = split(eqn_string, '\n')
    print_pad = false
    for piece in forced_split_eqn
        subpieces = split_string(piece, equation_width)
        for (i, subpiece) in enumerate(subpieces)
            # We don't need dots on the last subpiece, since it
            # is either the last row of the entire string, or it has
            # an explicit newline in it!
            requires_dots = i < length(subpieces)
            print(buffer, ' '^(print_pad * left_cols_width))
            print(buffer, subpiece)
            if requires_dots
                print(buffer, dots)
            end
            println(buffer)
            print_pad = true
        end
    end
    return dump_buffer(buffer)
end

function format_hall_of_fame(hof::HallOfFame{T,L}, options) where {T,L}
    dominating = calculate_pareto_frontier(hof)

    # Only check for negative losses if using logarithmic scaling
    options.loss_scale == :log && for member in dominating
        if member.loss < 0.0
            throw(
                DomainError(
                    member.loss,
                    "Your loss function must be non-negative. To allow negative losses, set the `loss_scale` to linear, or consider wrapping your loss inside an exponential.",
                ),
            )
        end
    end

    trees = [member.tree for member in dominating]
    losses = [member.loss for member in dominating]
    complexities = [compute_complexity(member, options) for member in dominating]
    scores = Array{L}(undef, length(dominating))

    cur_loss = typemax(L)
    last_loss = cur_loss
    last_complexity = zero(eltype(complexities))

    for i in 1:length(dominating)
        complexity = complexities[i]
        cur_loss = losses[i]
        delta_c = complexity - last_complexity
        scores[i] = if i == 1
            zero(L)
        else
            if options.loss_scale == :linear
                compute_direct_score(cur_loss, last_loss, delta_c)
            else
                compute_zero_centered_score(cur_loss, last_loss, delta_c)
            end
        end
        last_loss = cur_loss
        last_complexity = complexity
    end
    return (; trees, scores, losses, complexities)
end
function compute_direct_score(cur_loss, last_loss, delta_c)
    delta = cur_loss - last_loss
    return relu(-delta / delta_c)
end
function compute_zero_centered_score(cur_loss, last_loss, delta_c)
    log_ratio = log(relu(cur_loss / last_loss) + eps(cur_loss))
    return relu(-log_ratio / delta_c)
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

# Type accessor for HallOfFame
popmember_type(::Type{<:HallOfFame{T,L,N,PM}}) where {T,L,N,PM} = PM

end
