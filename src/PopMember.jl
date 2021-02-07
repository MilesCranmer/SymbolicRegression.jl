# Define a member of population by equation, score, and age
mutable struct PopMember{T<:Real}
    tree::Node
    score::T
    birth::Int
end

"""
    PopMember(t::Node, score::T)

Create a population member with a birth date at the current time.

# Arguments

- `t::Node`: The tree for the population member.
- `score::T`: The loss to assign this member.
"""
function PopMember(t::Node, score::T) where {T<:Real}
    PopMember{T}(t, score, getTime())
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
                   options::Options) where {T<:Real}
    PopMember(t, scoreFunc(dataset, baseline, t, options))
end

function copyPopMember(p::PopMember{T}) where {T<:Real}
    tree = copyNode(p.tree)
    score = p.score
    birth = p.birth
    return PopMember{T}(tree, score, birth)
end
