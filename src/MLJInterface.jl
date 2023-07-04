module MLJInterfaceModule

using Optim: Optim
import MLJModelInterface as MMI
import DynamicExpressions: eval_tree_array, string_tree, Node
import LossFunctions: SupervisedLoss
import ..CoreModule: Options, Dataset, MutationWeights, LOSS_TYPE
import ..CoreModule.OptionsModule: DEFAULT_OPTIONS, OPTION_DESCRIPTIONS
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
    equation_strings = get_equation_strings_for(
        m, formatted.trees, fitresult.options, fitresult.variable_names
    )
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

MMI.clean!(::AbstractSRRegressor) = ""

# TODO: Enable `verbosity` being passed to `equation_search`
function MMI.fit(m::AbstractSRRegressor, verbosity, X, y, w=nothing)
    return MMI.update(m, verbosity, (; state=nothing), nothing, X, y, w)
end
function MMI.update(
    m::AbstractSRRegressor, verbosity, old_fitresult, old_cache, X, y, w=nothing
)
    options = get(old_fitresult, :options, get_options(m))
    X_t, variable_names = get_matrix_and_colnames(X)
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
    fitresult = (; state=search_state, options=options, variable_names=variable_names)
    return (fitresult, nothing, full_report(m, fitresult))
end
function get_matrix_and_colnames(X)
    sch = MMI.istable(X) ? MMI.schema(X) : nothing
    Xm_t = MMI.matrix(X; transpose=true)
    colnames = if sch === nothing
        [map(i -> "x$(i)", axes(Xm_t, 1))...]
    else
        [string.(sch.names)...]
    end
    return Xm_t, colnames
end

function format_input_for(::SRRegressor, y)
    @assert(
        !(MMI.istable(y) || (length(size(y)) == 2 && size(y, 2) > 1)),
        "For multi-output regression, please use `MultitargetSRRegressor`."
    )
    return vec(y)
end
function format_input_for(::MultitargetSRRegressor, y)
    @assert(
        MMI.istable(y) || (length(size(y)) == 2 && size(y, 2) > 1),
        "For single-output regression, please use `SRRegressor`."
    )
    return MMI.matrix(y; transpose=true)
end

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
    Xnew_t = MMI.matrix(Xnew; transpose=true)
    eq = params.equations[params.best_idx]
    out, flag = eval_tree_array(eq, Xnew_t, fitresult.options)
    !flag && error("Detected a NaN in evaluating expression.")
    return out
end
function MMI.predict(m::MultitargetSRRegressor, fitresult, Xnew)
    params = MMI.fitted_params(m, fitresult)
    Xnew_t = MMI.matrix(Xnew; transpose=true)
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

function get_equation_strings_for(::SRRegressor, trees, options, variable_names)
    return (t -> string_tree(t, options; variable_names=variable_names)).(trees)
end
function get_equation_strings_for(::MultitargetSRRegressor, trees, options, variable_names)
    return [
        (t -> string_tree(t, options; variable_names=variable_names)).(ts) for ts in trees
    ]
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

MMI.metadata_pkg(
    AbstractSRRegressor;
    name="SymbolicRegression",
    uuid="8254be44-1295-4e6a-a16d-46603ac705cb",
    url="https://github.com/MilesCranmer/SymbolicRegression.jl",
    julia=true,
    license="Apache-2.0",
    is_wrapper=false,
)

MMI.metadata_model(
    SRRegressor;
    input_scitype=Union{MMI.Table(MMI.Continuous),AbstractMatrix{<:MMI.Continuous}},
    target_scitype=AbstractVector{<:MMI.Continuous},
    supports_weights=true,
    reports_feature_importances=false,
    load_path="SymbolicRegression.MLJInterfaceModule.SRRegressor",
    descr="Symbolic Regression via Evolutionary Search",
)
MMI.metadata_model(
    MultitargetSRRegressor;
    input_scitype=Union{MMI.Table(MMI.Continuous),AbstractMatrix{<:MMI.Continuous}},
    target_scitype=Union{MMI.Table(MMI.Continuous),AbstractMatrix{<:MMI.Continuous}},
    supports_weights=true,
    reports_feature_importances=false,
    load_path="SymbolicRegression.MLJInterfaceModule.MultitargetSRRegressor",
    descr="Multi-Target Symbolic Regression via Evolutionary Search",
)

function tag_with_docstring(model_name::Symbol, description::String)
    docstring = """$(MMI.doc_header(eval(model_name)))

    # Arguments
    """

    # TODO: These ones are copied (or written) manually:
    append_arguments = """- `niterations::Int=10`: The number of iterations to perform the search.
        More iterations will improve the results.
    - `parallelism=:multithreading`: What parallelism mode to use.
        The options are `:multithreading`, `:multiprocessing`, and `:serial`.
        By default, multithreading will be used. Multithreading uses less memory,
        but multiprocessing can handle multi-node compute. If using `:multithreading`
        mode, the number of threads available to julia are used. If using
        `:multiprocessing`, `numprocs` processes will be created dynamically if
        `procs` is unset. If you have already allocated processes, pass them
        to the `procs` argument and they will be used.
        You may also pass a string instead of a symbol, like `"multithreading"`.
    - `numprocs::Union{Int, Nothing}=nothing`:  The number of processes to use,
        if you want `equation_search` to set this up automatically. By default
        this will be `4`, but can be any number (you should pick a number <=
        the number of cores available).
    - `procs::Union{Vector{Int}, Nothing}=nothing`: If you have set up
        a distributed run manually with `procs = addprocs()` and `@everywhere`,
        pass the `procs` to this keyword argument.
    - `addprocs_function::Union{Function, Nothing}=nothing`: If using multiprocessing
        (`parallelism=:multithreading`), and are not passing `procs` manually,
        then they will be allocated dynamically using `addprocs`. However,
        you may also pass a custom function to use instead of `addprocs`.
        This function should take a single positional argument,
        which is the number of processes to use, as well as the `lazy` keyword argument.
        For example, if set up on a slurm cluster, you could pass
        `addprocs_function = addprocs_slurm`, which will set up slurm processes.
    - `runtests::Bool=true`: Whether to run (quick) tests before starting the
        search, to see if there will be any problems during the equation search
        related to the host environment.
    - `loss_type::Type=Nothing`: If you would like to use a different type
        for the loss than for the data you passed, specify the type here.
        Note that if you pass complex data `::Complex{L}`, then the loss
        type will automatically be set to `L`.
    - `selection_method::Function`: Function to selection expression from
        the Pareto frontier for use in `predict`. See `SymbolicRegression.MLJInterfaceModule.choose_best`
        for an example. This function should return a single integer specifying
        the index of the expression to use. By default, `choose_best` maximizes
        the score (a pound-for-pound rating) of expressions reaching the threshold
        of 1.5x the minimum loss. To fix the index at `5`, you could just write `Returns(5)`.
    """

    # Remove common indentation:
    docstring = replace(docstring, r"^    " => "")
    extra_arguments = replace(append_arguments, r"^    " => "")

    # Add parameter descriptions:
    docstring = docstring * OPTION_DESCRIPTIONS
    docstring = docstring * extra_arguments
    return quote
        @doc $docstring $model_name
    end
end

#! format: off
eval(tag_with_docstring(:SRRegressor, "Symbolic Regression via Evolutionary Search"))
eval(tag_with_docstring(:MultitargetSRRegressor, "Multi-Target Symbolic Regression via Evolutionary Search"))
#! format: on

end
