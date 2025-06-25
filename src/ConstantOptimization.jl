module ConstantOptimizationModule

using Random: AbstractRNG, default_rng
using LineSearches: LineSearches
using Optim: Optim
using ADTypes: AbstractADType, AutoEnzyme
using DifferentiationInterface: value_and_gradient, prepare_gradient
using DynamicExpressions:
    AbstractExpression,
    Expression,
    count_scalar_constants,
    get_scalar_constants,
    set_scalar_constants!,
    extract_gradient
using DispatchDoctor: @unstable
using ..CoreModule:
    AbstractOptions, Dataset, DATA_TYPE, LOSS_TYPE, specialized_options, dataset_fraction
using ..UtilsModule: get_birth_order, PerTaskCache, stable_get!
using ..LossFunctionsModule: eval_loss, loss_to_cost
using ..PopMemberModule: PopMember

function can_optimize(::AbstractExpression{T}, options) where {T}
    return can_optimize(T, options)
end
function can_optimize(::Type{T}, _) where {T<:Number}
    return true
end

function optimize_constants(
    dataset::Dataset{T,L},
    member::P,
    options::AbstractOptions;
    rng::AbstractRNG=default_rng(),
)::Tuple{P,Float64} where {T<:DATA_TYPE,L<:LOSS_TYPE,P<:PopMember{T,L}}
    can_optimize(member.tree, options) || return (member, 0.0)
    nconst = count_constants_for_optimization(member.tree)
    nconst == 0 && return (member, 0.0)
    if nconst == 1 && !(T <: Complex)
        algorithm = Optim.Newton(; linesearch=LineSearches.BackTracking())
        return _optimize_constants(
            dataset,
            member,
            specialized_options(options),
            algorithm,
            options.optimizer_options,
            rng,
        )
    end
    return _optimize_constants(
        dataset,
        member,
        specialized_options(options),
        # We use specialized options here due to Enzyme being
        # more particular about dynamic dispatch
        options.optimizer_algorithm,
        options.optimizer_options,
        rng,
    )
end

"""How many constants will be optimized."""
count_constants_for_optimization(ex::Expression) = count_scalar_constants(ex)

function _optimize_constants(
    dataset, member::P, options, algorithm, optimizer_options, rng
)::Tuple{P,Float64} where {T,L,P<:PopMember{T,L}}
    tree = member.tree
    x0, refs = get_scalar_constants(tree)
    @assert count_constants_for_optimization(tree) == length(x0)
    ctx = EvaluatorContext(dataset, options)
    f = Evaluator(tree, refs, ctx)
    fg! = GradEvaluator(f, options.autodiff_backend)
    return _optimize_constants_inner(
        f, fg!, x0, refs, dataset, member, options, algorithm, optimizer_options, rng
    )
end
function _optimize_constants_inner(
    f::F, fg!::G, x0, refs, dataset, member::P, options, algorithm, optimizer_options, rng
)::Tuple{P,Float64} where {F,G,T,L,P<:PopMember{T,L}}
    obj = if algorithm isa Optim.Newton || options.autodiff_backend === nothing
        f
    else
        Optim.only_fg!(fg!)
    end
    baseline = f(x0)
    result = Optim.optimize(obj, x0, algorithm, optimizer_options)
    eval_fraction = dataset_fraction(dataset)
    num_evals = result.f_calls * eval_fraction
    # Try other initial conditions:
    for _ in 1:(options.optimizer_nrestarts)
        eps = randn(rng, T, size(x0)...)
        xt = @. x0 * (T(1) + T(1//2) * eps)
        tmpresult = Optim.optimize(obj, xt, algorithm, optimizer_options)
        num_evals += tmpresult.f_calls * eval_fraction
        # TODO: Does this need to take into account h_calls?

        if tmpresult.minimum < result.minimum
            result = tmpresult
        end
    end

    if result.minimum < baseline
        set_scalar_constants!(member.tree, result.minimizer, refs)
        member.loss = f(result.minimizer; regularization=true)
        member.cost = loss_to_cost(
            member.loss, dataset.use_baseline, dataset.baseline_loss, member, options
        )
        member.birth = get_birth_order(; deterministic=options.deterministic)
        num_evals += eval_fraction
    else
        # Reset to original state
        set_scalar_constants!(member.tree, x0, refs)
    end

    return member, num_evals
end

struct EvaluatorContext{D<:Dataset,O<:AbstractOptions} <: Function
    dataset::D
    options::O
end
function (c::EvaluatorContext)(tree; regularization=false)
    return eval_loss(tree, c.dataset, c.options; regularization)
end

struct Evaluator{N<:AbstractExpression,R,C<:EvaluatorContext} <: Function
    tree::N
    refs::R
    ctx::C
end
function (e::Evaluator)(x::AbstractVector; regularization=false)
    set_scalar_constants!(e.tree, x, e.refs)
    return e.ctx(e.tree; regularization)
end

struct GradEvaluator{E<:Evaluator,AD<:Union{Nothing,AbstractADType},PR,EX} <: Function
    e::E
    prep::PR
    backend::AD
    extra::EX
end
@unstable function GradEvaluator(e::Evaluator, backend)
    prep = isnothing(backend) ? nothing : _cached_prep(e.ctx, backend, e.tree)
    return GradEvaluator(e, prep, backend, nothing)
end

const CachedPrep = PerTaskCache{Dict{UInt,Any}}()

@unstable function _cached_prep(ctx, backend, example_tree)
    # We avoid hashing on the tree because it should not affect the prep.
    # We want to cache as much as possible!
    key = hash((ctx, backend))
    stable_get!(CachedPrep[], key) do
        prepare_gradient(ctx, backend, example_tree)
    end
end

function (g::GradEvaluator{<:Any,AD})(_, G, x::AbstractVector) where {AD}
    AD isa AutoEnzyme && error("Please load the `Enzyme.jl` package.")
    set_scalar_constants!(g.e.tree, x, g.e.refs)
    maybe_prep = isnothing(g.prep) ? () : (g.prep,)
    (val, grad) = value_and_gradient(g.e.ctx, maybe_prep..., g.backend, g.e.tree)
    if G !== nothing && grad !== nothing
        G .= extract_gradient(grad, g.e.tree)
    end
    return val
end

end
