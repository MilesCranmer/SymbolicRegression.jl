module PopMemberModule

using DispatchDoctor: @unstable
using DynamicExpressions: AbstractExpression, AbstractExpressionNode, string_tree
using ..CoreModule: AbstractOptions, Dataset, DATA_TYPE, LOSS_TYPE, create_expression
import ..ComplexityModule: compute_complexity
using ..UtilsModule: get_birth_order
using ..LossFunctionsModule: eval_cost

# Define a member of population by equation, cost, and age
mutable struct PopMember{T<:DATA_TYPE,L<:LOSS_TYPE,N<:AbstractExpression{T}}
    tree::N
    cost::L  # Inludes complexity penalty, normalization
    loss::L  # Raw loss
    birth::Int
    complexity::Int

    # For recording history:
    ref::Int
    parent::Int
end
@inline function Base.setproperty!(member::PopMember, field::Symbol, value)
    if field == :complexity
        throw(
            error("Don't set `.complexity` directly. Use `recompute_complexity!` instead.")
        )
    elseif field == :tree
        setfield!(member, :complexity, -1)
    elseif field == :score
        Base.depwarn(
            "deprecated: use `cost` instead of `score`.", Symbol(:setproperty!, :PopMember)
        )
        return setfield!(member, :cost, value)
    end
    return setfield!(member, field, value)
end
@unstable @inline function Base.getproperty(member::PopMember, field::Symbol)
    if field == :complexity
        throw(
            error("Don't access `.complexity` directly. Use `compute_complexity` instead.")
        )
    elseif field == :score
        Base.depwarn(
            "deprecated: use `cost` instead of `score`.", Symbol(:getproperty, :PopMember)
        )
        return getfield(member, :cost)
    end
    return getfield(member, field)
end
function Base.show(io::IO, p::PopMember{T,L,N}) where {T,L,N}
    shower(x) = sprint(show, x)
    print(io, "PopMember(")
    print(io, "tree = (", string_tree(p.tree), "), ")
    print(io, "loss = ", shower(p.loss), ", ")
    print(io, "cost = ", shower(p.cost))
    print(io, ")")
    return nothing
end

generate_reference() = abs(rand(Int))

"""
    PopMember(t::AbstractExpression{T}, cost::L, loss::L)

Create a population member with a birth date at the current time.
The type of the `Node` may be different from the type of the cost
and loss.

# Arguments

- `t::AbstractExpression{T}`: The tree for the population member.
- `cost::L`: The cost (normalized to a baseline, and offset by a complexity penalty)
- `loss::L`: The raw loss to assign.
"""
function PopMember(
    t::AbstractExpression{T},
    cost::L,
    loss::L,
    options::Union{AbstractOptions,Nothing}=nothing,
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
        cost,
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
        options::AbstractOptions
    )

Create a population member with a birth date at the current time.
Automatically compute the cost for this tree.

# Arguments

- `dataset::Dataset{T,L}`: The dataset to evaluate the tree on.
- `t::AbstractExpression{T}`: The tree for the population member.
- `options::AbstractOptions`: What options to use.
"""
function PopMember(
    dataset::Dataset{T,L},
    tree::Union{AbstractExpressionNode{T},AbstractExpression{T}},
    options::AbstractOptions,
    complexity::Union{Int,Nothing}=nothing;
    ref::Int=-1,
    parent::Int=-1,
    deterministic=nothing,
) where {T<:DATA_TYPE,L<:LOSS_TYPE}
    ex = create_expression(tree, options, dataset)
    set_complexity = complexity === nothing ? compute_complexity(ex, options) : complexity
    @assert set_complexity != -1
    cost, loss = eval_cost(dataset, ex, options; complexity=set_complexity)
    return PopMember(
        ex,
        cost,
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
    cost = copy(p.cost)
    loss = copy(p.loss)
    birth = copy(p.birth)
    complexity = copy(getfield(p, :complexity))
    ref = copy(p.ref)
    parent = copy(p.parent)
    return P(tree, cost, loss, birth, complexity, ref, parent)
end

function reset_birth!(p::PopMember; deterministic::Bool)
    p.birth = get_birth_order(; deterministic)
    return p
end

# Can read off complexity directly from pop members
function compute_complexity(
    member::PopMember, options::AbstractOptions; break_sharing=Val(false)
)::Int
    complexity = getfield(member, :complexity)
    complexity == -1 && return recompute_complexity!(member, options; break_sharing)
    # TODO: Turn this into a warning, and then return normal compute_complexity instead.
    return complexity
end
function recompute_complexity!(
    member::PopMember, options::AbstractOptions; break_sharing=Val(false)
)::Int
    complexity = compute_complexity(member.tree, options; break_sharing)
    setfield!(member, :complexity, complexity)
    return complexity
end

end
