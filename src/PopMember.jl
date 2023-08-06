module PopMemberModule

import DynamicExpressions: Node, copy_node, count_nodes
import ..CoreModule: Options, Dataset, DATA_TYPE, LOSS_TYPE
import ..ComplexityModule: compute_complexity
import ..UtilsModule: get_birth_order
import ..LossFunctionsModule: score_func

# Define a member of population by equation, score, and age
mutable struct PopMember{T<:DATA_TYPE,L<:LOSS_TYPE}
    tree::Node{T}
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
function Base.getproperty(member::PopMember, field::Symbol)
    field == :complexity && throw(
        error("Don't access `.complexity` directly. Use `compute_complexity` instead.")
    )
    return getfield(member, field)
end

generate_reference() = abs(rand(Int))

"""
    PopMember(t::Node{T}, score::L, loss::L)

Create a population member with a birth date at the current time.
The type of the `Node` may be different from the type of the score
and loss.

# Arguments

- `t::Node{T}`: The tree for the population member.
- `score::L`: The score (normalized to a baseline, and offset by a complexity penalty)
- `loss::L`: The raw loss to assign.
"""
function PopMember(
    t::Node{T},
    score::L,
    loss::L,
    options::Options,
    complexity::Union{Int,Nothing}=nothing;
    ref::Int=-1,
    parent::Int=-1,
    deterministic=false,
) where {T<:DATA_TYPE,L<:LOSS_TYPE}
    if ref == -1
        ref = generate_reference()
    end
    complexity = complexity === nothing ? -1 : complexity
    return PopMember{T,L}(
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
    PopMember(dataset::Dataset{T,L},
              t::Node{T}, options::Options)

Create a population member with a birth date at the current time.
Automatically compute the score for this tree.

# Arguments

- `dataset::Dataset{T,L}`: The dataset to evaluate the tree on.
- `t::Node{T}`: The tree for the population member.
- `options::Options`: What options to use.
"""
function PopMember(
    dataset::Dataset{T,L},
    t::Node{T},
    options::Options,
    complexity::Union{Int,Nothing}=nothing;
    ref::Int=-1,
    parent::Int=-1,
    deterministic=nothing,
) where {T<:DATA_TYPE,L<:LOSS_TYPE}
    set_complexity = complexity === nothing ? compute_complexity(t, options) : complexity
    @assert set_complexity != -1
    score, loss = score_func(dataset, t, options; complexity=set_complexity)
    return PopMember(
        t,
        score,
        loss,
        options,
        set_complexity;
        ref=ref,
        parent=parent,
        deterministic=deterministic,
    )
end

function copy_pop_member(
    p::PopMember{T,L}
)::PopMember{T,L} where {T<:DATA_TYPE,L<:LOSS_TYPE}
    tree = copy_node(p.tree)
    score = copy(p.score)
    loss = copy(p.loss)
    birth = copy(p.birth)
    complexity = copy(getfield(p, :complexity))
    ref = copy(p.ref)
    parent = copy(p.parent)
    return PopMember{T,L}(tree, score, loss, birth, complexity, ref, parent)
end

function copy_pop_member_reset_birth(
    p::PopMember{T,L}; deterministic::Bool
)::PopMember{T,L} where {T<:DATA_TYPE,L<:LOSS_TYPE}
    new_member = copy_pop_member(p)
    new_member.birth = get_birth_order(; deterministic=deterministic)
    return new_member
end

# Can read off complexity directly from pop members
function compute_complexity(member::PopMember, options::Options)::Int
    complexity = getfield(member, :complexity)
    complexity == -1 && return recompute_complexity!(member, options)
    # TODO: Turn this into a warning, and then return normal compute_complexity instead.
    return complexity
end
function recompute_complexity!(member::PopMember, options::Options)::Int
    complexity = compute_complexity(member.tree, options)
    setfield!(member, :complexity, complexity)
    return complexity
end

end
