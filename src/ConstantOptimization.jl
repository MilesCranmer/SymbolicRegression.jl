module ConstantOptimizationModule

import LineSearches
import Optim
import ..CoreModule: CONST_TYPE, Node, Options, Dataset
import ..UtilsModule: getTime
import ..EquationUtilsModule: getConstants, setConstants, countConstants
import ..LossFunctionsModule: scoreFunc, EvalLoss, dEvalLoss
import ..PopMemberModule: PopMember

# Proxy function for optimization
function optFunc(x::Vector{CONST_TYPE}, dataset::Dataset{T},
                 tree::Node, options::Options)::T where {T<:Real}
    setConstants(tree, x)
    # TODO(mcranmer): This should use scoreFunc batching.
    loss = EvalLoss(tree, dataset, options)
    return loss
end

function doptFunc!(gradient::Vector{CONST_TYPE},
                   x::Vector{CONST_TYPE}, dataset::Dataset{T},
                   tree::Node, options::Options) where {T<:Real}
    setConstants(tree, x)
    # loss = EvalLoss(tree, dataset, options)
    dloss_dconstants = dEvalLoss(tree, dataset, options)
    copyto!(gradient, dloss_dconstants)  # = dloss_dconstants
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

    f(x::Vector{CONST_TYPE})::T = optFunc(x, dataset, member.tree, options)
    df!(gradient::Vector{CONST_TYPE}, x::Vector{CONST_TYPE}) = doptFunc!(gradient, x, dataset, member.tree, options)

    if nconst == 1
        algorithm = Optim.Newton(linesearch=LineSearches.BackTracking())
    else
        if options.optimizer_algorithm == "NelderMead"
            algorithm = Optim.NelderMead(linesearch=LineSearches.BackTracking())
        elseif options.optimizer_algorithm == "BFGS"
            algorithm = Optim.BFGS(linesearch=LineSearches.BackTracking())#order=3))
        else
            error("Optimization function not implemented.")
        end
    end

    get_result(init_x) = if options.enable_autodiff
        Optim.optimize(f, df!, init_x, algorithm, Optim.Options(iterations=options.optimizer_iterations))
    else
        Optim.optimize(f, init_x, algorithm, Optim.Options(iterations=options.optimizer_iterations))
    end

    result = get_result(x0)
    # Try other initial conditions:
    for i=1:options.optimizer_nrestarts
        new_start = x0 .* (convert(CONST_TYPE, 1) .+ convert(CONST_TYPE, 1//2)*randn(CONST_TYPE, size(x0, 1)))
        tmpresult = get_result(new_start)

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

end
