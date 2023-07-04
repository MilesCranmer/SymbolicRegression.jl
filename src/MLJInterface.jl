module MLJInterfaceModule

using Optim: Optim
import MLJModelInterface as MMI
import DynamicExpressions: eval_tree_array, string_tree, Node
import LossFunctions: SupervisedLoss
import ..CoreModule: Options, Dataset, MutationWeights, LOSS_TYPE
import ..CoreModule.OptionsModule: DEFAULT_OPTIONS
import ..ComplexityModule: compute_complexity
import ..HallOfFameModule: HallOfFame, calculate_pareto_frontier, format_hall_of_fame
#! format: off
import ..equation_search
#! format: on

abstract type AbstractSRRegressor <: MMI.Deterministic end

# TODO: To reduce code re-use, we could forward these defaults from
#       `equation_search`, similar to what we do for `Options`.

"""Generate an `SRRegressor` struct containing all the fields in `Options`."""
function modelexpr(model_name::Symbol)
    struct_def = :(Base.@kwdef mutable struct $(model_name) <: AbstractSRRegressor
        niterations::Int = 10
        parallelism::Symbol = :multithreading
        numprocs::Union{Int,Nothing} = nothing
        procs::Union{Vector{Int},Nothing} = nothing
        addprocs_function::Union{Function,Nothing} = nothing
        runtests::Bool = true
        loss_type::Type = Nothing
        selection_method::Function = choose_best
    end)
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
        function get_options(m::$(model_name))
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

eval(modelexpr(:SRRegressor))
eval(modelexpr(:MultitargetSRRegressor))

# Cleaning already taken care of by `Options` and `equation_search`
function full_report(m::AbstractSRRegressor, fitresult)
    _, hof = fitresult.state
    # TODO: Adjust baseline loss
    formatted = format_hall_of_fame(hof, fitresult.options, 1.0)
    equation_strings = get_equation_strings_for(m, formatted.trees, fitresult.options)
    best_idx = dispatch_selection_for(
        m, formatted.trees, formatted.losses, formatted.scores, formatted.complexities
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
MMI.clean!(::AbstractSRRegressor) = ""

function MMI.fit(m::AbstractSRRegressor, verbosity, X, y, w=nothing)
    return _update(m, verbosity, (; state=nothing), nothing, X, y, w)
end
function MMI.update(
    m::AbstractSRRegressor, verbosity, old_fitresult, old_cache, X, y, w=nothing
)
    return _update(m, verbosity, old_fitresult, old_cache, X, y, w)
end
function _update(m::AbstractSRRegressor, verbosity, old_fitresult, old_cache, X, y, w)
    options = get(old_fitresult, :options, get_options(m))
    mX = MMI.matrix(X)
    variable_names = getcolnames(X)
    X_t = permutedims(mX)
    y_t = format_input_for(m, y)
    search_state = equation_search(
        X_t,
        y_t;
        niterations=m.niterations,
        weights=w,
        variable_names=variable_names,
        options=options,
        parallelism=m.parallelism,
        numprocs=m.numprocs,
        procs=m.procs,
        addprocs_function=m.addprocs_function,
        runtests=m.runtests,
        saved_state=old_fitresult.state,
        return_state=true,
        loss_type=m.loss_type,
    )
    fitresult = (; state=search_state, options=options)
    return (fitresult, nothing, full_report(m, fitresult))
end

function getcolnames(X)
    try
        return getcolnames(MMI.schema(X), X)
    catch e
        isa(e, ArgumentError) || rethrow(e)
    end
    try
        return getcolnames(MMI.schema(MMI.table(X)), X)
    catch e
        isa(e, MethodError) || isa(e, ArgumentError) || rethrow(e)
    end
    return getcolnames(nothing, X)
end
getcolnames(::Nothing, X) = [map(i -> "x$(i)", axes(X, 2))...]
getcolnames(sch, _) = [string.(sch.names)...]

format_input_for(::SRRegressor, y) = (@assert ndims(y) == 1; y)
format_input_for(::MultitargetSRRegressor, y) = MMI.matrix(y, transpose=true)
function MMI.fitted_params(m::AbstractSRRegressor, fitresult)
    report = full_report(m, fitresult)
    return (;
        best_idx=report.best_idx,
        equations=report.equations,
        equation_strings=report.equation_strings,
    )
end
function MMI.predict(m::SRRegressor, fitresult, Xnew)
    params = MMI.fitted_params(m, fitresult)
    Xnew_t = transpose(MMI.matrix(Xnew))
    eq = params.equations[params.best_idx]
    out, flag = eval_tree_array(eq, Xnew_t, fitresult.options)
    !flag && error("Detected a NaN in evaluating expression.")
    return out
end
function MMI.predict(m::MultitargetSRRegressor, fitresult, Xnew)
    params = MMI.fitted_params(m, fitresult)
    Xnew_t = transpose(MMI.matrix(Xnew))
    equations = params.equations
    best_idx = params.best_idx
    outs = [
        let (out, flag) = eval_tree_array(eq[i], Xnew_t, fitresult.options)
            !flag && error("Detected a NaN in evaluating expression.")
            out
        end for (i, eq) in zip(best_idx, equations)
    ]
    return reduce(hcat, outs)
end

#! format: off
MMI.package_name(::Type{<:AbstractSRRegressor}) = "SymbolicRegression"
MMI.package_uuid(::Type{<:AbstractSRRegressor}) = "8254be44-1295-4e6a-a16d-46603ac705cb"
MMI.package_url(::Type{<:AbstractSRRegressor}) = "https://github.com/MilesCranmer/SymbolicRegression.jl"
MMI.package_license(::Type{<:AbstractSRRegressor}) = "Apache-2.0"
MMI.is_pure_julia(::Type{<:AbstractSRRegressor}) = true
MMI.is_wrapper(::Type{<:AbstractSRRegressor}) = false

MMI.input_scitype(::Type{<:AbstractSRRegressor}) = MMI.Table(MMI.Continuous)
MMI.supports_weights(::Type{<:AbstractSRRegressor}) = true
MMI.reports_feature_importances(::Type{<:AbstractSRRegressor}) = false

MMI.target_scitype(::Type{SRRegressor}) = AbstractVector{<:MMI.Continuous}
MMI.load_path(::Type{SRRegressor}) = "SymbolicRegression.MLJInterfaceModule.SRRegressor"
MMI.human_name(::Type{SRRegressor}) = "Symbolic Regression via Evolutionary Search"

MMI.target_scitype(::Type{MultitargetSRRegressor}) = MMI.Table(MMI.Continuous)
MMI.load_path(::Type{MultitargetSRRegressor}) = "SymbolicRegression.MLJInterfaceModule.MultitargetSRRegressor"
MMI.human_name(::Type{MultitargetSRRegressor}) = "Multi-Target Symbolic Regression via Evolutionary Search"
#! format: on

function get_equation_strings_for(::SRRegressor, trees, options)
    return (t -> string_tree(t, options)).(trees)
end
function get_equation_strings_for(::MultitargetSRRegressor, trees, options)
    return [(t -> string_tree(t, options)).(ts) for ts in trees]
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

function dispatch_selection_for(m::SRRegressor, trees, losses, scores, complexities)
    return m.selection_method(;
        trees=trees, losses=losses, scores=scores, complexities=complexities
    )::Integer
end
function dispatch_selection_for(
    m::MultitargetSRRegressor, trees, losses, scores, complexities
)
    return [
        m.selection_method(;
            trees=trees[i], losses=losses[i], scores=scores[i], complexities=complexities[i]
        )::Integer for i in eachindex(trees)
    ]
end

end
