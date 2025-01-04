module HallOfFameModule

using StyledStrings: @styled_str
using DynamicExpressions: AbstractExpression, string_tree
# using DataStructures: PriorityQueue
using Printf: @sprintf
using ..UtilsModule: split_string, AnnotatedIOBuffer, dump_buffer
using ..CoreModule: ParetoSingleOptions, ParetoNeighborhoodOptions
using ..CoreModule: AbstractOptions, Dataset, DATA_TYPE, LOSS_TYPE, relu, create_expression
using ..ComplexityModule: compute_complexity
using ..PopMemberModule: PopMember
using ..InterfaceDynamicExpressionsModule: format_dimensions, WILDCARD_UNIT_STRING
using ..PopulationModule: Population

"""
    AbstractParetoElement{P<:PopMember}

Abstract type for storing elements on the Pareto frontier.

# Subtypes
- `ParetoSingle`: Stores a single member at each complexity level
- `ParetoNeighborhood`: Stores multiple members at each complexity level in a fixed-size bucket
"""
abstract type AbstractParetoElement{P<:PopMember} end

pop_member_type(::Type{<:AbstractParetoElement{P}}) where {P} = P

struct ParetoSingle{T,L,N,P<:PopMember{T,L,N}} <: AbstractParetoElement{P}
    member::P
end
struct ParetoNeighborhood{T,L,N,P<:PopMember{T,L,N}} <: AbstractParetoElement{P}
    members::Vector{P}
    bucket_size::Int
end

Base.copy(el::ParetoSingle) = ParetoSingle(copy(el.member))
Base.copy(el::ParetoNeighborhood) = ParetoNeighborhood(copy(el.members), el.bucket_size)

Base.first(el::ParetoSingle) = el.member
Base.first(el::ParetoNeighborhood) = first(el.members)

Base.iterate(el::ParetoSingle) = (el.member, nothing)
Base.iterate(::ParetoSingle, ::Nothing) = nothing
Base.iterate(el::ParetoNeighborhood) = iterate(el.members)
Base.iterate(el::ParetoNeighborhood, state) = iterate(el.members, state)

function Base.show(io::IO, mime::MIME"text/plain", el::ParetoSingle)
    print(io, "ParetoSingle(")
    show(io, mime, el.member)
    print(io, ")")
    return nothing
end

function _depwarn_pareto_single(funcsym::Symbol)
    return Base.depwarn(
        "Hall of fame `.members` is now a vector of `AbstractParetoElement` objects. ",
        funcsym,
    )
end

function Base.getproperty(s::ParetoSingle, name::Symbol)
    name == :member && return getfield(s, :member)
    _depwarn_pareto_single(:getproperty)
    return getproperty(s.member, name)
end
function Base.setproperty!(s::ParetoSingle, name::Symbol, value)
    name == :member && return setfield!(s, :member, value)
    _depwarn_pareto_single(:setproperty!)
    return setproperty!(s.member, name, value)
end

"""
    HallOfFame{T<:DATA_TYPE,L<:LOSS_TYPE,N<:AbstractExpression{T}}

List of the best members seen all time in `.members`, with `.members[c]` being
the best member seen at complexity c. Including only the members which actually
have been set, you can run `.members[exists]`.

# Fields

- `members::Array{PopMember{T,L},1}`: List of the best members seen all time.
    These are ordered by complexity, with `.members[1]` the member with complexity 1.
- `exists::Array{Bool,1}`: Whether the member at the given complexity has been set.
"""
struct HallOfFame{
    T<:DATA_TYPE,
    L<:LOSS_TYPE,
    N<:AbstractExpression{T},
    H<:AbstractParetoElement{<:PopMember{T,L,N}},
}
    elements::Vector{H}
    exists::Vector{Bool}
end
pop_member_type(::Type{<:HallOfFame{T,L,N,H}}) where {T,L,N,H} = pop_member_type(H)
function Base.getproperty(hof::HallOfFame, name::Symbol)
    if name == :members
        Base.depwarn(
            "HallOfFame.members is deprecated. Use HallOfFame.elements instead.",
            :getproperty,
        )
        return getfield(hof, :elements)
    end
    return getfield(hof, name)
