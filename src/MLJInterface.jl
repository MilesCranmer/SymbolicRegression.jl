module MLJInterfaceModule

using Optim: Optim
import MLJModelInterface as MMI
import DynamicExpressions: eval_tree_array, string_tree, Node
import DynamicQuantities:
    AbstractQuantity,
    AbstractDimensions,
    SymbolicDimensions,
    Quantity,
    DEFAULT_DIM_BASE_TYPE,
    ustrip,
    dimension
import LossFunctions: SupervisedLoss
import Compat: allequal, stack
import ..InterfaceDynamicQuantitiesModule: get_dimensions_type
import ..CoreModule: Options, Dataset, MutationWeights, LOSS_TYPE
import ..CoreModule.OptionsModule: DEFAULT_OPTIONS, OPTION_DESCRIPTIONS
import ..ComplexityModule: compute_complexity
import ..HallOfFameModule: HallOfFame, format_hall_of_fame
import ..UtilsModule: subscriptify
#! format: off
import ..equation_search
#! format: on

abstract type AbstractSRRegressor <: MMI.Deterministic end

# TODO: To reduce code re-use, we could forward these defaults from
#       `equation_search`, similar to what we do for `Options`.

"""Generate an `SRRegressor` struct containing all the fields in `Options`."""
function modelexpr(model_name::Symbol)
    struct_def =
        :(Base.@kwdef mutable struct $(model_name){D<:AbstractDimensions,L,use_recorder} <:
                                     AbstractSRRegressor
            niterations::Int = 10
            parallelism::Symbol = :multithreading
            numprocs::Union{Int,Nothing} = nothing
            procs::Union{Vector{Int},Nothing} = nothing
            addprocs_function::Union{Function,Nothing} = nothing
            runtests::Bool = true
            loss_type::L = Nothing
            selection_method::Function = choose_best
            dimensions_type::Type{D} = SymbolicDimensions{DEFAULT_DIM_BASE_TYPE}
        end)
    # TODO: store `procs` from initial run if parallelism is `:multiprocessing`
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
function full_report(
    m::AbstractSRRegressor, fitresult; v_with_strings::Val{with_strings}=Val(true)
) where {with_strings}
    _, hof = fitresult.state
    # TODO: Adjust baseline loss
    formatted = format_hall_of_fame(hof, fitresult.options)
    equation_strings = if with_strings
        get_equation_strings_for(
            m, formatted.trees, fitresult.options, fitresult.variable_names
        )
    else
        nothing
    end
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
    return MMI.update(m, verbosity, nothing, nothing, X, y, w)
end
function MMI.update(
    m::AbstractSRRegressor, verbosity, old_fitresult, old_cache, X, y, w=nothing
)
    options = old_fitresult === nothing ? get_options(m) : old_fitresult.options
    return _update(m, verbosity, old_fitresult, old_cache, X, y, w, options)
