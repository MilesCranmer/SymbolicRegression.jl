module ConstantOptimizationModule

using LineSearches: LineSearches
using Optim: Optim
using DynamicExpressions: Node, count_constants, get_constant_refs
using ..CoreModule: Options, Dataset, DATA_TYPE, LOSS_TYPE
using ..UtilsModule: get_birth_order
using ..LossFunctionsModule: eval_loss, loss_to_score, batch_sample
using ..PopMemberModule: PopMember

function optimize_constants(
    dataset::Dataset{T,L}, member::P, options::Options
)::Tuple{P,Float64} where {T<:DATA_TYPE,L<:LOSS_TYPE,P<:PopMember{T,L}}
    if options.batching
        dispatch_optimize_constants(
            dataset, member, options, batch_sample(dataset, options)
        )
    else
        dispatch_optimize_constants(dataset, member, options, nothing)
    end
end
function dispatch_optimize_constants(
    dataset::Dataset{T,L}, member::P, options::Options, idx
) where {T<:DATA_TYPE,L<:LOSS_TYPE,P<:PopMember{T,L}}
    nconst = count_constants(member.tree)
    nconst == 0 && return (member, 0.0)
    if nconst == 1 && !(T <: Complex)
        algorithm = Optim.Newton(; linesearch=LineSearches.BackTracking())
        return _optimize_constants(
            dataset, member, options, algorithm, options.optimizer_options, idx
        )
    end
    return _optimize_constants(
        dataset,
        member,
        options,
        options.optimizer_algorithm,
        options.optimizer_options,
        idx,
    )
end

function _optimize_constants(
    dataset, member::P, options, algorithm, optimizer_options, idx
)::Tuple{P,Float64} where {T,L,P<:PopMember{T,L}}
    tree = member.tree
    eval_fraction = options.batching ? (options.batch_size / dataset.n) : 1.0
    f(t) = eval_loss(t, dataset, options; regularization=false, idx=idx)::L
    baseline = f(tree)
    result = Optim.optimize(f, tree, algorithm, optimizer_options)
    num_evals = result.f_calls * eval_fraction
    # Try other initial conditions:
    for _ in 1:(options.optimizer_nrestarts)
        tmptree = copy(tree)
        foreach(tmptree) do node
            if node.degree == 0 && node.constant
                node.val = (node.val) * (T(1) + T(1//2) * randn(T))
            end
        end
        tmpresult = Optim.optimize(
            f, tmptree, algorithm, optimizer_options; make_copy=false
        )
        num_evals += tmpresult.f_calls * eval_fraction

        if tmpresult.minimum < result.minimum
            result = tmpresult
        end
    end

    if result.minimum < baseline
        member.tree = result.minimizer
        member.loss = eval_loss(member.tree, dataset, options; regularization=true, idx=idx)
        member.score = loss_to_score(
            member.loss, dataset.use_baseline, dataset.baseline_loss, member, options
        )
        member.birth = get_birth_order(; deterministic=options.deterministic)
        num_evals += eval_fraction
    end

    return member, num_evals
end

end
