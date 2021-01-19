# Define a member of population by equation, score, and age
mutable struct PopMember{T<:AbstractFloat}
    tree::Node
    score::T
    birth::Integer

end

function PopMember(t::Node, score::T) where {T<:AbstractFloat}
    PopMember{T}(t, score, getTime())
end

function PopMember(X::AbstractArray{T, 2}, y::AbstractArray{T, 1},
                   baseline::T, t::Node,
                   options::Options) where {T<:AbstractFloat}
    PopMember(t, scoreFunc(X, y, baseline, t, options))
end

