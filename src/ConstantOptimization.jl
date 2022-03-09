using FromFile
import LineSearches
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
    loss = scoreFunc(dataset, baseline, tree, options; allow_diff=allow_diff)[2]
    return loss
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
    f(x::Vector{CONST_TYPE})::T = optFunc(x, dataset, baseline, member.tree, options)
    differentiable_f(x::Vector{CONST_TYPE})::T = optFunc(x, dataset, baseline, member.tree, options; allow_diff=true)
    use_differentiable = false
    if nconst == 1
        algorithm = Optim.Newton(linesearch=LineSearches.BackTracking())
    else
        if options.optimizer_algorithm == "NelderMead"
            algorithm = Optim.NelderMead(linesearch=LineSearches.BackTracking())
        elseif options.optimizer_algorithm == "BFGS"
            use_differentiable = false #true #Not working with autodiff yet TODO
            algorithm = Optim.BFGS(linesearch=LineSearches.BackTracking())#order=3))
        else
            error("Optimization function not implemented.")
        end
    end
    result = if !use_differentiable
        Optim.optimize(f, x0, algorithm, Optim.Options(iterations=options.optimizer_iterations))
    else
         Optim.optimize(differentiable_f, x0, algorithm, Optim.Options(iterations=options.optimizer_iterations))
    end
    # Try other initial conditions:
    for i=1:options.optimizer_nrestarts
        new_start = x0 .* (convert(CONST_TYPE, 1) .+ convert(CONST_TYPE, 1//2)*randn(CONST_TYPE, size(x0, 1)))
        tmpresult = if !use_differentiable
             Optim.optimize(f, new_start, algorithm, Optim.Options(iterations=options.optimizer_iterations))
        else
             Optim.optimize(differentiable_f, new_start, algorithm, Optim.Options(iterations=options.optimizer_iterations))
        end

        if tmpresult.minimum < result.minimum
            result = tmpresult
        end
    end

    if Optim.converged(result)
        setConstants(member.tree, result.minimizer)
        member.score, member.loss = scoreFunc(dataset, baseline, member.tree, options)
        member.birth = getTime()
    else
        setConstants(member.tree, x0)
    end
    return member
end
