# Define a member of population by equation, score, and age
mutable struct PopMember
    tree::Node
    score::Float32
    birth::Integer

    PopMember(t::Node, score::Float32) = new(t, score, getTime())

end


function PopMember(X::Array{Float32, 2}, y::Array{Float32, 1}, baseline::Float32, t::Node, options::Options)
    PopMember(t, scoreFunc(X, y, baseline, t, options))
end

