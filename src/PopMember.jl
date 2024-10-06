module PopMemberModule

using DispatchDoctor: @unstable
using DynamicExpressions: AbstractExpression, AbstractExpressionNode, string_tree
using ..CoreModule: Options, Dataset, DATA_TYPE, LOSS_TYPE, create_expression
import ..ComplexityModule: compute_complexity
using ..UtilsModule: get_birth_order
using ..LossFunctionsModule: score_func

# Define a member of population by equation, score, and age
mutable struct PopMember{T<:DATA_TYPE,L<:LOSS_TYPE,N<:AbstractExpression{T}}
    tree::N
    score::L  # Inludes complexity penalty, normalization
    loss::L  # Raw loss
    birth::Int
    complexity::Int

    # For recording history:
    ref::Int
    parent::Int
end
function Base.setproperty!(member::PopMember, field::Symbol, value)
    field == :complexity && throw(
        error("Don't set `.complexity` directly. Use `recompute_complexity!` instead.")
    )
    field == :tree && setfield!(member, :complexity, -1)
    return setfield!(member, field, value)
end
@unstable @inline function Base.getproperty(member::PopMember, field::Symbol)
    field == :complexity && throw(
        error("Don't access `.complexity` directly. Use `compute_complexity` instead.")
    )
    return getfield(member, field)
end
function Base.show(io::IO, p::PopMember{T,L,N}) where {T,L,N}
    shower(x) = sprint(show, x)
    print(io, "PopMember(")
    print(io, "tree = (", string_tree(p.tree), "), ")
    print(io, "loss = ", shower(p.loss), ", ")
    print(io, "score = ", shower(p.score))
    print(io, ")")
    return nothing
end

generate_reference() = abs(rand(Int))

"""
    PopMember(t::AbstractExpression{T}, score::L, loss::L)

Create a population member with a birth date at the current time.
The type of the `Node` may be different from the type of the score
and loss.

# Arguments

- `t::AbstractExpression{T}`: The tree for the population member.
- `score::L`: The score (normalized to a baseline, and offset by a complexity penalty)
- `loss::L`: The raw loss to assign.
"""
function PopMember(
    t::AbstractExpression{T},
    score::L,
    loss::L,
    options::Union{Options,Nothing}=nothing,
    complexity::Union{Int,Nothing}=nothing;
    ref::Int=-1,
    parent::Int=-1,
    deterministic=nothing,
) where {T<:DATA_TYPE,L<:LOSS_TYPE}
    if ref == -1
        ref = generate_reference()
    end
    if !(deterministic isa Bool)
        throw(
            ArgumentError(
                "You must declare `deterministic` as `true` or `false`, it cannot be left undefined.",
            ),
        )
    end
    complexity = complexity === nothing ? -1 : complexity
    return PopMember{T,L,typeof(t)}(
        t,
        score,
        loss,
        get_birth_order(; deterministic=deterministic),
        complexity,
        ref,
        parent,
    )
end

"""
    PopMember(
        dataset::Dataset{T,L},
        t::AbstractExpression{T},
        options::Options
    )

Create a population member with a birth date at the current time.
Automatically compute the score for this tree.

# Arguments

- `dataset::Dataset{T,L}`: The dataset to evaluate the tree on.
- `t::AbstractExpression{T}`: The tree for the population member.
- `options::Options`: What options to use.
"""
function PopMember(
    dataset::Dataset{T,L},
    tree::Union{AbstractExpressionNode{T},AbstractExpression{T}},
    options::Options,
    complexity::Union{Int,Nothing}=nothing;
    ref::Int=-1,
    parent::Int=-1,
    deterministic=nothing,
) where {T<:DATA_TYPE,L<:LOSS_TYPE}
    ex = create_expression(tree, options, dataset)
    set_complexity = complexity === nothing ? compute_complexity(ex, options) : complexity
    @assert set_complexity != -1
    score, loss = score_func(dataset, ex, options; complexity=set_complexity)
    return PopMember(
        ex,
        score,
        loss,
        options,
        set_complexity;
        ref=ref,
        parent=parent,
        deterministic=deterministic,
    )
end

function Base.copy(p::P) where {P<:PopMember}
    tree = copy(p.tree)
    score = copy(p.score)
    loss = copy(p.loss)
    birth = copy(p.birth)
    complexity = copy(getfield(p, :complexity))
    ref = copy(p.ref)
    parent = copy(p.parent)
    return P(tree, score, loss, birth, complexity, ref, parent)
end

function reset_birth!(p::PopMember; deterministic::Bool)
    p.birth = get_birth_order(; deterministic)
    return p
end

# Can read off complexity directly from pop members
function compute_complexity(
    member::PopMember, options::Options; break_sharing=Val(false)
)::Int
    complexity = getfield(member, :complexity)
    complexity == -1 && return recompute_complexity!(member, options; break_sharing)
    # TODO: Turn this into a warning, and then return normal compute_complexity instead.
    return complexity
end
function recompute_complexity!(
    member::PopMember, options::Options; break_sharing=Val(false)
)::Int
    complexity = compute_complexity(member.tree, options; break_sharing)
    setfield!(member, :complexity, complexity)
    return complexity
end

end
