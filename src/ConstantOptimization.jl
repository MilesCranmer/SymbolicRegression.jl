using Optim

# Proxy function for optimization
function optFunc(x::Vector{ConstantType}, X::AbstractMatrix{T},
                 y::AbstractVector{T}, baseline::T,
                 tree::Node, options::Options)::T where {T<:AbstractFloat}
    setConstants(tree, x)
    return scoreFunc(X, y, baseline, tree, options)
end

# Use Nelder-Mead to optimize the constants in an equation
function optimizeConstants(X::AbstractMatrix{T}, y::AbstractVector{T},
                           baseline::T, member::PopMember,
                           options::Options)::PopMember where {T<:AbstractFloat}

    nconst = countConstants(member.tree)
    if nconst == 0
        return member
    end
    x0 = getConstants(member.tree)
    f(x::Vector{ConstantType})::T = optFunc(x, X, y, baseline, member.tree, options)
    if size(x0)[1] == 1
        algorithm = Newton
    else
        algorithm = NelderMead
    end

    try
        result = optimize(f, x0, algorithm(), Optim.Options(iterations=100))
        # Try other initial conditions:
        for i=1:options.nrestarts
            new_start = x0 .* (convert(ConstantType, 1.0) .+ convert(ConstantType, 0.5)*randn(ConstantType, size(x0)[1]))
            tmpresult = optimize(f, new_start, algorithm(), Optim.Options(iterations=100))

            if tmpresult.minimum < result.minimum
                result = tmpresult
            end
        end

        if Optim.converged(result)
            setConstants(member.tree, result.minimizer)
            member.score = convert(T, result.minimum)
            member.birth = getTime()
        else
            setConstants(member.tree, x0)
        end
    catch error
        # Fine if optimization encountered domain error, just return x0
        if isa(error, AssertionError)
            setConstants(member.tree, x0)
        else
            throw(error)
        end
    end
    return member
end
