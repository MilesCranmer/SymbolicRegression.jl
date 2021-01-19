using Optim

# Proxy function for optimization
function optFunc(x::Array{Float32, 1}, X::Array{Float32, 2}, y::Array{Float32, 1}, baseline::Float32, tree::Node, options::Options)::Float32
    setConstants(tree, x)
    return scoreFunc(X, y, baseline, tree, options)
end

# Use Nelder-Mead to optimize the constants in an equation
function optimizeConstants(X::Array{Float32, 2}, y::Array{Float32, 1}, baseline::Float32, member::PopMember, options::Options)::PopMember
    nconst = countConstants(member.tree)
    if nconst == 0
        return member
    end
    x0 = getConstants(member.tree)
    f(x::Array{Float32,1})::Float32 = optFunc(x, X, y, baseline, member.tree, options)
    if size(x0)[1] == 1
        algorithm = Newton
    else
        algorithm = NelderMead
    end

    try
        result = optimize(f, x0, algorithm(), Optim.Options(iterations=100))
        # Try other initial conditions:
        for i=1:options.nrestarts
            tmpresult = optimize(f, x0 .* (1f0 .+ 5f-1*randn(Float32, size(x0)[1])), algorithm(), Optim.Options(iterations=100))
            if tmpresult.minimum < result.minimum
                result = tmpresult
            end
        end

        if Optim.converged(result)
            setConstants(member.tree, result.minimizer)
            member.score = convert(Float32, result.minimum)
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
