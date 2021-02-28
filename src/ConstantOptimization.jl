using FromFile
import Optim
@from "Core.jl" import CONST_TYPE, Node, Options, Dataset
@from "Utils.jl" import getTime
@from "EquationUtils.jl" import getConstants, setConstants, countConstants
@from "LossFunctions.jl" import scoreFunc
@from "PopMember.jl" import PopMember

# Proxy function for optimization
function optFunc(x::Vector{CONST_TYPE}, dataset::Dataset{T}, baseline::T,
                 tree::Node, options::Options; allow_diff=false)::T where {T<:Real}
    setConstants(tree, x)
    return scoreFunc(dataset, baseline, tree, options; allow_diff=allow_diff)
end

# Use Nelder-Mead to optimize the constants in an equation
function optimizeConstants(dataset::Dataset{T},
                           baseline::T, member::PopMember,
                           options::Options)::PopMember where {T<:Real}

    nconst = countConstants(member.tree)
    if nconst == 0
        return member
    end
    x0 = getConstants(member.tree)
    if nconst == 1
        algorithm = Optim.Newton
    else
        if options.constant_optimizer == "NelderMead"
            algorithm = Optim.NelderMead
            f(x::Vector{CONST_TYPE})::T = optFunc(x, dataset, baseline, member.tree, options; allow_diff=false)
        elseif options.constant_optimizer == "BFGS"
            algorithm = Optim.BFGS
            f(x::Vector{CONST_TYPE})::T = optFunc(x, dataset, baseline, member.tree, options; allow_diff=true)
        else
            error("Optimization function not implemented.")
        end
    end

    result = Optim.optimize(f, x0, algorithm(), Optim.Options(iterations=100))
    # Try other initial conditions:
    for i=1:options.nrestarts
        new_start = x0 .* (convert(CONST_TYPE, 1) .+ convert(CONST_TYPE, 1//2)*randn(CONST_TYPE, size(x0, 1)))
        tmpresult = Optim.optimize(f, new_start, algorithm(), Optim.Options(iterations=100))

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
    return member
end
