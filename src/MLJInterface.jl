module MLJInterfaceModule

using MLJModelInterface: MLJModelInterface
import DynamicExpressions: eval_tree_array, string_tree, Node
import ..CoreModule: Options, Dataset, LOSS_TYPE
import ..ComplexityModule: compute_complexity
import ..HallOfFameModule: HallOfFame, calculate_pareto_frontier, format_hall_of_fame
#! format: off
import ..equation_search
#! format: on

mutable struct SRRegressor <: MLJModelInterface.Deterministic
    sr_options::Options
    niterations::Int
    parallelism::Symbol
    numprocs::Union{Int,Nothing}
    procs::Union{Vector{Int},Nothing}
    addprocs_function::Union{Function,Nothing}
    runtests::Bool
    loss_type::Type
    selection_method::Function
end
# TODO: Ideally we could forward all parameters from `Options`?

function choose_best(; trees, losses::Vector{L}, scores, complexities) where {L<:LOSS_TYPE}
    # Same as in PySR:
    # https://github.com/MilesCranmer/PySR/blob/e74b8ad46b163c799908b3aa4d851cf8457c79ef/pysr/sr.py#L2318-L2332
    # threshold = 1.5 * minimum_loss
    # Then, we get max score of those below the threshold.
    threshold = 1.5 * minimum(losses)
    return argmax([
        (losses[i] <= threshold) ? scores[i] : typemin(L) for i in eachindex(losses)
    ])
end

function dispatch_selection(
    selection_method::F, trees::VN, losses, scores, complexities
) where {F,T,N<:Node{T},VN<:Vector{N}}
    return selection_method(;
        trees=trees, losses=losses, scores=scores, complexities=complexities
    )::Integer
end
function dispatch_selection(
    selection_method::F, trees::MN, losses, scores, complexities
) where {F,T,N<:Node{T},VN<:Vector{N},MN<:Vector{VN}}
    return [
        dispatch_selection(
            selection_method, trees[i], losses[i], scores[i], complexities[i]
        ) for i in eachindex(trees)
    ]
end

# TODO: Should somehow automatically document kws available.
function SRRegressor(;
    niterations::Int=10,
    parallelism::Symbol=:multithreading,
    numprocs::Union{Int,Nothing}=nothing,
    procs::Union{Vector{Int},Nothing}=nothing,
    addprocs_function::Union{Function,Nothing}=nothing,
    runtests::Bool=true,
    loss_type::Type=Nothing,
    selection_method=choose_best,
    kws...,
)
    @assert !haskey(kws, :return_state)
    return SRRegressor(
        Options(; return_state=true, kws...),
        niterations,
        parallelism,
        numprocs,
        procs,
        addprocs_function,
        runtests,
        loss_type,
        selection_method,
    )
end
# Cleaning already taken care of by `Options` and `equation_search`
MLJModelInterface.clean!(::SRRegressor) = ""

# TODO: How to pass `variable_names` and `units`?
# TODO: Enable `verbosity` being passed to `equation_search`
function MLJModelInterface.fit(m::SRRegressor, verbosity, X, y, w=nothing)
    state = equation_search(
        X,
        y;
        niterations=m.niterations,
        weights=w,
        variable_names=nothing,
        options=m.sr_options,
        parallelism=m.parallelism,
        numprocs=m.numprocs,
        procs=m.procs,
        addprocs_function=m.addprocs_function,
        runtests=m.runtests,
        saved_state=nothing,
        loss_type=m.loss_type,
    )
    _, hof = state
    # TODO: Adjust baseline loss
    report = format_hall_of_fame(hof, m.sr_options, 1.0)
    report_with_str = (;
        equation_strings=get_equation_strings(report.trees, m.sr_options),
        losses=report.losses,
        scores=report.scores,
        complexities=report.complexities,
    )
    return (state, nothing, report_with_str)
end
function MLJModelInterface.fitted_params(m::SRRegressor, fitresult)
    _, hof = fitresult
    # TODO: Adjust baseline loss
    formatted = format_hall_of_fame(hof, m.sr_options, 1.0)
    best_idx = dispatch_selection(
        m.selection_method,
        formatted.trees,
        formatted.losses,
        formatted.scores,
        formatted.complexities,
    )
    return (;
        equations=formatted.trees,
        equation_strings=get_equation_strings(formatted.trees, m.sr_options),
        best_idx=best_idx,
    )
end
function MLJModelInterface.predict(m::SRRegressor, fitresult, Xnew)
    params = MLJModelInterface.fitted_params(m, fitresult)
    equations = params.equations
    best_idx = params.best_idx
    if isa(best_idx, Vector)
        outs = [
            let out, flag = eval_tree_array(eq[i], Xnew, m.sr_options)
                !flag && error("Detected a NaN in evaluating expression.")
                out
            end for (i, eq) in zip(best_idx, equations)
        ]
        return reduce(hcat, outs)
    else
        out, flag = eval_tree_array(equations[best_idx], Xnew, m.sr_options)
        !flag && error("Detected a NaN in evaluating expression.")
        return out
    end
end

# TODO: Add `metadata_model`

function get_equation_strings(trees, options)
    if isa(first(trees), Vector)
        return [(t -> string_tree(t, options)).(ts) for ts in trees]
    else
        return (t -> string_tree(t, options)).(trees)
    end
end

end