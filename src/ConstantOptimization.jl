module ConstantOptimizationModule

using LineSearches: LineSearches
using Optim: Optim
import DynamicExpressions: Node, count_constants
import ..CoreModule: Options, Dataset, DATA_TYPE, LOSS_TYPE
import ..UtilsModule: get_birth_order
import ..LossFunctionsModule: score_func, eval_loss, batch_sample
import ..PopMemberModule: PopMember

# Proxy function for optimization
@inline function opt_func(
    x, dataset::Dataset{T,L}, tree, constant_nodes, options, idx
) where {T<:DATA_TYPE,L<:LOSS_TYPE}
    _set_constants!(x, constant_nodes)
    # TODO(mcranmer): This should use score_func batching.
    loss = eval_loss(tree, dataset, options; regularization=false, idx=idx)
    return loss::L
end

function _set_constants!(x::AbstractArray{T}, constant_nodes) where {T}
    for (xi, node) in zip(x, constant_nodes)
        node.val::T = xi
    end
    return nothing
end

# Use Nelder-Mead to optimize the constants in an equation
function optimize_constants(
    dataset::Dataset{T,L}, member::PopMember{T,L}, options::Options
)::Tuple{PopMember{T,L},Float64} where {T<:DATA_TYPE,L<:LOSS_TYPE}
    if options.batching
        dispatch_optimize_constants(
            dataset, member, options, batch_sample(dataset, options)
        )
    else
        dispatch_optimize_constants(dataset, member, options, nothing)
    end
end
function dispatch_optimize_constants(
    dataset::Dataset{T,L}, member::PopMember{T,L}, options::Options, idx
) where {T<:DATA_TYPE,L<:LOSS_TYPE}
    nconst = count_constants(member.tree)
    nconst == 0 && return (member, 0.0)
    if T <: Complex
        # TODO: Make this more general. Also, do we even need Newton here at all??
        algorithm = Optim.BFGS(; linesearch=LineSearches.BackTracking())#order=3))
        return _optimize_constants(
            dataset, member, options, algorithm, options.optimizer_options, idx
        )
    elseif nconst == 1
        algorithm = Optim.Newton(; linesearch=LineSearches.BackTracking())
        return _optimize_constants(
            dataset, member, options, algorithm, options.optimizer_options, idx
        )
    else
        if options.optimizer_algorithm == "NelderMead"
            algorithm = Optim.NelderMead(; linesearch=LineSearches.BackTracking())
            return _optimize_constants(
                dataset, member, options, algorithm, options.optimizer_options, idx
            )
        elseif options.optimizer_algorithm == "BFGS"
            algorithm = Optim.BFGS(; linesearch=LineSearches.BackTracking())#order=3))
            return _optimize_constants(
                dataset, member, options, algorithm, options.optimizer_options, idx
            )
        else
            error("Optimization function not implemented.")
        end
    end
end

function _optimize_constants(
    dataset, member::PopMember{T,L}, options, algorithm, optimizer_options, idx
)::Tuple{PopMember{T,L},Float64} where {T,L}
    tree = member.tree
    constant_nodes = filter(t -> t.degree == 0 && t.constant, tree)
    x0 = [n.val::T for n in constant_nodes]
    f(x) = opt_func(x, dataset, tree, constant_nodes, options, idx)
    result = Optim.optimize(f, x0, algorithm, optimizer_options)
    num_evals = 0.0
    num_evals += result.f_calls
    # Try other initial conditions:
    for i in 1:(options.optimizer_nrestarts)
        new_start = x0 .* (T(1) .+ T(1//2) * randn(T, size(x0, 1)))
        tmpresult = Optim.optimize(f, new_start, algorithm, optimizer_options)
        num_evals += tmpresult.f_calls

        if tmpresult.minimum < result.minimum
            result = tmpresult
        end
    end

    if Optim.converged(result)
        _set_constants!(result.minimizer, constant_nodes)
        member.score, member.loss = score_func(dataset, member, options)
        num_evals += 1
        member.birth = get_birth_order(; deterministic=options.deterministic)
    else
        _set_constants!(x0, constant_nodes)
    end

    return member, num_evals
end

end
