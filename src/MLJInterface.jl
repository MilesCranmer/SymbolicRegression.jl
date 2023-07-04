module MLJInterfaceModule

using MLJModelInterface: MLJModelInterface
using Optim: Optim
import DynamicExpressions: eval_tree_array, string_tree, Node
import ..CoreModule: Options, Dataset, MutationWeights, LOSS_TYPE
import ..CoreModule.OptionsModule: DEFAULT_OPTIONS
import ..ComplexityModule: compute_complexity
import ..HallOfFameModule: HallOfFame, calculate_pareto_frontier, format_hall_of_fame
#! format: off
import ..equation_search
#! format: on

abstract type AbstractSRRegressor <: MLJModelInterface.Deterministic end

const sr_regressor_template =
    :(Base.@kwdef mutable struct SRRegressor <: AbstractSRRegressor
        niterations::Int = 10
        parallelism::Symbol = :multithreading
        numprocs::Union{Int,Nothing} = nothing
        procs::Union{Vector{Int},Nothing} = nothing
        addprocs_function::Union{Function,Nothing} = nothing
        runtests::Bool = true
        loss_type::Type = Nothing
        selection_method::Function = choose_best
    end)
# TODO: To reduce code re-use, we could forward these defaults from
#       `equation_search`, similar to what we do for `Options`.

"""Generate an `SRRegressor` struct containing all the fields in `Options`."""
function modelexpr()
    struct_def = deepcopy(sr_regressor_template)
    fields = last(last(struct_def.args).args).args

    # Add everything from `Options` constructor directly to struct:
    for (i, option) in enumerate(DEFAULT_OPTIONS)
        insert!(fields, i, Expr(:(=), option.args...))
    end

    # We also need to create the `get_options` function, based on this:
    constructor = :(Options(;))
    constructor_fields = last(constructor.args).args
    for option in DEFAULT_OPTIONS
        symb = getsymb(first(option.args))
        push!(constructor_fields, Expr(:kw, symb, Expr(:(.), :m, Core.QuoteNode(symb))))
    end

    return quote
        $struct_def
        function get_options(m::SRRegressor)
            return $constructor
        end
    end
end
function getsymb(ex::Symbol)
    return ex
end
function getsymb(ex::Expr)
    for arg in ex.args
        isa(arg, Symbol) && return arg
        s = getsymb(arg)
        isa(s, Symbol) && return s
    end
    return nothing
end

"""Get an equivalent `Options()` object for a particular regressor."""
function get_options(::AbstractSRRegressor) end

eval(modelexpr())

# Cleaning already taken care of by `Options` and `equation_search`
function full_report(m::AbstractSRRegressor, fitresult)
    _, hof = fitresult.state
    # TODO: Adjust baseline loss
    formatted = format_hall_of_fame(hof, fitresult.options, 1.0)
    equation_strings = get_equation_strings(formatted.trees, fitresult.options)
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

# TODO: Pass `variable_names` and `units`
# TODO: Enable `verbosity` being passed to `equation_search`
MLJModelInterface.clean!(::AbstractSRRegressor) = ""

function MLJModelInterface.fit(m::AbstractSRRegressor, verbosity, X, y, w=nothing)
    options = get_options(m)
    search_state = equation_search(
        X,
        y;
        niterations=m.niterations,
        weights=w,
        variable_names=nothing,
        options=options,
        parallelism=m.parallelism,
        numprocs=m.numprocs,
        procs=m.procs,
        addprocs_function=m.addprocs_function,
        runtests=m.runtests,
        saved_state=nothing,
        return_state=true,
        loss_type=m.loss_type,
    )
    fitresult = (; state=search_state, options=options)
    return (fitresult, nothing, full_report(m, fitresult))
end
function MLJModelInterface.fitted_params(m::AbstractSRRegressor, fitresult)
    report = full_report(m, fitresult)
    return (;
        best_idx=report.best_idx,
        equations=report.equations,
        equation_strings=report.equation_strings,
    )
end
function MLJModelInterface.predict(m::AbstractSRRegressor, fitresult, Xnew)
    params = MLJModelInterface.fitted_params(m, fitresult)
    equations = params.equations
    best_idx = params.best_idx
    if isa(best_idx, Vector)
        outs = [
            let out, flag = eval_tree_array(eq[i], Xnew, fitresult.options)
                !flag && error("Detected a NaN in evaluating expression.")
                out
            end for (i, eq) in zip(best_idx, equations)
        ]
        return reduce(hcat, outs)
    else
        out, flag = eval_tree_array(equations[best_idx], Xnew, fitresult.options)
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
