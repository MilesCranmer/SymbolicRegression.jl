module HallOfFameModule

using StyledStrings: @styled_str
using DynamicExpressions: AbstractExpression, string_tree
using DispatchDoctor: @unstable
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
    PM = options.popmember_type

    # Create a prototype member to get the concrete type
    prototype = PM(
        copy(base_tree),
        L(0),
        L(Inf),
        options,
        1;  # complexity
        parent=-1,
        deterministic=options.deterministic,
    )

    PMtype = typeof(prototype)

    return HallOfFame{T,L,typeof(base_tree),PMtype}(
        [
            if i == 1
                prototype
            else
                PM(
                    copy(base_tree),
                    L(0),
                    L(Inf),
                    options,
                    1;  # complexity
                    parent=-1,
                    deterministic=options.deterministic,
                )
            end for i in 1:(options.maxsize)
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

"""
    member_to_row(member::AbstractPopMember, dataset::Dataset, options::AbstractOptions;
                  pretty::Bool=true)

Convert a PopMember to a row representation for display/export.

This is the primary extension point for custom PopMember types. Users can override this
method to include additional fields in the output.

# Arguments
- `member`: The population member to convert
- `dataset`: Dataset for formatting equation strings
- `options`: Options controlling complexity and equation formatting
- `pretty`: Whether to use pretty-printing for equations (default: true)

# Returns
A NamedTuple containing the member's data. Default fields are:
- `complexity`: Expression complexity
- `loss`: Raw loss value
- `cost`: Cost including complexity penalty
- `birth`: Birth order/generation
- `ref`: Unique reference ID
- `parent`: Parent reference ID
- `equation`: Formatted equation string

# Example 1: Adding custom fields to a custom PopMember
```julia
function SymbolicRegression.HallOfFameModule.member_to_row(
    member::MyCustomPopMember,
    dataset::Dataset,
    options::AbstractOptions;
    kwargs...
)
    base = invoke(member_to_row, Tuple{AbstractPopMember, Dataset, AbstractOptions},
                  member, dataset, options; kwargs...)
    return merge(base, (my_field = member.custom_data,))
end
```

# Example 2: Displaying custom fields in the Hall of Fame
After extending `member_to_row`, create custom columns to display your fields:
```julia
using Printf

custom_columns = [
    HOFColumn(:complexity, "C", row -> row.complexity, string, 5, :right),
    HOFColumn(:loss, "Loss", row -> row.loss, x -> @sprintf("%.3e", x), 9, :right),
    HOFColumn(:my_field, "MyField", row -> row.my_field, x -> @sprintf("%.2f", x), 10, :right),
    HOFColumn(:equation, "Equation", row -> row.equation, identity, nothing, :left)
]

# Display with custom columns
str = string_dominating_pareto_curve(hof, dataset, options; columns=custom_columns)
println(str)

# Or export via Tables.jl with custom columns
rows = hof_rows(hof, dataset, options; columns=custom_columns)
using DataFrames
df = DataFrame(rows)
```
"""
function member_to_row(
    member::AbstractPopMember, dataset::Dataset, options::AbstractOptions; pretty::Bool=true
)
    eqn_string = string_tree(
        member.tree,
        options;
        display_variable_names=dataset.display_variable_names,
        X_sym_units=dataset.X_sym_units,
        y_sym_units=dataset.y_sym_units,
        pretty=pretty,
    )
    prefix = make_prefix(member.tree, options, dataset)
    eqn_string = prefix * eqn_string
    return (
        complexity=compute_complexity(member, options),
        loss=member.loss,
        cost=member.cost,
        birth=member.birth,
        ref=member.ref,
        parent=member.parent,
        equation=eqn_string,
    )
end

"""
    HOFColumn

Specification for a column in Hall of Fame display and export.

# Fields
- `name::Symbol`: Column identifier (key in the row NamedTuple)
- `header::String`: Display header text
- `getter::Function`: Function `(row::NamedTuple) -> value` to extract/compute column value
- `formatter::Function`: Function `(value) -> String` for display formatting (display only)
- `width::Union{Int,Nothing}`: Display width (nothing for auto-sizing)
- `alignment::Symbol`: Text alignment - `:left`, `:right`, or `:center`

# Example
```julia
# Simple column that extracts an existing field
complexity_col = HOFColumn(
    :complexity, "Complexity",
    row -> row.complexity,
    x -> string(x),
    10, :right
)

# Computed column
r2_col = HOFColumn(
    :r2, "R²",
    row -> compute_r2(row),  # Custom computation
    x -> @sprintf("%.3f", x),
    8, :right
)
```
"""
struct HOFColumn
    name::Symbol
    header::String
    getter::Function
    formatter::Function
    width::Union{Int,Nothing}
    alignment::Symbol
end

"""
    default_columns(options::AbstractOptions) -> Vector{HOFColumn}

Return the default column specifications for Hall of Fame display.

The default columns are:
- Complexity (right-aligned, width 10)
- Loss (right-aligned, width 9, scientific notation)
- Score (conditional on `options.loss_scale == :log`, right-aligned, width 9)
- Equation (left-aligned, auto-width)

Users can customize by modifying this vector or creating their own.
"""
function default_columns(options::AbstractOptions)
    cols = HOFColumn[
        HOFColumn(
            :complexity,
            "Complexity",
            row -> row.complexity,
            x -> @sprintf("%d", x),
            10,
            :right,
        ),
        HOFColumn(:loss, "Loss", row -> row.loss, x -> @sprintf("%.3e", x), 9, :right),
    ]

    # Add score column for logarithmic loss scale
    if options.loss_scale == :log
        push!(
            cols,
            HOFColumn(
                :score, "Score", row -> row.score, x -> @sprintf("%.3e", x), 9, :right
            ),
        )
    end

    # Equation column (special handling in display due to wrapping)
    push!(
        cols,
        HOFColumn(:equation, "Equation", row -> row.equation, identity, nothing, :left),
    )

    return cols
end

"""
    HOFRows

A lazy iterator for HallOfFame members that computes rows on-demand.
This struct implements the Tables.jl interface for easy export to DataFrames, CSV, etc.

# Fields
- `members`: Vector of PopMembers to iterate over
- `dataset`: Dataset for formatting equations
- `options`: Options for complexity and formatting
- `include_score`: Whether to compute and include Pareto improvement scores
- `pretty`: Whether to use pretty-printing for equations
- `columns`: Optional column specifications (nothing = all columns from member_to_row)
"""
struct HOFRows{PM<:AbstractPopMember}
    members::Vector{PM}
    dataset::Dataset
    options::AbstractOptions
    include_score::Bool
    pretty::Bool
    columns::Union{Vector{HOFColumn},Nothing}
end

# Helper function to create a single row with optional score and column filtering
@unstable function _make_row(view::HOFRows, i::Int, scores)
    # Get full row from member_to_row
    row = member_to_row(view.members[i], view.dataset, view.options; pretty=view.pretty)

    # Add score if computed
    row = scores === nothing ? row : (; row..., score=scores[i])

    # Apply column filtering if specified
    if view.columns !== nothing
        # Build filtered row using column getters
        filtered_values = [col.getter(row) for col in view.columns]
        filtered_names = Tuple(col.name for col in view.columns)
        return NamedTuple{filtered_names}(filtered_values)
    end

    return row
end

# Make HOFRows iterable
Base.length(view::HOFRows) = length(view.members)
Base.eltype(::Type{<:HOFRows}) = NamedTuple

function Base.iterate(view::HOFRows)
    isempty(view.members) && return nothing

    # Compute all scores upfront if needed
    scores = view.include_score ? compute_scores(view.members, view.options) : nothing
    state = (scores, 1)

    row = _make_row(view, 1, scores)
    return (row, state)
end

function Base.iterate(view::HOFRows, state)
    scores, i = state
    i += 1
    i > length(view.members) && return nothing

    row = _make_row(view, i, scores)
    return (row, (scores, i))
end

"""
    hof_rows(hof::HallOfFame, dataset::Dataset, options::AbstractOptions;
             pareto_only::Bool=true, include_score::Bool=pareto_only,
             pretty::Bool=true, columns::Union{Vector{HOFColumn},Nothing}=nothing)

This function returns an `HOFRows` object.

# Arguments
- `hof`: The HallOfFame to export
- `dataset`: Dataset for formatting equations
- `options`: Options controlling complexity and formatting
- `pareto_only`: Only include Pareto frontier members (default: true)
- `include_score`: Include Pareto improvement scores (default: same as `pareto_only`)
- `pretty`: Use pretty-printing for equations (default: true)
- `columns`: Optional column specifications (default: nothing = all columns from member_to_row)

# Returns
An `HOFRows` object that can be used with Tables.jl-compatible consumers like
`DataFrame`, `CSV.write`, etc.

# Examples
```julia
# Get a Tables.jl view of the Pareto frontier
rows = hof_rows(hof, dataset, options)

# Convert to DataFrame (requires DataFrames.jl)
using DataFrames
df = DataFrame(rows)

# Get all members without scores
all_rows = hof_rows(hof, dataset, options; pareto_only=false, include_score=false)

# Get only specific columns
custom_cols = [
    HOFColumn(:complexity, "Complexity", row -> row.complexity, string, 10, :right),
    HOFColumn(:loss, "Loss", row -> row.loss, x -> @sprintf("%.3e", x), 9, :right)
]
filtered_rows = hof_rows(hof, dataset, options; columns=custom_cols)
```
"""
function hof_rows(
    hof::HallOfFame,
    dataset::Dataset,
    options::AbstractOptions;
    pareto_only::Bool=true,
    include_score::Bool=pareto_only,
    pretty::Bool=true,
    columns::Union{Vector{HOFColumn},Nothing}=nothing,
)
    members = if pareto_only
        calculate_pareto_frontier(hof)
    else
        [m for (m, ex) in zip(hof.members, hof.exists) if ex]
    end

    return HOFRows(members, dataset, options, include_score, pretty, columns)
end

"""
    string_dominating_pareto_curve(
        hallOfFame, dataset, options;
        width::Union{Integer,Nothing}=nothing,
        pretty::Bool=true,
        columns::Union{Vector{HOFColumn},Nothing}=nothing
    )

Format the Pareto frontier as a pretty-printed string table.

# Arguments
- `hallOfFame`: The HallOfFame to display
- `dataset`: Dataset for formatting equations
- `options`: Options controlling complexity and formatting
- `width`: Terminal width (default: 100)
- `pretty`: Use pretty-printing for equations (default: true)
- `columns`: Column specifications (default: nothing = use default_columns(options))

# Example with custom columns
```julia
custom_cols = [
    HOFColumn(:complexity, "C", row -> row.complexity, string, 5, :right),
    HOFColumn(:loss, "Loss", row -> row.loss, x -> @sprintf("%.2e", x), 8, :right),
    HOFColumn(:equation, "Equation", row -> row.equation, identity, nothing, :left)
]
str = string_dominating_pareto_curve(hof, dataset, options; columns=custom_cols)
```
"""
function string_dominating_pareto_curve(
    hallOfFame,
    dataset,
    options;
    width::Union{Integer,Nothing}=nothing,
    pretty::Bool=true,
    columns::Union{Vector{HOFColumn},Nothing}=nothing,
)
    # Use default columns if not specified
    cols = columns === nothing ? default_columns(options) : columns

    terminal_width = (width === nothing) ? 100 : max(100, width::Integer)
    buffer = AnnotatedIOBuffer(IOBuffer())

    # Print top border
    println(buffer, '─'^(terminal_width - 1))

    # Build header from column specs
    header_parts = map(cols) do col
        header_text = styled"{bold:{underline:$(col.header)}}"
        if col.width === nothing
            # Last column (typically equation) - no padding
            header_text
        else
            # Fixed-width column - pad to width
            rpad(header_text, col.width)
        end
    end
    println(buffer, join(header_parts, "  "))

    # Get rows (without column filtering, we'll format ourselves)
    rows_view = hof_rows(
        hallOfFame, dataset, options; pareto_only=true, include_score=true, pretty=pretty
    )
    members = rows_view.members

    # Format each row
    for (i, full_row) in enumerate(rows_view)
        member = members[i]

        # Format all columns except the last one (which may need wrapping)
        formatted_cols = String[]
        for (col_idx, col) in enumerate(cols)
            value = col.getter(full_row)
            formatted = col.formatter(value)

            if col_idx == length(cols)
                # Last column - handle separately for wrapping
                # Calculate left margin from previous columns
                left_cols_width = sum(
                    length(formatted_cols[j]) + 2 for j in 1:(length(formatted_cols))
                )

                # Handle equation prefix if it's an equation column
                if col.name == :equation && haskey(full_row, :equation)
                    prefix = make_prefix(member.tree, options, dataset)
                    wrapped = wrap_equation_string(
                        formatted, left_cols_width + length(prefix), terminal_width
                    )
                    print(buffer, join(formatted_cols, "  "))
                    print(buffer, "  ")
                    print(buffer, wrapped)
                else
                    # Non-equation last column - just print
                    push!(formatted_cols, formatted)
                    println(buffer, join(formatted_cols, "  "))
                end
            else
                # Non-last column - format with alignment and width
                if col.width !== nothing
                    if col.alignment == :right
                        formatted = lpad(formatted, col.width)
                    elseif col.alignment == :center
                        formatted = lpad(
                            rpad(formatted, (col.width + length(formatted)) ÷ 2), col.width
                        )
                    else  # :left
                        formatted = rpad(formatted, col.width)
                    end
                end
                push!(formatted_cols, formatted)
            end
        end
    end

    # Print bottom border
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

"""
    compute_scores(members::Vector{<:AbstractPopMember}, options::AbstractOptions)

Compute improvement scores for an ordered sequence of members.

Scores measure the improvement in loss per unit complexity compared to the previous
member in the sequence. The first member always has a score of zero.

This function works with any ordered sequence of members (e.g., Pareto frontier,
complexity-sorted members, etc.).

# Arguments
- `members`: Vector of PopMembers in the desired order
- `options`: Options controlling the loss scale (`:linear` or `:log`)

# Returns
Vector of scores with the same length as `members`
"""
function compute_scores(
    members::Vector{<:AbstractPopMember{T,L,N}}, options::AbstractOptions
) where {T,L,N}
    isempty(members) && return L[]

    scores = Vector{L}(undef, length(members))

    complexities = [compute_complexity(member, options) for member in members]
    losses = [member.loss for member in members]

    last_loss = typemax(L)
    last_complexity = zero(eltype(complexities))

    for i in eachindex(members)
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

    return scores
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
    scores = compute_scores(dominating, options)

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
