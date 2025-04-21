module HallOfFameModule

using DispatchDoctor: @unstable
using StyledStrings: styled
using DynamicExpressions: AbstractExpression, string_tree
using ..UtilsModule: split_string, AnnotatedIOBuffer, dump_buffer
using ..CoreModule: AbstractOptions, Dataset, DATA_TYPE, LOSS_TYPE, relu, create_expression
using ..ComplexityModule: compute_complexity
using ..PopMemberModule: AbstractPopMember, PopMember
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
struct HallOfFame{T<:DATA_TYPE,L<:LOSS_TYPE,N<:AbstractExpression{T},PM<:AbstractPopMember{T,L,N}}
    members::Array{PM,1}
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

    return HallOfFame{T,L,typeof(base_tree), PopMember{T,L,typeof(base_tree)}}(
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
@unstable function calculate_pareto_frontier(hallOfFame::HallOfFame{T,L,N}) where {T,L,N}
    # TODO - remove dataset from args.
    # Dominating pareto curve - must be better than all simpler equations
    dominating = similar(hallOfFame.members, 0)
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

# const HEADER = let
#     join(
#         (
#             rpad(styled"{bold:{underline:Complexity}}", 10),
#             rpad(styled"{bold:{underline:Loss}}", 9),
#             rpad(styled"{bold:{underline:Score}}", 9),
#             styled"{bold:{underline:Equation}}",
#         ),
#         "  ",
#     )
# end

_fmt(x::Integer)       = @sprintf("%-10d", x)
_fmt(x::AbstractFloat) = @sprintf("%-8.3e", x)
_fmt(x)                = rpad(string(x), 12)        # fallback

function string_dominating_pareto_curve(
    hallOfFame, dataset, options; width::Union{Integer,Nothing}=nothing, pretty::Bool=true
)
    terminal_width = (width === nothing) ? 100 : max(100, width::Integer)
    formatted = format_hall_of_fame(hallOfFame, options)
    stat_cols  = collect(propertynames(formatted))
    filter!(c -> c ≠ :trees, stat_cols)
    priority   = [:complexity, :loss, :score]
    stat_cols  = vcat(intersect(priority, stat_cols),
                      setdiff(stat_cols, priority))
    header_cells = [rpad(styled("{bold:{underline:$(titlecase(string(c)))}}"), 12) for c in stat_cols]
    push!(header_cells, styled("{bold:{underline:Equation}}"))
    header = join(header_cells, "  ")

    _buffer = IOBuffer()
    buffer = AnnotatedIOBuffer(_buffer)
    println(buffer, '─'^(terminal_width - 1))
    println(buffer, header)
    for i in 1:length(formatted.trees)
        stats  = join((_fmt(getfield(formatted, c)[i]) for c in stat_cols), "  ")
        print(buffer, stats)
        eqn = string_tree(formatted.trees[i], options;
                          display_variable_names = dataset.display_variable_names,
                          X_sym_units            = dataset.X_sym_units,
                          y_sym_units            = dataset.y_sym_units,
                          pretty)
        prefix = make_prefix(formatted.trees[i], options, dataset)
        print(buffer,
              wrap_equation_string(prefix * eqn,
                                   length(stats) + length(prefix) + 2,
                                   terminal_width))
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
    _buffer = IOBuffer()
    buffer = AnnotatedIOBuffer(_buffer)

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

@unstable function format_hall_of_fame(hof::HallOfFame{T,L,N,PM}, options;
    columns::Union{Vector{Symbol},Nothing}=[:losses, :complexities, :scores, :trees]
    ) where {T,L,N,PM<:PopMember{T,L,N}}
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

    member_fields = if length(dominating) == 0
        Union{}[]
    else
        collect(propertynames(first(dominating)))
    end
    filter!(f -> f != :tree && f != :loss, member_fields)
    coldata = Dict{Symbol,Any}()
    coldata[:trees] = [member.tree for member in dominating]
    coldata[:losses] = [member.loss for member in dominating]

    for f in member_fields
        coldata[f] = [getfield(m, f) for m in dominating]
    end
    coldata[:complexities] = [compute_complexity(m, options) for m in dominating]
    ZERO_POINT = eps(L)
    cur_loss = typemax(L)
    last_loss = cur_loss
    last_complexity = 0

    coldata[:scores] = Vector{L}(undef, length(dominating))
    for i in eachindex(dominating)
        complexity = coldata[:complexities][i]
        cur_loss = coldata[:losses][i]
        delta_c = complexity - last_complexity
        delta_l_mse = log(relu(cur_loss / last_loss) + ZERO_POINT)
        coldata[:scores][i] = relu(-delta_l_mse / delta_c)
        last_loss = cur_loss
        last_complexity = complexity
    end
    # For coldata, only keep the columns that are in `columns`
    if columns !== nothing
        for c in keys(coldata)
            if !(c in columns)
                delete!(coldata, c)
            end
        end
    end
    return NamedTuple(coldata)
end

@unstable function format_hall_of_fame(hof::AbstractVector{<:HallOfFame}, options)
    outs = [format_hall_of_fame(h, options) for h in hof]
    isempty(outs) && return NamedTuple()
    ks = propertynames(first(outs))
    vals = map(k -> [getfield(o, k) for o in outs], ks)
    return NamedTuple{ks}(vals)
end
# TODO: Re-use this in `string_dominating_pareto_curve`

end