end
function _update(m, verbosity, old_fitresult, old_cache, X, y, w, options)
    # To speed up iterative fits, we cache the types:
    types = if old_fitresult === nothing
        (;
            T=Any,
            X_t=Any,
            y_t=Any,
            w_t=Any,
            state=Any,
            X_units=Any,
            y_units=Any,
            X_units_clean=Any,
            y_units_clean=Any,
        )
    else
        old_fitresult.types
    end
    X_t::types.X_t, variable_names, X_units::types.X_units = get_matrix_and_info(
        X, m.dimensions_type
    )
    y_t::types.y_t, y_variable_names, y_units::types.y_units = format_input_for(
        m, y, m.dimensions_type
    )
    X_units_clean::types.X_units_clean = clean_units(X_units)
    y_units_clean::types.y_units_clean = clean_units(y_units)
    w_t::types.w_t = if w !== nothing && isa(m, MultitargetSRRegressor)
        @assert(isa(w, AbstractVector) && ndims(w) == 1, "Unexpected input for `w`.")
        repeat(w', size(y_t, 1))
    else
        w
    end
    search_state::types.state = equation_search(
        X_t,
        y_t;
        niterations=m.niterations,
        weights=w_t,
        variable_names=variable_names,
        options=options,
        parallelism=m.parallelism,
        numprocs=m.numprocs,
        procs=m.procs,
        addprocs_function=m.addprocs_function,
        runtests=m.runtests,
        saved_state=(old_fitresult === nothing ? nothing : old_fitresult.state),
        return_state=true,
        loss_type=m.loss_type,
        X_units=X_units_clean,
        y_units=y_units_clean,
        verbosity=verbosity,
        # Help out with inference:
        v_dim_out=isa(m, SRRegressor) ? Val(1) : Val(2),
    )
    fitresult = (;
        state=search_state,
        num_targets=isa(m, SRRegressor) ? 1 : size(y_t, 1),
        options=options,
        variable_names=variable_names,
        y_variable_names=y_variable_names,
        y_is_table=MMI.istable(y),
        X_units=X_units_clean,
        y_units=y_units_clean,
        types=(
            T=hof_eltype(search_state[2]),
            X_t=typeof(X_t),
            y_t=typeof(y_t),
            w_t=typeof(w_t),
            state=typeof(search_state),
            X_units=typeof(X_units),
            y_units=typeof(y_units),
            X_units_clean=typeof(X_units_clean),
            y_units_clean=typeof(y_units_clean),
        ),
    )::(old_fitresult === nothing ? Any : typeof(old_fitresult))
    return (fitresult, nothing, full_report(m, fitresult))
end
hof_eltype(::Type{H}) where {T,H<:HallOfFame{T}} = T
hof_eltype(::Type{V}) where {V<:Vector} = hof_eltype(eltype(V))
hof_eltype(h) = hof_eltype(typeof(h))

function clean_units(units)
    !isa(units, AbstractDimensions) && error("Unexpected units.")
    iszero(units) && return nothing
    return units
end
function clean_units(units::Vector)
    !all(Base.Fix2(isa, AbstractDimensions), units) && error("Unexpected units.")
    all(iszero, units) && return nothing
    return units
end

function get_matrix_and_info(X, ::Type{D}) where {D}
    sch = MMI.istable(X) ? MMI.schema(X) : nothing
    Xm_t = MMI.matrix(X; transpose=true)
    colnames = if sch === nothing
        [map(i -> "x$(subscriptify(i))", axes(Xm_t, 1))...]
    else
        [string.(sch.names)...]
    end
    D_promoted = get_dimensions_type(Xm_t, D)
    Xm_t_strip, X_units = unwrap_units_single(Xm_t, D_promoted)
    return Xm_t_strip, colnames, X_units
end

function format_input_for(::SRRegressor, y, ::Type{D}) where {D}
    @assert(
        !(MMI.istable(y) || (length(size(y)) == 2 && size(y, 2) > 1)),
        "For multi-output regression, please use `MultitargetSRRegressor`."
    )
    y_t = vec(y)
    colnames = nothing
    D_promoted = get_dimensions_type(y_t, D)
    y_t_strip, y_units = unwrap_units_single(y_t, D_promoted)
    return y_t_strip, colnames, y_units
end
function format_input_for(::MultitargetSRRegressor, y, ::Type{D}) where {D}
    @assert(
        MMI.istable(y) || (length(size(y)) == 2 && size(y, 2) > 1),
        "For single-output regression, please use `SRRegressor`."
    )
    return get_matrix_and_info(y, D)
end
function validate_variable_names(variable_names, fitresult)
    @assert(
        variable_names == fitresult.variable_names,
        "Variable names do not match fitted regressor."
    )
    return nothing
end
function validate_units(X_units, old_X_units)
    @assert(
        all(X_units .== old_X_units),
        "Units of new data do not match units of fitted regressor."
    )
    return nothing
end

# TODO: Test whether this conversion poses any issues in data normalization...
function dimension_fallback(
    q::Union{<:Quantity{T,<:AbstractDimensions}}, ::Type{D}
) where {T,D}
    return dimension(convert(Quantity{T,D}, q))::D
end
dimension_fallback(_, ::Type{D}) where {D} = D()
function prediction_warn()
    @warn "Evaluation failed either due to NaNs detected or due to unfinished search. Using 0s for prediction."
end

@inline function wrap_units(v, y_units, i::Integer)
    if y_units === nothing
        return v
    else
        return (yi -> Quantity(yi, y_units[i])).(v)
    end
end
@inline function wrap_units(v, y_units, ::Nothing)
    if y_units === nothing
        return v
    else
        return (yi -> Quantity(yi, y_units)).(v)
    end
end

function prediction_fallback(::Type{T}, m::SRRegressor, Xnew_t, fitresult) where {T}
    prediction_warn()
    out = fill!(similar(Xnew_t, T, axes(Xnew_t, 2)), zero(T))
    return wrap_units(out, fitresult.y_units, nothing)
end
function prediction_fallback(
    ::Type{T}, ::MultitargetSRRegressor, Xnew_t, fitresult, prototype
) where {T}
    prediction_warn()
    out_cols = [
        wrap_units(
            fill!(similar(Xnew_t, T, axes(Xnew_t, 2)), zero(T)), fitresult.y_units, i
        ) for i in 1:(fitresult.num_targets)
    ]
    out_matrix = reduce(hcat, out_cols)
    if !fitresult.y_is_table
        return out_matrix
    else
        return MMI.table(out_matrix; names=fitresult.y_variable_names, prototype=prototype)
    end
end

function unwrap_units_single(A::AbstractMatrix{T}, ::Type{D}) where {D,T<:Number}
    return A, [D() for _ in eachrow(A)]
end
function unwrap_units_single(A::AbstractMatrix, ::Type{D}) where {D}
    for (i, row) in enumerate(eachrow(A))
        allequal(Base.Fix2(dimension_fallback, D).(row)) ||
            error("Inconsistent units in feature $i of matrix.")
    end
    dims = map(Base.Fix2(dimension_fallback, D) ∘ first, eachrow(A))
    return stack([ustrip.(row) for row in eachrow(A)]; dims=1), dims
end
function unwrap_units_single(v::AbstractVector{T}, ::Type{D}) where {D,T<:Number}
    return v, D()
end
function unwrap_units_single(v::AbstractVector, ::Type{D}) where {D}
    allequal(Base.Fix2(dimension_fallback, D).(v)) || error("Inconsistent units in vector.")
    dims = dimension_fallback(first(v), D)
    v = ustrip.(v)
    return v, dims
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
    params = full_report(m, fitresult; v_with_strings=Val(false))
    Xnew_t, variable_names, X_units = get_matrix_and_info(Xnew, m.dimensions_type)
    T = promote_type(eltype(Xnew_t), fitresult.types.T)
    if length(params.equations) == 0
        return prediction_fallback(T, m, Xnew_t, fitresult)
    end
    X_units_clean = clean_units(X_units)
    validate_variable_names(variable_names, fitresult)
    validate_units(X_units_clean, fitresult.X_units)
    eq = params.equations[params.best_idx]
    out, completed = eval_tree_array(eq, Xnew_t, fitresult.options)
    if !completed
        return prediction_fallback(T, m, Xnew_t, fitresult)
    else
        return wrap_units(out, fitresult.y_units, nothing)
    end
end
function MMI.predict(m::MultitargetSRRegressor, fitresult, Xnew)
    params = full_report(m, fitresult; v_with_strings=Val(false))
    prototype = MMI.istable(Xnew) ? Xnew : nothing
    Xnew_t, variable_names, X_units = get_matrix_and_info(Xnew, m.dimensions_type)
    T = promote_type(eltype(Xnew_t), fitresult.types.T)
    X_units_clean = clean_units(X_units)
    validate_variable_names(variable_names, fitresult)
    validate_units(X_units_clean, fitresult.X_units)
    equations = params.equations
    if any(t -> length(t) == 0, equations)
        return prediction_fallback(T, m, Xnew_t, fitresult, prototype)
    end
    best_idx = params.best_idx
    outs = []
    for (i, (best_i, eq)) in enumerate(zip(best_idx, equations))
        out, completed = eval_tree_array(eq[best_i], Xnew_t, fitresult.options)
        if !completed
            return prediction_fallback(T, m, Xnew_t, fitresult, prototype)
        end
        push!(outs, wrap_units(out, fitresult.y_units, i))
    end
    out_matrix = reduce(hcat, outs)
    if !fitresult.y_is_table
        return out_matrix
    else
        return MMI.table(out_matrix; names=fitresult.y_variable_names, prototype=prototype)
    end
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

function dispatch_selection_for(m::SRRegressor, trees, losses, scores, complexities)::Int
    length(trees) == 0 && return 0
    return m.selection_method(;
        trees=trees, losses=losses, scores=scores, complexities=complexities
    )
end
function dispatch_selection_for(
    m::MultitargetSRRegressor, trees, losses, scores, complexities
)
    any(t -> length(t) == 0, trees) && return fill(0, length(trees))
    return [
        m.selection_method(;
            trees=trees[i], losses=losses[i], scores=scores[i], complexities=complexities[i]
        ) for i in eachindex(trees)
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

# TODO: Allow for Count data, and coerce it into Continuous as needed.
MMI.metadata_model(
    SRRegressor;
    input_scitype=Union{MMI.Table(MMI.Continuous),AbstractMatrix{<:MMI.Continuous}},
    target_scitype=AbstractVector{<:MMI.Continuous},
    supports_weights=true,
    reports_feature_importances=false,
    load_path="SymbolicRegression.MLJInterfaceModule.SRRegressor",
    human_name="Symbolic Regression via Evolutionary Search",
)
MMI.metadata_model(
    MultitargetSRRegressor;
    input_scitype=Union{MMI.Table(MMI.Continuous),AbstractMatrix{<:MMI.Continuous}},
    target_scitype=Union{MMI.Table(MMI.Continuous),AbstractMatrix{<:MMI.Continuous}},
    supports_weights=true,
    reports_feature_importances=false,
    load_path="SymbolicRegression.MLJInterfaceModule.MultitargetSRRegressor",
    human_name="Multi-Target Symbolic Regression via Evolutionary Search",
)

function tag_with_docstring(model_name::Symbol, description::String, bottom_matter::String)
    docstring = """$(MMI.doc_header(eval(model_name)))

    $(description)

    # Hyper-parameters
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
    - `dimensions_type::AbstractDimensions`: The type of dimensions to use when storing
        the units of the data. By default this is `DynamicQuantities.SymbolicDimensions`.
    """

    bottom = """
    # Operations

    - `predict(mach, Xnew)`: Return predictions of the target given features `Xnew`, which
      should have same scitype as `X` above. The expression used for prediction is defined
      by the `selection_method` function, which can be seen by viewing `report(mach).best_idx`.

    $(bottom_matter)
    """

    # Remove common indentation:
    docstring = replace(docstring, r"^    " => "")
    extra_arguments = replace(append_arguments, r"^    " => "")
    bottom = replace(bottom, r"^    " => "")

    # Add parameter descriptions:
    docstring = docstring * OPTION_DESCRIPTIONS
    docstring = docstring * extra_arguments
    docstring = docstring * bottom
    return quote
        @doc $docstring $model_name
    end
end

#https://arxiv.org/abs/2305.01582
eval(
    tag_with_docstring(
        :SRRegressor,
        replace(
            """
    Single-target Symbolic Regression regressor (`SRRegressor`) searches
    for symbolic expressions that predict a single target variable from
    a set of input variables. All data is assumed to be `Continuous`.
    The search is performed using an evolutionary algorithm.
    This algorithm is described in the paper
    https://arxiv.org/abs/2305.01582.

    # Training data

    In MLJ or MLJBase, bind an instance `model` to data with

        mach = machine(model, X, y)

    OR

        mach = machine(model, X, y, w)

    Here:

    - `X` is any table of input features (eg, a `DataFrame`) whose columns are of scitype
      `Continuous`; check column scitypes with `schema(X)`. Variable names in discovered
      expressions will be taken from the column names of `X`, if available. Units in columns
      of `X` (use `DynamicQuantities` for units) will trigger dimensional analysis to be used.

    - `y` is the target, which can be any `AbstractVector` whose element scitype is
        `Continuous`; check the scitype with `scitype(y)`. Units in `y` (use `DynamicQuantities`
        for units) will trigger dimensional analysis to be used.

    - `w` is the observation weights which can either be `nothing` (default) or an 
      `AbstractVector` whoose element scitype is `Count` or `Continuous`.

    Train the machine using `fit!(mach)`, inspect the discovered expressions with
    `report(mach)`, and predict on new data with `predict(mach, Xnew)`.
    Note that unlike other regressors, symbolic regression stores a list of
    trained models. The model chosen from this list is defined by the function
    `selection_method` keyword argument, which by default balances accuracy
    and complexity.

    """,
            r"^    " => "",
        ),
        replace(
            """
    # Fitted parameters

    The fields of `fitted_params(mach)` are:

    - `best_idx::Int`: The index of the best expression in the Pareto frontier,
       as determined by the `selection_method` function.
    - `equations::Vector{Node{T}}`: The expressions discovered by the search, represented
      in a dominating Pareto frontier (i.e., the best expressions found for
      each complexity). `T` is equal to the element type
      of the passed data.
    - `equation_strings::Vector{String}`: The expressions discovered by the search,
      represented as strings for easy inspection.

    # Report

    The fields of `report(mach)` are:

    - `best_idx::Int`: The index of the best expression in the Pareto frontier,
       as determined by the `selection_method` function.
    - `equations::Vector{Node{T}}`: The expressions discovered by the search, represented
      in a dominating Pareto frontier (i.e., the best expressions found for
      each complexity).
    - `equation_strings::Vector{String}`: The expressions discovered by the search,
      represented as strings for easy inspection.
    - `complexities::Vector{Int}`: The complexity of each expression in the Pareto frontier.
    - `losses::Vector{L}`: The loss of each expression in the Pareto frontier, according
      to the loss function specified in the model. The type `L` is the loss type, which
      is usually the same as the element type of data passed (i.e., `T`), but can differ
      if complex data types are passed.
    - `scores::Vector{L}`: A metric which considers both the complexity and loss of an expression,
      equal to the change in the log-loss divided by the change in complexity, relative to
      the previous expression along the Pareto frontier. A larger score aims to indicate
      an expression is more likely to be the true expression generating the data, but
      this is very problem-dependent and generally several other factors should be considered.

    # Examples

    ```julia
    using MLJ
    SRRegressor = @load SRRegressor pkg=SymbolicRegression
    X, y = @load_boston
    model = SRRegressor(binary_operators=[+, -, *], unary_operators=[exp], niterations=100)
    mach = machine(model, X, y)
    fit!(mach)
    y_hat = predict(mach, X)
    # View the equation used:
    r = report(mach)
    println("Equation used:", r.equation_strings[r.best_idx])
    ```

    With units and variable names:

    ```julia
    using MLJ
    using DynamicQuantities
    SRegressor = @load SRRegressor pkg=SymbolicRegression

    X = (; x1=rand(32) .* us"km/h", x2=rand(32) .* us"km")
    y = @. X.x2 / X.x1 + 0.5us"h"
    model = SRRegressor(binary_operators=[+, -, *, /])
    mach = machine(model, X, y)
    fit!(mach)
    y_hat = predict(mach, X)
    # View the equation used:
    r = report(mach)
    println("Equation used:", r.equation_strings[r.best_idx])
    ```

    See also [`MultitargetSRRegressor`](@ref).
    """,
            r"^    " => "",
        ),
    ),
)
eval(
    tag_with_docstring(
        :MultitargetSRRegressor,
        replace(
            """
    Multi-target Symbolic Regression regressor (`MultitargetSRRegressor`)
    conducts several searches for expressions that predict each target variable
    from a set of input variables. All data is assumed to be `Continuous`.
    The search is performed using an evolutionary algorithm.
    This algorithm is described in the paper
    https://arxiv.org/abs/2305.01582.

    # Training data
    In MLJ or MLJBase, bind an instance `model` to data with

        mach = machine(model, X, y)

    OR

        mach = machine(model, X, y, w)

    Here:

    - `X` is any table of input features (eg, a `DataFrame`) whose columns are of scitype
    `Continuous`; check column scitypes with `schema(X)`. Variable names in discovered
    expressions will be taken from the column names of `X`, if available. Units in columns
    of `X` (use `DynamicQuantities` for units) will trigger dimensional analysis to be used.

    - `y` is the target, which can be any table of target variables whose element
      scitype is `Continuous`; check the scitype with `schema(y)`. Units in columns of
      `y` (use `DynamicQuantities` for units) will trigger dimensional analysis to be used.

    - `w` is the observation weights which can either be `nothing` (default) or an 
      `AbstractVector` whoose element scitype is `Count` or `Continuous`. The same
      weights are used for all targets.

    Train the machine using `fit!(mach)`, inspect the discovered expressions with
    `report(mach)`, and predict on new data with `predict(mach, Xnew)`.
    Note that unlike other regressors, symbolic regression stores a list of lists of
    trained models. The models chosen from each of these lists is defined by the function
    `selection_method` keyword argument, which by default balances accuracy
    and complexity.

    """,
            r"^    " => "",
        ),
        replace(
            """
    # Fitted parameters

    The fields of `fitted_params(mach)` are:

    - `best_idx::Vector{Int}`: The index of the best expression in each Pareto frontier,
      as determined by the `selection_method` function.
    - `equations::Vector{Vector{Node{T}}}`: The expressions discovered by the search, represented
      in a dominating Pareto frontier (i.e., the best expressions found for
      each complexity). The outer vector is indexed by target variable, and the inner
      vector is ordered by increasing complexity. `T` is equal to the element type
      of the passed data.
    - `equation_strings::Vector{Vector{String}}`: The expressions discovered by the search,
      represented as strings for easy inspection.

    # Report

    The fields of `report(mach)` are:

    - `best_idx::Vector{Int}`: The index of the best expression in each Pareto frontier,
       as determined by the `selection_method` function.
    - `equations::Vector{Vector{Node{T}}}`: The expressions discovered by the search, represented
      in a dominating Pareto frontier (i.e., the best expressions found for
      each complexity). The outer vector is indexed by target variable, and the inner
      vector is ordered by increasing complexity.
    - `equation_strings::Vector{Vector{String}}`: The expressions discovered by the search,
      represented as strings for easy inspection.
    - `complexities::Vector{Vector{Int}}`: The complexity of each expression in each Pareto frontier.
    - `losses::Vector{Vector{L}}`: The loss of each expression in each Pareto frontier, according
      to the loss function specified in the model. The type `L` is the loss type, which
      is usually the same as the element type of data passed (i.e., `T`), but can differ
      if complex data types are passed.
    - `scores::Vector{Vector{L}}`: A metric which considers both the complexity and loss of an expression,
      equal to the change in the log-loss divided by the change in complexity, relative to
      the previous expression along the Pareto frontier. A larger score aims to indicate
      an expression is more likely to be the true expression generating the data, but
      this is very problem-dependent and generally several other factors should be considered.

    # Examples

    ```julia
    using MLJ
    MultitargetSRRegressor = @load MultitargetSRRegressor pkg=SymbolicRegression
    X = (a=rand(100), b=rand(100), c=rand(100))
    Y = (y1=(@. cos(X.c) * 2.1 - 0.9), y2=(@. X.a * X.b + X.c))
    model = MultitargetSRRegressor(binary_operators=[+, -, *], unary_operators=[exp], niterations=100)
    mach = machine(model, X, Y)
    fit!(mach)
    y_hat = predict(mach, X)
    # View the equations used:
    r = report(mach)
    for (output_index, (eq, i)) in enumerate(zip(r.equation_strings, r.best_idx))
        println("Equation used for ", output_index, ": ", eq[i])
    end
    ```

    See also [`SRRegressor`](@ref).
    """,
            r"^    " => "",
        ),
    ),
)

end
