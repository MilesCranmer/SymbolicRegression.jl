module ConstantOptimizationModule

using LineSearches: LineSearches
using Optim: Optim
using DynamicExpressions: Expression, Node, count_constants, get_constants, set_constants!
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
    nconst = count_constants_for_optimization(member.tree)
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
count_constants_for_optimization(ex::Expression) = count_constants(ex)

function _optimize_constants(
    dataset, member::P, options, algorithm, optimizer_options, idx
)::Tuple{P,Float64} where {T,L,P<:PopMember{T,L}}
    tree = member.tree
    eval_fraction = options.batching ? (options.batch_size / dataset.n) : 1.0
    f = Evaluator(dataset, options, idx)
    fg! = GradEvaluator(f)
    obj = if algorithm isa Optim.Newton || options.autodiff_backend isa Val{:finite}
        f
    else
        Optim.only_fg!(fg!)
    end
    baseline = f(tree)
    x0, refs = get_constants(tree)
    result = Optim.optimize(obj, tree, algorithm, optimizer_options)
    num_evals = result.f_calls * eval_fraction
    # Try other initial conditions:
    for _ in 1:(options.optimizer_nrestarts)
        tmptree = copy(tree)
        eps = randn(T, size(x0)...)
        xt = @. x0 * (T(1) + T(1//2) * eps)
        set_constants!(tmptree, xt, refs)
        tmpresult = Optim.optimize(
            obj, tmptree, algorithm, optimizer_options; make_copy=false
        )
        num_evals += tmpresult.f_calls * eval_fraction
        # TODO: Does this need to take into account h_calls?

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

struct Evaluator{D<:Dataset,O<:Options,I} <: Function
    dataset::D
    options::O
    idx::I
end
(e::Evaluator)(t) = eval_loss(t, e.dataset, e.options; regularization=false, idx=e.idx)
struct GradEvaluator{F<:Evaluator} <: Function
    f::F
end
function (g::GradEvaluator)(F, G, t)
    (val, grad) = _withgradient(g.f, t)
    if G !== nothing &&
        grad !== nothing &&
        only(grad) !== nothing &&
        only(grad).tree !== nothing
        G .= only(grad).tree.gradient
    end
    return val
end
_withgradient(args...) = error("Please load the Zygote.jl package.")

end
