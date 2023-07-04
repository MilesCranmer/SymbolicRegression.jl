module MLJInterfaceModule

using MLJModelInterface: MLJModelInterface
import DynamicExpressions: eval_tree_array, string_tree, Node
import ..CoreModule: Options, Dataset, LOSS_TYPE
import ..ComplexityModule: compute_complexity
import ..HallOfFameModule: HallOfFame, calculate_pareto_frontier, format_hall_of_fame
#! format: off
import ..equation_search
#! format: on

# TODO: Think about automatically putting all Option parameters into this struct.
MLJModelInterface.@mlj_model mutable struct SRRegressor <: MLJModelInterface.Deterministic
    sr_options::Options = Options()
    niterations::Int = 10::(_ >= 0)
    parallelism::Symbol =
        :multithreading::(_ in (:multithreading, :multiprocessing, :serial))
    numprocs::Union{Int,Nothing} = nothing::(_ === nothing || _ >= 0)
    procs::Union{Vector{Int},Nothing} = nothing
    addprocs_function::Union{Function,Nothing} = nothing
    runtests::Bool = true
    loss_type::Type = Nothing
    selection_method::Function = choose_best
end

function full_report(m::SRRegressor, fitresult)
    _, hof = fitresult
    # TODO: Adjust baseline loss
    formatted = format_hall_of_fame(hof, m.sr_options, 1.0)
    equation_strings = get_equation_strings(formatted.trees, m.sr_options)
    best_idx = dispatch_selection(
        m.selection_method,
        formatted.trees,
        formatted.losses,
        formatted.scores,
        formatted.complexities,
    )
    return (;
        best_idx=best_idx,
        equations=formatted.trees,
        equation_strings=equation_strings,
        losses=formatted.losses,
        complexities=formatted.complexities,
        scores=formatted.scores,
    )
end

# TODO: How to pass `variable_names` and `units`?
# TODO: Enable `verbosity` being passed to `equation_search`
function MLJModelInterface.fit(m::SRRegressor, verbosity, X, y, w=nothing)
    fitresult = equation_search(
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
        return_state=true,
        loss_type=m.loss_type,
    )
    return (fitresult, nothing, full_report(m, fitresult))
end
function MLJModelInterface.fitted_params(m::SRRegressor, fitresult)
    # _, hof = fitresult
    # # TODO: Adjust baseline loss
    # formatted = format_hall_of_fame(hof, m.sr_options, 1.0)
    report = full_report(m, fitresult)
    return (;
        best_idx=report.best_idx,
        equations=report.equations,
        equation_strings=report.equation_strings,
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

end
