module ConstantOptimizationModule

using LineSearches: LineSearches
using Optim: Optim
import DynamicExpressions: Node, get_constants, set_constants, count_constants
import ..CoreModule: Options, Dataset
import ..UtilsModule: get_birth_order
import ..LossFunctionsModule: score_func, eval_loss, d_eval_loss
import ..PopMemberModule: PopMember

# Proxy function for optimization
function opt_func(
    x::Vector{T}, dataset::Dataset{T}, tree::Node{T}, options::Options
)::T where {T<:Real}
    set_constants(tree, x)
    # TODO(mcranmer): This should use score_func batching.
    loss = eval_loss(tree, dataset, options)
    return loss
end

function opt_func_with_g(
    x::Vector{T}, dataset::Dataset{T}, tree::Node{T}, options::Options
)::Tuple{T,Vector{T}} where {T<:Real}
    set_constants(tree, x)
    # TODO(mcranmer): This should use score_func batching.
    loss, d_loss_d_constants = d_eval_loss(tree, dataset, options)
    return loss, d_loss_d_constants
end

function load_common_buffer!(
    x::Vector{T},
    last_x::Vector{T},
    buffer::Vector{T},
    dataset::Dataset{T},
    tree::Node{T},
    options::Options,
) where {T<:Real}
    if x != last_x
        copy!(last_x, x)
        loss, d_loss = opt_func_with_g(x, dataset, tree, options)
        buffer[1] = loss
        buffer[2:end] .= d_loss
    end
end

function buffered_opt_func(
    x::Vector{T},
    last_x::Vector{T},
    buffer::Vector{T},
    dataset::Dataset{T},
    tree::Node{T},
    options::Options,
) where {T<:Real}
    load_common_buffer!(x, last_x, buffer, dataset, tree, options)
    return buffer[1]
end

function buffered_d_opt_func!(
    x::Vector{T},
    stor::Vector{T},
    last_x::Vector{T},
    buffer::Vector{T},
    dataset::Dataset{T},
    tree::Node{T},
    options::Options,
) where {T<:Real}
    load_common_buffer!(x, last_x, buffer, dataset, tree, options)
    copyto!(stor, buffer[2:end])
    return nothing
end

# Use Nelder-Mead to optimize the constants in an equation
function optimize_constants(
    dataset::Dataset{T}, member::PopMember{T}, options::Options
)::Tuple{PopMember{T},Float64} where {T<:Real}
    enable_autodiff =
        length(options.operators.diff_binops) > 0 ||
        length(options.operators.diff_unaops) > 0
    nconst = count_constants(member.tree)
    num_evals = 0.0
    if nconst == 0
        return (member, 0.0)
    end
    x0 = get_constants(member.tree)
    if nconst == 1
        algorithm = Optim.Newton(; linesearch=LineSearches.BackTracking())
    else
        if options.optimizer_algorithm == "NelderMead"
            algorithm = Optim.NelderMead(; linesearch=LineSearches.BackTracking())
        elseif options.optimizer_algorithm == "BFGS"
            algorithm = Optim.BFGS(; linesearch=LineSearches.BackTracking())#order=3))
        else
            error("Optimization function $(options.optimizer_algorithm) not implemented.")
        end
    end
    local result
    if !enable_autodiff
        f(x::Vector{T})::T = opt_func(x, dataset, member.tree, options)
        result = Optim.optimize(f, x0, algorithm, options.optimizer_options)
        num_evals += result.f_calls
        # Try other initial conditions:
        for _ in 1:(options.optimizer_nrestarts)
            new_start = x0 .* (T(1) .+ T(1//2) * randn(T, size(x0, 1)))
            tmpresult = Optim.optimize(f, new_start, algorithm, options.optimizer_options)
            num_evals += tmpresult.f_calls

            if tmpresult.minimum < result.minimum
                result = tmpresult
            end
        end
    else
        init_x = copy(x0)
        last_x = similar(init_x)
        buffer = zeros(T, 1 + nconst)
        function buff_f(x::Vector{T})::T
            return buffered_opt_func(x, init_x, buffer, dataset, member.tree, options)
        end
        function buff_g(stor::Vector{T}, x::Vector{T})
            return buffered_d_opt_func!(
                x, stor, last_x, buffer, dataset, member.tree, options
            )
        end
        result = Optim.optimize(buff_f, buff_g, x0, algorithm, options.optimizer_options)
        num_evals += result.f_calls + result.g_calls * nconst

        for _ in 1:(options.optimizer_nrestarts)
            init_x .= x0 .* (T(1) .+ T(1//2) * randn(T, size(x0, 1)))
            tmpresult = Optim.optimize(
                buff_f, buff_g, init_x, algorithm, options.optimizer_options
            )
            num_evals += result.f_calls + result.g_calls * nconst

            if tmpresult.minimum < result.minimum
                result = tmpresult
            end
        end
    end

    if Optim.converged(result)
        set_constants(member.tree, result.minimizer)
        member.score, member.loss = score_func(dataset, member.tree, options)
        num_evals += 1
        member.birth = get_birth_order(; deterministic=options.deterministic)
    else
        set_constants(member.tree, x0)
    end
    return member, num_evals
end

end
