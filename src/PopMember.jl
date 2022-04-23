module PopMemberModule

import ..CoreModule: Options, Dataset, Node, copyNode
import ..UtilsModule: getTime
import ..LossFunctionsModule: scoreFunc

# Define a member of population by equation, score, and age
mutable struct PopMember{T<:Real}
    tree::Node
    score::T  # Inludes complexity penalty, normalization
    loss::T  # Raw loss
    birth::Int

    # For recording history:
    ref::Int
    parent::Int
end

"""
    PopMember(t::Node, score::T, loss::T)

Create a population member with a birth date at the current time.

# Arguments

- `t::Node`: The tree for the population member.
- `score::T`: The score (normalized to a baseline, and offset by a complexity penalty)
- `loss::T`: The raw loss to assign.
"""
function PopMember(t::Node, score::T, loss::T; ref::Int=-1, parent::Int=-1) where {T<:Real}
    if ref == -1
        ref = abs(rand(Int))
    end
    PopMember{T}(t, score, loss, getTime(), ref, parent)
end

"""
    PopMember(dataset::Dataset{T}, baseline::T,
              t::Node, options::Options)

Create a population member with a birth date at the current time.
Automatically compute the score for this tree.

# Arguments

- `dataset::Dataset{T}`: The dataset to evaluate the tree on.
- `baseline::T`: The baseline loss.
- `t::Node`: The tree for the population member.
- `options::Options`: What options to use.
"""
function PopMember(dataset::Dataset{T},
                   baseline::T, t::Node,
                   options::Options; ref::Int=-1, parent::Int=-1) where {T<:Real}
    score, loss = scoreFunc(dataset, baseline, t, options)
    PopMember(t, score, loss, ref=ref, parent=parent)
end

function copyPopMember(p::PopMember{T}) where {T<:Real}
    tree = copyNode(p.tree)
    score = copy(p.score)
    loss = copy(p.loss)
    birth = copy(p.birth)
    ref = copy(p.ref)
    parent = copy(p.parent)
    return PopMember{T}(tree, score, loss, birth, ref, parent)
end

end