end
function Base.show(io::IO, mime::MIME"text/plain", hof::HallOfFame{T,L,N}) where {T,L,N}
    println(io, "HallOfFame{...}:")
    for i in eachindex(hof.elements, hof.exists)
        s_element, s_exists = if hof.exists[i]
            sprint((io, m) -> show(io, mime, m), hof.elements[i]), "true"
        else
            "undef", "false"
        end
        println(io, " "^4 * ".exists[$i] = $s_exists")
        print(io, " "^4 * ".elements[$i] =")
        splitted = split(strip(s_element), '\n')
        if length(splitted) == 1
            println(io, " " * s_element)
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
    options::AbstractOptions, dataset::Dataset{T,L};
) where {T<:DATA_TYPE,L<:LOSS_TYPE}
    base_tree = create_expression(zero(T), options, dataset)
    N = typeof(base_tree)
    member = PopMember(
        base_tree, L(0), L(Inf), options; parent=-1, deterministic=options.deterministic
    )

    return HallOfFame(
        [init_element(options.pareto_element_options, member) for i in 1:(options.maxsize)],
        [false for i in 1:(options.maxsize)],
    )
end
Base.copy(hof::HallOfFame) = HallOfFame(map(copy, hof.members), copy(hof.exists))

function init_element(::Union{ParetoSingleOptions,ParetoSingle}, member::PopMember)
    return ParetoSingle(copy(member))
end
function init_element(
    opt::Union{ParetoNeighborhoodOptions,ParetoNeighborhood}, member::PopMember
)
    return ParetoNeighborhood([copy(member)], opt.bucket_size)
end

function Base.push!(hof::HallOfFame, (size, member)::Pair{<:Integer,<:PopMember})
    maxsize = length(hof.elements)
    if 0 < size <= maxsize
        if !hof.exists[size]
            hof.elements[size] = init_element(hof.elements[size], member)
            hof.exists[size] = true
        else
            hof.elements[size] = push!(hof.elements[size], member.score => member)
        end
    end
    return hof
end

function Base.push!(el::ParetoSingle, (score, member)::Pair{<:LOSS_TYPE,<:PopMember})
    return el.member.score > score ? ParetoSingle(copy(member)) : el
end
function Base.push!(el::ParetoNeighborhood, (score, member)::Pair{<:LOSS_TYPE,<:PopMember})
    return error("Not implemented")
end

function Base.push!(hof::HallOfFame, pop::Population; options::AbstractOptions)
    for member in pop.members
        size = compute_complexity(member, options)
        push!(hof, size => member)
    end
    return hof
end

function Base.merge!(hof1::HallOfFame, hof2::HallOfFame)
    for i in eachindex(hof1.elements, hof1.exists, hof2.elements, hof2.exists)
        if hof1.exists[i] && hof2.exists[i]
            hof1.elements[i] = merge(hof1.elements[i], hof2.elements[i])
        elseif !hof1.exists[i] && hof2.exists[i]
            hof1.elements[i] = copy(hof2.elements[i])
            hof1.exists[i] = true
        else
            # do nothing, as !hof2.exists[i]
        end
    end
    return hof1
end
function Base.merge(el1::ParetoSingle, el2::ParetoSingle)
    # Remember: we want the MIN score (bad API choice, but we're stuck with it for now)
    return el1.member.score <= el2.member.score ? el1 : copy(el2)
end
function Base.merge(el1::ParetoNeighborhood, el2::ParetoNeighborhood)
    return error("Not implemented")
end

"""
    calculate_pareto_frontier(hof::HallOfFame)

Compute the dominating pareto curve - each returned member must be better than all simpler equations.
"""
function calculate_pareto_frontier(hof::HallOfFame)
    P = pop_member_type(typeof(hof))
    dominating = P[]
    for i in eachindex(hof.elements)
        if !hof.exists[i]
            continue
        end
        element = hof.elements[i]
        member = first(element)
        # We check if this member is better than all
        # elements which are smaller than it and also exist.
        is_dominating = true
        for j in 1:(i - 1)
            if !hof.exists[j]
                continue
            end
            smaller_element = hof.elements[j]
            smaller_member = first(smaller_element)
            if member.loss >= smaller_member.loss
                is_dominating = false
                break
            end
            # TODO: Why are we using loss and not score? In other words,
            #       why are we _pushing_ based on score and not loss?
        end
        if is_dominating
            push!(dominating, copy(member))
        end
    end
    return dominating
end

const HEADER = let
    join(
        (
            rpad(styled"{bold:{underline:Complexity}}", 10),
            rpad(styled"{bold:{underline:Loss}}", 9),
            rpad(styled"{bold:{underline:Score}}", 9),
            styled"{bold:{underline:Equation}}",
        ),
        "  ",
    )
end

function string_dominating_pareto_curve(
    hallOfFame, dataset, options; width::Union{Integer,Nothing}=nothing, pretty::Bool=true
)
    terminal_width = (width === nothing) ? 100 : max(100, width::Integer)
    _buffer = IOBuffer()
    buffer = AnnotatedIOBuffer(_buffer)
    println(buffer, '─'^(terminal_width - 1))
    println(buffer, HEADER)

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
        stats_columns_string = @sprintf("%-10d  %-8.3e  %-8.3e  ", complexity, loss, score)
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
