# Define a member of population by equation, score, and age
mutable struct PopMember{T<:Real}
    tree::Node
    score::T
    birth::Int
end

function PopMember(t::Node, score::T) where {T<:Real}
    PopMember{T}(t, score, getTime())
end

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
