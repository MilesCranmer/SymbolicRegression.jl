module PopMemberModule

import DynamicExpressions: Node, copy_node
import ..CoreModule: Options, Dataset
import ..UtilsModule: get_birth_order
import ..LossFunctionsModule: score_func

# Define a member of population by equation, score, and age
mutable struct PopMember{T<:Real}
    tree::Node{T}
    score::T  # Inludes complexity penalty, normalization
    loss::T  # Raw loss
    birth::Int

    # For recording history:
    ref::Int
    parent::Int
end

generate_reference() = abs(rand(Int))

"""
    PopMember(t::Node, score::T, loss::T)

Create a population member with a birth date at the current time.

# Arguments

- `t::Node`: The tree for the population member.
- `score::T`: The score (normalized to a baseline, and offset by a complexity penalty)
- `loss::T`: The raw loss to assign.
"""
function PopMember(
    t::Node{T}, score::T, loss::T; ref::Int=-1, parent::Int=-1, deterministic=false
) where {T<:Real}
    if ref == -1
        ref = generate_reference()
    end
    return PopMember{T}(
        t, score, loss, get_birth_order(; deterministic=deterministic), ref, parent
    )
end

"""
    PopMember(dataset::Dataset{T},
              t::Node, options::Options)

Create a population member with a birth date at the current time.
Automatically compute the score for this tree.

# Arguments

- `dataset::Dataset{T}`: The dataset to evaluate the tree on.
- `t::Node`: The tree for the population member.
- `options::Options`: What options to use.
"""
function PopMember(
    dataset::Dataset{T},
    t::Node{T},
    options::Options;
    ref::Int=-1,
    parent::Int=-1,
    deterministic=nothing,
) where {T<:Real}
    score, loss = score_func(dataset, t, options)
    return PopMember(t, score, loss; ref=ref, parent=parent, deterministic=deterministic)
end

function copy_pop_member(p::PopMember{T})::PopMember{T} where {T<:Real}
    tree = copy_node(p.tree)
    score = copy(p.score)
    loss = copy(p.loss)
    birth = copy(p.birth)
    ref = copy(p.ref)
    parent = copy(p.parent)
    return PopMember{T}(tree, score, loss, birth, ref, parent)
end

function copy_pop_member_reset_birth(
    p::PopMember{T}; deterministic::Bool
)::PopMember{T} where {T<:Real}
    new_member = copy_pop_member(p)
    new_member.birth = get_birth_order(; deterministic=deterministic)
    return new_member
end

end
