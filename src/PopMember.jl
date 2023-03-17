module PopMemberModule

import DynamicExpressions: Node, copy_node
import ..CoreModule: Options, Dataset, DATA_TYPE, LOSS_TYPE
import ..UtilsModule: get_birth_order
import ..LossFunctionsModule: score_func

# Define a member of population by equation, score, and age
mutable struct PopMember{T<:DATA_TYPE,L<:LOSS_TYPE}
    tree::Node{T}
    score::L  # Inludes complexity penalty, normalization
    loss::L  # Raw loss
    birth::Int

    # For recording history:
    ref::Int
    parent::Int
end

generate_reference() = abs(rand(Int))

"""
    PopMember(t::Node{T}, score::L, loss::L)

Create a population member with a birth date at the current time.

# Arguments

- `t::Node`: The tree for the population member.
- `score::T`: The score (normalized to a baseline, and offset by a complexity penalty)
- `loss::T`: The raw loss to assign.
"""
function PopMember(
    t::Node{T}, score::L, loss::L; ref::Int=-1, parent::Int=-1, deterministic=false
) where {T<:DATA_TYPE,L<:LOSS_TYPE}
    if ref == -1
        ref = generate_reference()
    end
    return PopMember{T,L}(
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
    dataset::Dataset{T,L},
    t::Node{T},
    options::Options;
    ref::Int=-1,
    parent::Int=-1,
    deterministic=nothing,
) where {T<:DATA_TYPE,L<:LOSS_TYPE}
    score, loss = score_func(dataset, t, options)
    return PopMember(t, score, loss; ref=ref, parent=parent, deterministic=deterministic)
end

function copy_pop_member(
    p::PopMember{T,L}
)::PopMember{T,L} where {T<:DATA_TYPE,L<:LOSS_TYPE}
    tree = copy_node(p.tree)
    score = copy(p.score)
    loss = copy(p.loss)
    birth = copy(p.birth)
    ref = copy(p.ref)
    parent = copy(p.parent)
    return PopMember{T,L}(tree, score, loss, birth, ref, parent)
end

function copy_pop_member_reset_birth(p::P; deterministic::Bool)::P where {P<:PopMember}
    new_member = copy_pop_member(p)
    new_member.birth = get_birth_order(; deterministic=deterministic)
    return new_member
end

end
