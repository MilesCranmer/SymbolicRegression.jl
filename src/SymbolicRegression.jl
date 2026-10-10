module SymbolicRegression

# Types
export Population,
    PopMember,
    HallOfFame,
    Options,
    OperatorEnum,
    Dataset,
    MutationWeights,
    AbstractMutation,
    ConstantMutation,
    OperatorMutation,
    FeatureMutation,
    SwapOperandsMutation,
    AddNodeMutation,
    InsertNodeMutation,
    DeleteNodeMutation,
    FormConnectionMutation,
    BreakConnectionMutation,
    RotateTreeMutation,
    BacksolveMutation,
    SimplifyMutation,
    RandomizeMutation,
    OptimizeMutation,
    DoNothingMutation,
    AbstractCrossover,
    SubtreeCrossover,
    AdaptiveParsimonyPlugin,
    AdaptiveMutationWeightsPlugin,
    MutationBurstPlugin,
    SimulatedAnnealingPlugin,
    Node,
    GraphNode,
    Expression,
    ExpressionSpec,
    TemplateExpression,
    TemplateStructure,
    TemplateExpressionSpec,
    @template_spec,
    ValidVector,
    ComposableExpression,
    NodeSampler,
    AbstractExpression,
    AbstractExpressionNode,
    AbstractExpressionSpec,
    EvalContext,
    EvalOptions,
    SRRegressor,
    MultitargetSRRegressor,
    SRLogger,
    ExternalStop,

    #Functions:
    equation_search,
    s_r_cycle,
    calculate_pareto_frontier,
    count_nodes,
    compute_complexity,
    @parse_expression,
    parse_expression,
    @declare_expression_operator,
    print_tree,
    string_tree,
    eval_tree_array,
    eval_diff_tree_array,
    eval_grad_tree_array,
    differentiable_eval_tree_array,
    set_node!,
    copy_node,
    node_to_symbolic,
    symbolic_to_node,
    simplify_tree!,
    tree_mapreduce,
    combine_operators,
    gen_random_tree,
    gen_random_tree_fixed_size,
    @extend_operators,
    get_tree,
    get_contents,
    get_metadata,
    with_contents,
    with_metadata,
    default_mutations,
    plugin_mutations,
    plugin_crossovers,

    #Operators
    plus,
    sub,
    mult,
    square,
    cube,
    pow,
    safe_pow,
    safe_log,
    safe_log2,
    safe_log10,
    safe_log1p,
    safe_asin,
    safe_acos,
    safe_acosh,
    safe_atanh,
    safe_sqrt,
    neg,
    greater,
    cond,
    relu,
    logical_or,
    logical_and,

    # special operators
    gamma,
    erf,
    erfc,
    atanh_clip

using Distributed
using Printf: @printf, @sprintf
using Pkg: Pkg
using TOML: parsefile
using Random: seed!, shuffle!
using Reexport
using ProgressMeter: finish!
using DynamicExpressions:
    Node,
    GraphNode,
    Expression,
    NodeSampler,
    AbstractExpression,
    AbstractExpressionNode,
    ExpressionInterface,
    OperatorEnum,
    GenericOperatorEnum,
    @parse_expression,
    parse_expression,
    @declare_expression_operator,
    copy_node,
    set_node!,
    string_tree,
    print_tree,
    count_nodes,
    get_constants,
    get_scalar_constants,
    set_constants!,
    set_scalar_constants!,
    index_constants,
    NodeIndex,
    eval_tree_array,
    EvalContext,
    differentiable_eval_tree_array,
    eval_diff_tree_array,
    eval_grad_tree_array,
    node_to_symbolic,
    symbolic_to_node,
    combine_operators,
    simplify_tree!,
    tree_mapreduce,
    set_default_variable_names!,
    node_type,
    get_tree,
    get_contents,
    get_metadata,
    with_contents,
    with_metadata
using DynamicExpressions: with_type_parameters
@reexport using LossFunctions:
    MarginLoss,
    DistanceLoss,
    SupervisedLoss,
    ZeroOneLoss,
    LogitMarginLoss,
    PerceptronLoss,
    HingeLoss,
    L1HingeLoss,
    L2HingeLoss,
    SmoothedL1HingeLoss,
    ModifiedHuberLoss,
    L2MarginLoss,
    ExpLoss,
    SigmoidLoss,
    DWDMarginLoss,
    LPDistLoss,
    L1DistLoss,
    L2DistLoss,
    PeriodicLoss,
    HuberLoss,
    EpsilonInsLoss,
    L1EpsilonInsLoss,
    L2EpsilonInsLoss,
    LogitDistLoss,
    QuantileLoss,
    LogCoshLoss
using DynamicDiff: D
using Compat: @compat, Fix

#! format: off
@compat(
    public,
    (
        AbstractOptions, AbstractRuntimeOptions, RuntimeOptions,
        mutate!, condition_mutation_weights!, crossover, CrossoverResult,
        sample_mutation, MutationResult, AbstractPopMember, AbstractSearchState, SearchState,
        LOSS_TYPE, DATA_TYPE, node_type,
        AbstractComposableExpression,
        optimize_constants, get_constants_for_optimization,
        set_constants_for_optimization!, extract_gradient_for_optimization,
        get_optimizable_parameters,
        set_optimizable_parameters!, extract_optimizable_gradient,
        AbstractPlugin, MutationEvent,
        init_plugin_state,
        on_search_start!, on_search_end!,
        on_generation_end!, on_cycle_end!, on_mutation_end!, init_member,
        fork_plugin_state,
    )
)
#! format: on
# ^ We can add new functions here based on requests from users.
# However, I don't want to add many functions without knowing what
# users will actually want to overload.

# https://discourse.julialang.org/t/how-to-find-out-the-version-of-a-package-from-its-module/37755/15
const PACKAGE_VERSION = try
    root = pkgdir(@__MODULE__)
    if root == String
        let project = parsefile(joinpath(root, "Project.toml"))
            VersionNumber(project["version"])
        end
    else
        VersionNumber(0, 0, 0)
    end
catch
    VersionNumber(0, 0, 0)
end

using DispatchDoctor: @stable, @unstable

@stable default_mode = "disable" begin
    include("Utils.jl")
    include("InterfaceDynamicQuantities.jl")
    include("Core.jl")
    include("InterfaceDynamicExpressions.jl")
    include("Complexity.jl")
    include("DimensionalAnalysis.jl")
    include("CheckConstraints.jl")
    include("InverseFunctions.jl")
    include("EvaluateInverse.jl")
    include("Backsolve.jl")
    include("MutationFunctions.jl")
    include("LossFunctions.jl")
    include("PopMember.jl")
    include("ConstantOptimization.jl")
    include("Population.jl")
    include("HallOfFame.jl")
    include("Tracing.jl")
    include("ExpressionBuilder.jl")
    include("Mutate.jl")
    include("Crossover.jl")
    include("RegularizedEvolution.jl")
    include("SingleIteration.jl")
    include("ProgressBars.jl")
    include("Migration.jl")
    include("SearchUtils.jl")
    include("Logging.jl")
    include("ComposableExpression.jl")
    include("TemplateExpression.jl")
    include("TemplateExpressionMacro.jl")
    include("plugins/AdaptiveParsimony.jl")
    include("plugins/AdaptiveMutationWeights.jl")
    include("plugins/MutationBurst.jl")
    include("plugins/SimulatedAnnealing.jl")

    __dispatch_doctor_unsable_test() = Val(rand(1:10))
end

using .CoreModule:
    DATA_TYPE,
    LOSS_TYPE,
    TraceType,
    Dataset,
    BasicDataset,
    use_batching,
    SubDataset,
    AbstractOptions,
    Options,
    ComplexityMapping,
    WarmStartIncompatibleError,
    MutationWeights,
    AbstractMutation,
    ConstantMutation,
    OperatorMutation,
    FeatureMutation,
    SwapOperandsMutation,
    AddNodeMutation,
    InsertNodeMutation,
    DeleteNodeMutation,
    FormConnectionMutation,
    BreakConnectionMutation,
    RotateTreeMutation,
    BacksolveMutation,
    SimplifyMutation,
    RandomizeMutation,
    OptimizeMutation,
    DoNothingMutation,
    default_mutations,
    AbstractCrossover,
    SubtreeCrossover,
    default_crossovers,
    AbstractExpressionSpec,
    ExpressionSpec,
    init_value,
    parse_scope,
    sample_value,
    mutate_value,
    get_safe_op,
    max_features,
    is_weighted,
    sample_mutation,
    batch,
    plus,
    sub,
    mult,
    square,
    cube,
    pow,
    safe_pow,
    safe_log,
    safe_log2,
    safe_log10,
    safe_log1p,
    safe_sqrt,
    safe_asin,
    safe_acos,
    safe_acosh,
    safe_atanh,
    neg,
    greater,
    less,
    greater_equal,
    less_equal,
    cond,
    relu,
    logical_or,
    logical_and,
    gamma,
    erf,
    erfc,
    atanh_clip,
    create_expression,
    has_units,
    AbstractPlugin,
    MutationEvent,
    init_plugin_state,
    init_plugin_states,
    on_search_start!,
    on_search_end!,
    on_generation_end!,
    on_cycle_end!,
    on_mutation_end!,
    init_member,
    resolve_init_member,
    tournament_cost_multiplier,
    mutation_acceptance_multiplier,
    MutationAcceptanceContext,
    fork_plugin_state,
    refresh_worker_plugin_state,
    MutationStepResult,
    wrap_mutation_step,
    on_cycle_start!,
    prepare_mutation_context,
    condition_mutation!,
    plugin_mutations,
    plugin_crossovers,
    ConstantMutationContext
using .UtilsModule: is_anonymous_function, strictmap, @ignore
using .ComplexityModule: compute_complexity
using .CheckConstraintsModule: check_constraints
using .MutationFunctionsModule:
    gen_random_tree, gen_random_tree_fixed_size, random_node, crossover_trees
using .InterfaceDynamicExpressionsModule:
    @extend_operators, require_copy_to_workers, make_example_inputs
using .LossFunctionsModule: eval_loss, eval_cost, update_baseline_loss!, score_func
using .ConstantOptimizationModule:
    optimize_constants,
    get_constants_for_optimization,
    set_constants_for_optimization!,
    extract_gradient_for_optimization,
    get_optimizable_parameters,
    set_optimizable_parameters!,
    extract_optimizable_gradient
using .PopMemberModule:
    AbstractPopMember, PopMember, reset_birth!, popmember_type, expression_type
using .CoreModule.UtilsModule: get_birth_order
using .PopulationModule: Population, best_sub_pop, best_of_sample
using .HallOfFameModule:
    HallOfFame,
    calculate_pareto_frontier,
    string_dominating_pareto_curve,
    update_hall_of_fame!
using .MutateModule: mutate!, condition_mutation_weights!, MutationResult
using .CrossoverModule: crossover, CrossoverResult
using .SingleIterationModule: s_r_cycle, optimize_and_simplify_population
using .ProgressBarsModule: WrappedProgressBar
using .TracingModule:
    initialize_trace!, new_trace, next_trace_iteration, trace_iteration_start!, write_trace
using .MigrationModule: migrate!
using .SearchUtilsModule:
    AbstractSearchState,
    SearchState,
    AbstractRuntimeOptions,
    RuntimeOptions,
    ExternalStop,
    WorkerAssignments,
    DefaultWorkerOutputType,
    assign_next_worker!,
    get_worker_output_type,
    worker_result_type,
    store_on_workers,
    delete_on_workers,
    extract_from_worker,
    @sr_spawner,
    @filtered_async,
    StdinReader,
    watch_stream,
    close_reader!,
    check_for_user_quit,
    check_for_loss_threshold,
    check_for_timeout,
    check_max_evals,
    check_external_stop,
    latch_external_stop!,
    drain_external_stop!,
    ResourceMonitor,
    record_channel_state!,
    estimate_work_fraction,
    update_progress_bar!,
    print_search_state,
    load_saved_hall_of_fame,
    load_saved_population,
    construct_datasets,
    save_to_file,
    FrontierSaveState,
    save_frontier_if_changed!,
    get_cur_maxsize,
    init_dummy_pops,
    parse_guesses,
    logging_callback!,
    infer_popmember_type
using .LoggingModule: AbstractSRLogger, SRLogger, get_logger
using .TemplateExpressionModule:
    TemplateExpression, TemplateStructure, TemplateExpressionSpec, ParamVector, has_params
using .TemplateExpressionModule: ValidVector, TemplateReturnError
using .ComposableExpressionModule:
    AbstractComposableExpression,
    ComposableExpression,
    ValidVectorMixError,
    ValidVectorAccessError
using .ExpressionBuilderModule: embed_metadata, strip_metadata
using .TemplateExpressionMacroModule: @template_spec
using .AdaptiveParsimonyModule: AdaptiveParsimonyPlugin
using .AdaptiveMutationWeightsModule: AdaptiveMutationWeightsPlugin
using .MutationBurstModule: MutationBurstPlugin
using .SimulatedAnnealingModule: SimulatedAnnealingPlugin

@stable default_mode = "disable" begin
    include("deprecates.jl")
    include("Configure.jl")
end

"""
    equation_search(X, y[; kws...])

Perform a distributed equation search for functions `f_i` which
describe the mapping `f_i(X[:, j]) ≈ y[i, j]`. Options are
configured using SymbolicRegression.Options(...),
which should be passed as a keyword argument to options.
One can turn off parallelism with `numprocs=0`,
which is useful for debugging and profiling.

# Arguments
- `X::AbstractMatrix{T}`:  The input dataset to predict `y` from.
    The first dimension is features, the second dimension is rows.
- `y::Union{AbstractMatrix{T}, AbstractVector{T}}`: The values to predict. The first dimension
    is the output feature to predict with each equation, and the
    second dimension is rows.
- `niterations::Int=100`: The number of iterations to perform the search.
    More iterations will improve the results.
- `weights::Union{AbstractMatrix, AbstractVector, Nothing}=nothing`: Optionally
    weight the loss for each `y` by this value (same shape as `y`). Will be
    converted to the same element type as `X`/`y` if it isn't already
    (e.g. real weights are automatically promoted to complex if `X`/`y` are
    complex-valued).
- `options::AbstractOptions=Options()`: The options for the search, such as
    which operators to use, evolution hyperparameters, etc.
- `variable_names::Union{Vector{String}, Nothing}=nothing`: The names
    of each feature in `X`, which will be used during printing of equations.
- `display_variable_names::Union{Vector{String}, Nothing}=variable_names`: Names
    to use when printing expressions during the search, but not when saving
    to an equation file.
- `y_variable_names::Union{String,AbstractVector{String},Nothing}=nothing`: The
    names of each output feature in `y`, which will be used during printing
    of equations.
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
    (`parallelism=:multiprocessing`), and are not passing `procs` manually,
    then they will be allocated dynamically using `addprocs`. However,
    you may also pass a custom function to use instead of `addprocs`.
    This function should take a single positional argument,
    which is the number of processes to use, as well as the `lazy` keyword argument.
    For example, if set up on a slurm cluster, you could pass
    `addprocs_function = addprocs_slurm`, which will set up slurm processes.
- `heap_size_hint_in_bytes::Union{Int,Nothing}=nothing`: On Julia 1.9+, you may set the `--heap-size-hint`
    flag on Julia processes, recommending garbage collection once a process
    is close to the recommended size. This is important for long-running distributed
    jobs where each process has an independent memory, and can help avoid
    out-of-memory errors. By default, this is set to `Sys.free_memory() / numprocs`.
- `worker_timeout::Union{Real,Nothing}=nothing`: Timeout in seconds for worker processes
    to establish connection with the master process. If `JULIA_WORKER_TIMEOUT` is already set,
    that value is used. Otherwise defaults to `max(60, numprocs^2)`.
- `worker_imports::Union{Vector{Symbol},Nothing}=nothing`: If you want to import
    additional modules on each worker, pass them here as a vector of symbols.
    By default some of the extensions will automatically be loaded when needed.
- `runtests::Bool=true`: Whether to run (quick) tests before starting the
    search, to see if there will be any problems during the equation search
    related to the host environment.
- `saved_state=nothing`: If you have already
    run `equation_search` and want to resume it, pass the state here.
    To get this to work, you need to have set return_state=true,
    which will cause `equation_search` to return the state. The second
    element of the state is the regular return value with the hall of fame.
    Note that you cannot change the operators or dataset, but most other options
    should be changeable.
- `return_state::Union{Bool, Nothing}=nothing`: Whether to return the
    state of the search for warm starts. By default this is false.
- `run_id::Union{String,Nothing}=nothing`: A unique identifier for the run.
    This will be used to store outputs from the run in the `outputs` directory.
    If not specified, a unique ID will be generated.
- `loss_type::Type=Nothing`: If you would like to use a different type
    for the loss than for the data you passed, specify the type here.
    Note that if you pass complex data `::Complex{L}`, then the loss
    type will automatically be set to `L`.
- `verbosity`: Whether to print debugging statements or not.
- `logger::Union{AbstractSRLogger,Nothing}=nothing`: An optional logger to record
    the progress of the search. You can use an `SRLogger` to wrap a custom logger,
    or pass `nothing` to disable logging.
- `progress`: Whether to use a progress bar output. Only available for
    single target output.
- `X_units::Union{AbstractVector,Nothing}=nothing`: The units of the dataset,
    to be used for dimensional constraints. For example, if `X_units=["kg", "m"]`,
    then the first feature will have units of kilograms, and the second will
    have units of meters.
- `y_units=nothing`: The units of the output, to be used for dimensional constraints.
    If `y` is a matrix, then this can be a vector of units, in which case
    each element corresponds to each output feature.
- `extra::NamedTuple=NamedTuple()`: Extra information to pass to a custom
    evaluation function. Since this is an arbitrary named tuple, you could pass
    any sort of dataset you wish to here.
- `guesses::Union{AbstractVector,AbstractVector{<:AbstractVector},Nothing}=nothing`: Initial
    guess equations to seed the search. Examples:
    - Single output: `["x1^2 + x2", "sin(x1) * x2"]`
    - Multi-output: `[["x1 + x2"], ["x1 * x2", "x1 - x2"]]`
    Constants will be automatically optimized.

# Returns
- `hallOfFame::HallOfFame`: The best equations seen during the search.
    hallOfFame.members gives an array of `PopMember` objects, which
    have their tree (equation) stored in `.tree`. Their loss
    is given in `.loss`. The array of `PopMember` objects
    is enumerated by size from `1` to `options.maxsize`.
"""
function equation_search(
    X::AbstractMatrix{T},
    y::AbstractMatrix;
    niterations::Int=100,
    weights::Union{AbstractMatrix,AbstractVector,Nothing}=nothing,
    options::AbstractOptions=Options(),
    variable_names::Union{AbstractVector{String},Nothing}=nothing,
    display_variable_names::Union{AbstractVector{String},Nothing}=variable_names,
    y_variable_names::Union{String,AbstractVector{String},Nothing}=nothing,
    parallelism=:multithreading,
    numprocs::Union{Int,Nothing}=nothing,
    procs::Union{Vector{Int},Nothing}=nothing,
    addprocs_function::Union{Function,Nothing}=nothing,
    heap_size_hint_in_bytes::Union{Integer,Nothing}=nothing,
    worker_timeout::Union{Real,Nothing}=nothing,
    worker_imports::Union{Vector{Symbol},Nothing}=nothing,
    runtests::Bool=true,
    saved_state=nothing,
    return_state::Union{Bool,Nothing,Val}=nothing,
    run_id::Union{String,Nothing}=nothing,
    loss_type::Type{L}=Nothing,
    verbosity::Union{Integer,Nothing}=nothing,
    logger::Union{AbstractSRLogger,Nothing}=nothing,
    progress::Union{Bool,Nothing}=nothing,
    X_units::Union{AbstractVector,Nothing}=nothing,
    y_units=nothing,
    extra::NamedTuple=NamedTuple(),
    guesses::Union{AbstractVector,AbstractVector{<:AbstractVector},Nothing}=nothing,
    external_stop=nothing,
    v_dim_out::Val{DIM_OUT}=Val(nothing),
    # Deprecated:
    multithreaded=nothing,
) where {T<:DATA_TYPE,L,DIM_OUT}
    if multithreaded !== nothing
        error(
            "`multithreaded` is deprecated. Use the `parallelism` argument instead. " *
            "Choose one of :multithreaded, :multiprocessing, or :serial.",
        )
    end

    if weights !== nothing
        @assert length(weights) == length(y)
        weights = reshape(weights, size(y))
        if eltype(weights) !== T
            weights = T.(weights)
        end
    end

    datasets = construct_datasets(
        X,
        y,
        weights,
        variable_names,
        display_variable_names,
        y_variable_names,
        X_units,
        y_units,
        extra,
        L,
    )

    return equation_search(
        datasets;
        niterations=niterations,
        options=options,
        parallelism=parallelism,
        numprocs=numprocs,
        procs=procs,
        addprocs_function=addprocs_function,
        heap_size_hint_in_bytes=heap_size_hint_in_bytes,
        worker_timeout=worker_timeout,
        worker_imports=worker_imports,
        runtests=runtests,
        saved_state=saved_state,
        return_state=return_state,
        run_id=run_id,
        verbosity=verbosity,
        logger=logger,
        progress=progress,
        guesses=guesses,
        external_stop=external_stop,
        v_dim_out=Val(DIM_OUT),
    )
end

function equation_search(
    X::AbstractMatrix{T}, y::AbstractVector; kw...
) where {T<:DATA_TYPE}
    return equation_search(X, reshape(y, (1, size(y, 1))); kw..., v_dim_out=Val(1))
end

function equation_search(dataset::Dataset; kws...)
    return equation_search([dataset]; kws..., v_dim_out=Val(1))
end

function equation_search(
    datasets::Vector{D};
    options::AbstractOptions=Options(),
    saved_state=nothing,
    guesses::Union{AbstractVector,AbstractVector{<:AbstractVector},Nothing}=nothing,
    runtime_options::Union{AbstractRuntimeOptions,Nothing}=nothing,
    runtime_options_kws...,
) where {T<:DATA_TYPE,L<:LOSS_TYPE,D<:Dataset{T,L}}
    _runtime_options = @something(
        runtime_options,
        RuntimeOptions(;
            options_return_state=options.return_state,
            options_verbosity=options.verbosity,
            options_progress=options.progress,
            nout=length(datasets),
            runtime_options_kws...,
        )
    )

    # Underscores here mean that we have mutated the variable
    return _equation_search(datasets, _runtime_options, options, saved_state, guesses)
end

@noinline function _equation_search(
    datasets::Vector{D},
    ropt::AbstractRuntimeOptions,
    options::AbstractOptions,
    saved_state,
    guesses,
) where {D<:Dataset}
    latch_external_stop!(ropt)
    _validate_options(datasets, ropt, options)
    state = _create_workers(datasets, ropt, options)
    _initialize_search!(state, datasets, ropt, options, saved_state, guesses)
    _warmup_search!(state, datasets, ropt, options)
    _main_search_loop!(state, datasets, ropt, options)
    _tear_down!(state, datasets, ropt, options)
    _info_dump(state, datasets, ropt, options)
    return _format_output(state, datasets, ropt, options)
end

function _validate_options(
    datasets::Vector{D}, ropt::AbstractRuntimeOptions, options::AbstractOptions
) where {T,L,D<:Dataset{T,L}}
    example_dataset = first(datasets)
    nout = length(datasets)
    @assert nout >= 1
    @assert (nout == 1 || ropt.dim_out == 2)
    @assert options.populations >= 1
    if ropt.progress
        @assert(nout == 1, "You cannot display a progress bar for multi-output searches.")
        @assert(ropt.verbosity > 0, "You cannot display a progress bar with `verbosity=0`.")
    end
    if options.node_type <: GraphNode && ropt.verbosity > 0
        @warn "The `GraphNode` interface and mutation operators are experimental and will change in future versions."
    end
    if ropt.runtests
        test_option_configuration(ropt.parallelism, datasets, options, ropt.verbosity)
        test_dataset_configuration(example_dataset, options, ropt.verbosity)
    end
    for dataset in datasets
        update_baseline_loss!(dataset, options)
    end
    if options.define_helper_functions
        set_default_variable_names!(first(datasets).variable_names)
    end
    if options.seed !== nothing
        seed!(options.seed)
    end
    return nothing
end
@stable default_mode = "disable" function _create_workers(
    datasets::Vector{D}, ropt::AbstractRuntimeOptions, options::AbstractOptions
) where {T,L,D<:Dataset{T,L}}
    stdin_reader = watch_stream(options.input_stream)
    example_dataset = first(datasets)
    trace = new_trace(options)
    initialize_trace!(trace, options, options.tracing_file)

    nout = length(datasets)
    PMType = infer_popmember_type(T, L, example_dataset, options)
    NT = expression_type(PMType)
    PopType = Population{T,L,NT,PMType}
    HallOfFameType = HallOfFame{T,L,NT,PMType}
    plugin_states = [init_plugin_states(options, datasets[j]) for j in 1:nout]
    for j in eachindex(datasets, plugin_states)
        strictmap(options.plugins, plugin_states[j]) do plugin, pstate
            on_search_start!(pstate, plugin, datasets[j], options, ropt)
            return nothing
        end
    end
    PluginStatesType = eltype(plugin_states)
    worker_plugin_state_prototype = strictmap(
        (plugin, head_state) -> fork_plugin_state(head_state, plugin, first(datasets)),
        options.plugins,
        first(plugin_states),
    )
    WorkerPluginStatesType = typeof(worker_plugin_state_prototype)
    worker_plugin_states = [
        WorkerPluginStatesType[
            if j == 1 && i == 1
                worker_plugin_state_prototype
            else
                strictmap(
                    (plugin, head_state) ->
                        fork_plugin_state(head_state, plugin, datasets[j]),
                    options.plugins,
                    plugin_states[j],
                )::WorkerPluginStatesType
            end for i in 1:(options.populations)
        ] for j in 1:nout
    ]
    WorkerOutputType = get_worker_output_type(
        Val(ropt.parallelism),
        PopType,
        HallOfFameType,
        typeof(trace),
        WorkerPluginStatesType,
    )

    # Pointers to populations on each worker:
    worker_output = Vector{WorkerOutputType}[WorkerOutputType[] for j in 1:nout]
    # Initialize storage for workers
    tasks = [Task[] for j in 1:nout]
    # Set up a channel to send finished populations back to head node
    channels = [[Channel(1) for i in 1:(options.populations)] for j in 1:nout]
    (procs, we_created_procs) = if ropt.parallelism == :multiprocessing
        configure_workers(;
            procs=ropt.init_procs,
            ropt.numprocs,
            ropt.addprocs_function,
            ropt.worker_timeout,
            options,
            worker_imports=ropt.worker_imports,
            project_path=splitdir(Pkg.project().path)[1],
            file=@__FILE__,
            ropt.exeflags,
            ropt.verbosity,
            example_dataset,
            ropt.runtests,
            test_head_plugin_states=first(plugin_states),
            test_worker_plugin_states=first(first(worker_plugin_states)),
        )
    else
        Int[], false
    end
    worker_inputs = if ropt.parallelism == :multiprocessing
        store_on_workers((datasets, options), procs)
    else
        nothing
    end
    # Get the next worker process to give a job:
    worker_assignment = WorkerAssignments()
    # Randomly order which order to check populations:
    # This is done so that we do work on all nout equally.
    task_order = [(j, i) for j in 1:nout for i in 1:(options.populations)]
    shuffle!(task_order)

    # Persistent storage of last-saved population for final return:
    last_pops = init_dummy_pops(options.populations, datasets, options)
    # Best 10 members from each population for migration:
    best_sub_pops = init_dummy_pops(options.populations, datasets, options)
    # Records the number of evaluations:
    # Real numbers indicate use of batching.
    num_evals = [[0.0 for i in 1:(options.populations)] for j in 1:nout]

    halls_of_fame = Vector{HallOfFameType}(undef, nout)

    total_cycles = ropt.niterations * options.populations
    cycles_remaining = [total_cycles for j in 1:nout]
    cur_maxsizes = [
        get_cur_maxsize(; options, total_cycles, cycles_remaining=cycles_remaining[j]) for
        j in 1:nout
    ]

    seed_members = [Vector{PMType}() for j in 1:nout]

    return SearchState{
        T,
        L,
        NT,
        PMType,
        WorkerOutputType,
        typeof(trace),
        PluginStatesType,
        WorkerPluginStatesType,
        typeof(worker_inputs),
    }(;
        procs=procs,
        we_created_procs=we_created_procs,
        worker_inputs=worker_inputs,
        worker_output=worker_output,
        tasks=tasks,
        channels=channels,
        worker_assignment=worker_assignment,
        task_order=task_order,
        halls_of_fame=halls_of_fame,
        last_pops=last_pops,
        best_sub_pops=best_sub_pops,
        num_evals=num_evals,
        cycles_remaining=cycles_remaining,
        cur_maxsizes=cur_maxsizes,
        stdin_reader=stdin_reader,
        trace_prototype=trace,
        seed_members=seed_members,
        plugin_states=plugin_states,
        worker_plugin_states=worker_plugin_states,
    )
end
function _initialize_search!(
    state::AbstractSearchState{T,L,N},
    datasets,
    ropt::AbstractRuntimeOptions,
    options::AbstractOptions,
    saved_state,
    guesses::Union{AbstractVector,AbstractVector{<:AbstractVector},Nothing},
) where {T,L,N}
    nout = length(datasets)

    init_hall_of_fame = load_saved_hall_of_fame(saved_state)
    if init_hall_of_fame === nothing
        for j in 1:nout
            state.halls_of_fame[j] = HallOfFame(options, datasets[j])
        end
    else
        # Recompute losses for the hall of fame, in
        # case the dataset changed:
        for j in eachindex(init_hall_of_fame, datasets, state.halls_of_fame)
            hof = strip_metadata(init_hall_of_fame[j], options, datasets[j])
            for member in hof.members[hof.exists]
                cost, result_loss = eval_cost(datasets[j], member, options)
                member.cost = cost
                member.loss = result_loss
            end
            state.halls_of_fame[j] = hof
        end
    end

    if !isnothing(guesses)
        parsed_seed_members = parse_guesses(
            eltype(state.halls_of_fame[1]), guesses, datasets, options
        )
        for j in 1:nout
            state.seed_members[j] = copy(parsed_seed_members[j])
            update_hall_of_fame!(state.halls_of_fame[j], parsed_seed_members[j], options)
        end
    end

    for j in 1:nout, i in 1:(options.populations)
        worker_idx = assign_next_worker!(
            state.worker_assignment; out=j, pop=i, parallelism=ropt.parallelism, state.procs
        )
        saved_pop = load_saved_population(saved_state; out=j, pop=i)
        new_pop = let
            _plugin_states = state.plugin_states[j]
            _worker_plugin_states = state.worker_plugin_states[j][i]
            _dataset = datasets[j]
            if saved_pop !== nothing && length(saved_pop.members) == options.population_size
                _saved_pop = strip_metadata(saved_pop, options, _dataset)
                ## Update losses:
                for member in _saved_pop.members
                    cost, result_loss = eval_cost(_dataset, member, options)
                    member.cost = cost
                    member.loss = result_loss
                end
                copy_pop = copy(_saved_pop)
                @sr_spawner(
                    (datasets, options) -> (
                        copy_pop,
                        HallOfFame(options, datasets[j]),
                        new_trace(options),
                        0.0,
                        _worker_plugin_states,
                    ),
                    inputs = something(state.worker_inputs, (datasets, options)),
                    parallelism = ropt.parallelism,
                    worker_idx = worker_idx,
                    result_type = worker_result_type(state)
                )
            else
                if saved_pop !== nothing && ropt.verbosity > 0
                    @warn "Recreating population (output=$(j), population=$(i)), as the saved one doesn't have the correct number of members."
                end
                @sr_spawner(
                    (datasets, options) -> (
                        Population(
                            datasets[j];
                            population_size=options.population_size,
                            nlength=3,
                            options=options,
                            nfeatures=max_features(datasets[j], options),
                            plugin_states=_plugin_states,
                        ),
                        HallOfFame(options, datasets[j]),
                        new_trace(options),
                        Float64(options.population_size),
                        _worker_plugin_states,
                    ),
                    inputs = something(state.worker_inputs, (datasets, options)),
                    parallelism = ropt.parallelism,
                    worker_idx = worker_idx,
                    result_type = worker_result_type(state)
                )
                # This involves population_size evaluations, on the full dataset:
            end
        end
        push!(state.worker_output[j], new_pop)
    end
    return nothing
end

function _preserve_loaded_state!(
    state::AbstractSearchState{T,L,N},
    ropt::AbstractRuntimeOptions,
    options::AbstractOptions,
) where {T,L,N}
    nout = length(state.worker_output)
    # Get the prototype to extract types
    PopType = eltype(eltype(state.last_pops))
    PM = popmember_type(PopType)
    HallType = HallOfFame{T,L,N,PM}

    for j in 1:nout, i in 1:(options.populations)
        (pop, _, _, _, _) = extract_from_worker(
            state.worker_output[j][i],
            PopType,
            HallType,
            typeof(state.trace_prototype),
            eltype(eltype(state.worker_plugin_states)),
        )
        state.last_pops[j][i] = copy(pop)
    end
    return nothing
end

function _warmup_search!(
    state::AbstractSearchState{T,L,N},
    datasets,
    ropt::AbstractRuntimeOptions,
    options::AbstractOptions,
) where {T,L,N}
    if ropt.niterations == 0
        return _preserve_loaded_state!(state, ropt, options)
    end

    nout = length(datasets)
    for j in 1:nout, i in 1:(options.populations)
        check_external_stop(ropt) && break
        cur_maxsize = state.cur_maxsizes[j]
        worker_idx = assign_next_worker!(
            state.worker_assignment; out=j, pop=i, parallelism=ropt.parallelism, state.procs
        )

        PopType = eltype(eltype(state.last_pops))
        PM = popmember_type(PopType)
        HallType = HallOfFame{T,L,N,PM}
        TraceStateType = typeof(state.trace_prototype)
        WorkerPluginStatesType = eltype(eltype(state.worker_plugin_states))
        (in_pop, _, _, _, worker_plugin_states) = extract_from_worker(
            state.worker_output[j][i],
            PopType,
            HallType,
            TraceStateType,
            WorkerPluginStatesType,
        )

        updated_pop = let verbosity = ropt.verbosity
            @sr_spawner(
                (datasets, options) -> _dispatch_s_r_cycle(
                    in_pop,
                    datasets[j],
                    options;
                    pop=i,
                    out=j,
                    iteration=0,
                    verbosity,
                    cur_maxsize,
                    plugin_states=worker_plugin_states,
                ),
                inputs = something(state.worker_inputs, (datasets, options)),
                parallelism = ropt.parallelism,
                worker_idx = worker_idx,
                result_type = worker_result_type(state)
            )
        end
        state.worker_output[j][i] = updated_pop
    end
    return nothing
end
function _main_search_loop!(
    state::AbstractSearchState{T,L,N},
    datasets,
    ropt::AbstractRuntimeOptions,
    options::AbstractOptions,
) where {T,L,N}
    ropt.verbosity > 0 && @info "Started!"
    nout = length(datasets)
    frontier_saves =
        options.save_to_file ? map(FrontierSaveState, state.halls_of_fame) : nothing

    start_time = time()
    progress_bar = if ropt.progress
        #TODO: need to iterate this on the max cycles remaining!
        WrappedProgressBar(
            ropt.niterations * nout, ropt.niterations; barlen=options.terminal_width
        )
    else
        nothing
    end

    last_print_time = time()
    last_speed_recording_time = time()
    num_evals_last = sum(sum, state.num_evals)
    num_evals_since_last = sum(sum, state.num_evals) - num_evals_last  # i.e., start at 0
    print_every_n_seconds = 5
    equation_speed = Float32[]

    if ropt.parallelism in (:multiprocessing, :multithreading)
        for j in 1:nout, i in 1:(options.populations)
            # Start listening for each population to finish:
            t = @filtered_async put!(state.channels[j][i], fetch(state.worker_output[j][i]))
            push!(state.tasks[j], t)
        end
    end
    kappa = 0
    resource_monitor = ResourceMonitor(;
        # Storing n times as many monitoring intervals as populations seems like it will
        # help get accurate resource estimates:
        max_recordings=(options.populations * 100 * nout),
        start_reporting_at=(options.populations * 3 * nout),
        window_size=(options.populations * 2 * nout),
    )
    while sum(state.cycles_remaining) > 0
        kappa += 1
        if kappa > options.populations * nout
            kappa = 1
        end
        # nout, populations:
        j, i = state.task_order[kappa]

        # Check if error on population:
        if ropt.parallelism in (:multiprocessing, :multithreading)
            if istaskfailed(state.tasks[j][i])
                fetch(state.tasks[j][i])
                error("Task failed for population")
            end
        end
        # Non-blocking check if a population is ready:
        population_ready = if ropt.parallelism in (:multiprocessing, :multithreading)
            # TODO: Implement type assertions based on parallelism.
            isready(state.channels[j][i])
        else
            true
        end
        record_channel_state!(resource_monitor, population_ready)

        # Don't start more if this output has finished its cycles:
        # TODO - this might skip extra cycles?
        population_ready &= (state.cycles_remaining[j] > 0)
        if population_ready
            # Take the fetch operation from the channel since its ready
            (cur_pop, best_seen, cur_trace, cur_num_evals, returned_plugin_states) =
                if ropt.parallelism in
                    (
                    :multiprocessing, :multithreading
                )
                    take!(
                        state.channels[j][i]
                    )
                else
                    state.worker_output[j][i]
                end::DefaultWorkerOutputType{
                    Population{T,L,N},
                    HallOfFame{T,L,N},
                    typeof(state.trace_prototype),
                    eltype(eltype(state.worker_plugin_states)),
                }
            state.last_pops[j][i] = copy(cur_pop)
            state.best_sub_pops[j][i] = best_sub_pop(cur_pop; topn=options.topn)
            write_trace(cur_trace, options.tracing_file)
            state.num_evals[j][i] += cur_num_evals
            dataset = datasets[j]
            cur_maxsize = state.cur_maxsizes[j]

            #! format: off
            update_hall_of_fame!(state.halls_of_fame[j], cur_pop.members, options)
            update_hall_of_fame!(state.halls_of_fame[j], best_seen.members[best_seen.exists], options)
            #! format: on

            # Dominating pareto curve - must be better than all simpler equations
            dominating = calculate_pareto_frontier(state.halls_of_fame[j])

            if options.save_to_file
                save_frontier_if_changed!(
                    frontier_saves[j],
                    state.halls_of_fame[j],
                    dominating,
                    nout,
                    j,
                    dataset,
                    options,
                    ropt,
                )
            end

            # Update plugin state (e.g. parsimony frequency table) from the
            # population the worker actually produced, before migration mixes
            # in pareto/seed/best-of-each members from outside this cycle.
            strictmap(options.plugins, state.plugin_states[j]) do plugin, pstate
                return on_generation_end!(
                    pstate, plugin, state, dataset, options, ropt, cur_pop
                )
            end

            ###################################################################
            # Migration #######################################################
            if options.migration
                migrate!(
                    state.best_sub_pops[j] => cur_pop,
                    options;
                    frac=options.fraction_replaced,
                )
            end
            if options.hof_migration && length(dominating) > 0
                migrate!(dominating => cur_pop, options; frac=options.fraction_replaced_hof)
            end
            if !isempty(state.seed_members[j])
                migrate!(
                    state.seed_members[j] => cur_pop,
                    options;
                    frac=options.fraction_replaced_guesses,
                )
            end
            ###################################################################

            state.cycles_remaining[j] -= 1
            if state.cycles_remaining[j] > 0 && !check_external_stop(ropt)
                worker_idx = assign_next_worker!(
                    state.worker_assignment;
                    out=j,
                    pop=i,
                    parallelism=ropt.parallelism,
                    state.procs,
                )
                iteration = next_trace_iteration(cur_trace)

                in_pop = copy(cur_pop::Population{T,L,N})
                worker_plugin_states = strictmap(
                    options.plugins, returned_plugin_states, state.plugin_states[j]
                ) do plugin, worker_state, latest_head_state
                    refresh_worker_plugin_state(
                        worker_state, latest_head_state, plugin, dataset
                    )
                end
                state.worker_output[j][i] =
                    let in_pop = in_pop,
                        worker_plugin_states = worker_plugin_states,
                        i = i,
                        j = j,
                        iteration = iteration,
                        verbosity = ropt.verbosity,
                        cur_maxsize = cur_maxsize,
                        worker_idx = worker_idx

                        @sr_spawner(
                            (datasets, options) -> _dispatch_s_r_cycle(
                                in_pop,
                                datasets[j],
                                options;
                                pop=i,
                                out=j,
                                iteration,
                                verbosity,
                                cur_maxsize,
                                plugin_states=worker_plugin_states,
                            ),
                            inputs = something(state.worker_inputs, (datasets, options)),
                            parallelism = ropt.parallelism,
                            worker_idx = worker_idx,
                            result_type = worker_result_type(state)
                        )
                    end
                if ropt.parallelism in (:multiprocessing, :multithreading)
                    state.tasks[j][i] = @filtered_async put!(
                        state.channels[j][i], fetch(state.worker_output[j][i])
                    )
                end

                total_cycles = ropt.niterations * options.populations
                state.cur_maxsizes[j] = get_cur_maxsize(;
                    options, total_cycles, cycles_remaining=state.cycles_remaining[j]
                )
                if !isnothing(progress_bar)
                    head_node_occupation = estimate_work_fraction(resource_monitor)
                    cycles_elapsed = total_cycles * nout - sum(state.cycles_remaining)
                    iterations_elapsed = cycles_elapsed ÷ options.populations
                    update_progress_bar!(
                        progress_bar,
                        iterations_elapsed,
                        only(state.halls_of_fame),
                        only(datasets),
                        options,
                        equation_speed,
                        head_node_occupation,
                        ropt.parallelism,
                    )
                end
            end
            if ropt.logger !== nothing
                logging_callback!(ropt.logger; state, datasets, ropt, options)
            end
        end
        yield()

        ################################################################
        ## Search statistics
        elapsed_since_speed_recording = time() - last_speed_recording_time
        if elapsed_since_speed_recording > 1.0
            num_evals_since_last, num_evals_last = let s = sum(sum, state.num_evals)
                s - num_evals_last, s
            end
            current_speed = num_evals_since_last / elapsed_since_speed_recording
            push!(equation_speed, current_speed)
            average_over_m_measurements = 20 # 20 second running average
            if length(equation_speed) > average_over_m_measurements
                deleteat!(equation_speed, 1)
            end
            last_speed_recording_time = time()
        end
        ################################################################

        ################################################################
        ## Printing code
        elapsed = time() - last_print_time
        # Update if time has passed
        if elapsed > print_every_n_seconds
            if ropt.verbosity > 0 && !ropt.progress && length(equation_speed) > 0

                # Dominating pareto curve - must be better than all simpler equations
                head_node_occupation = estimate_work_fraction(resource_monitor)
                total_cycles = ropt.niterations * options.populations
                print_search_state(
                    state.halls_of_fame,
                    datasets;
                    options,
                    equation_speed,
                    total_cycles,
                    state.cycles_remaining,
                    head_node_occupation,
                    parallelism=ropt.parallelism,
                    width=options.terminal_width,
                )
            end
            last_print_time = time()
        end
        ################################################################

        ################################################################
        ## Early stopping code
        if any((
            check_for_loss_threshold(state.halls_of_fame, options),
            check_for_user_quit(state.stdin_reader),
            check_for_timeout(start_time, options),
            check_max_evals(state.num_evals, options),
            check_external_stop(ropt),
        ))
            break
        end
        ################################################################
    end
    if !isnothing(progress_bar)
        finish!(progress_bar)
    end
    return nothing
end
function _tear_down!(
    state::AbstractSearchState,
    datasets,
    ropt::AbstractRuntimeOptions,
    options::AbstractOptions,
)
    close_reader!(state.stdin_reader)
    if ropt.parallelism in (:multiprocessing, :multithreading)
        outputs = Iterators.flatten(state.worker_output)
        if ropt.parallelism == :multiprocessing
            timedwait(() -> all(istaskdone, outputs), 5.0; pollint=0.01)
        else
            for output in outputs
                wait(output)
            end
        end
    end
    for j in eachindex(datasets, state.plugin_states)
        strictmap(options.plugins, state.plugin_states[j]) do plugin, pstate
            return on_search_end!(pstate, plugin, state, datasets[j], options, ropt)
        end
    end
    if ropt.parallelism == :multiprocessing
        # TODO: We should unwrap the error monitors here
        delete_on_workers(state.worker_inputs)
        state.we_created_procs && rmprocs(state.procs)
    end
    drain_external_stop!(ropt)
    return nothing
end
function _format_output(
    state::AbstractSearchState,
    datasets,
    ropt::AbstractRuntimeOptions,
    options::AbstractOptions,
)
    nout = length(datasets)
    out_hof = if ropt.dim_out == 1
        embed_metadata(only(state.halls_of_fame), options, only(datasets))
    else
        map(Fix{2}(embed_metadata, options), state.halls_of_fame, datasets)
    end
    if ropt.return_state
        return (map(Fix{2}(embed_metadata, options), state.last_pops, datasets), out_hof)
    else
        return out_hof
    end
end

@stable default_mode = "disable" function _dispatch_s_r_cycle(
    in_pop::Population{T,L,N},
    dataset::Dataset,
    options::AbstractOptions;
    pop::Int,
    out::Int,
    iteration::Int,
    verbosity,
    cur_maxsize::Int,
    plugin_states::Tuple,
) where {T,L,N}
    trace = new_trace(options)
    trace_iteration_start!(trace, out, pop, iteration, in_pop, options)
    num_evals = 0.0
    out_pop, best_seen, evals_from_cycle = s_r_cycle(
        dataset,
        in_pop,
        options.ncycles_per_iteration,
        cur_maxsize;
        verbosity=verbosity,
        options=options,
        trace=trace,
        plugin_states,
    )
    num_evals += evals_from_cycle
    out_pop, evals_from_optimize = optimize_and_simplify_population(
        dataset, out_pop, options, cur_maxsize, trace
    )
    num_evals += evals_from_optimize
    if use_batching(options, dataset)
        for i_member in 1:(options.maxsize)
            if best_seen.exists[i_member]
                cost, result_loss = eval_cost(dataset, best_seen.members[i_member], options)
                best_seen.members[i_member].cost = cost
                best_seen.members[i_member].loss = result_loss
                num_evals += 1
            end
        end
    end
    return (out_pop, best_seen, trace, num_evals, plugin_states)
end
function _info_dump(
    state::AbstractSearchState,
    datasets::Vector{D},
    ropt::AbstractRuntimeOptions,
    options::AbstractOptions,
) where {D<:Dataset}
    nout = length(state.halls_of_fame)

    # Ensure files are saved even when niterations=0, regardless of verbosity
    if options.save_to_file
        for j in 1:nout
            hall_of_fame = state.halls_of_fame[j]
            dataset = datasets[j]
            dominating = calculate_pareto_frontier(hall_of_fame)
            save_to_file(dominating, nout, j, dataset, options, ropt)
        end
    end

    ropt.verbosity <= 0 && return nothing

    if nout > 1
        @info "Final populations:"
    else
        @info "Final population:"
    end
    for (j, (hall_of_fame, dataset)) in enumerate(zip(state.halls_of_fame, datasets))
        if nout > 1
            @info "Output $j:"
        end
        equation_strings = string_dominating_pareto_curve(
            hall_of_fame,
            dataset,
            options;
            width=@something(
                options.terminal_width,
                ropt.progress ? displaysize(stdout)[2] : nothing,
                Some(nothing)
            )
        )
        println(equation_strings)
    end

    if options.save_to_file
        output_directory = joinpath(
            something(options.output_directory, "outputs"), ropt.run_id
        )
        @info "Results saved to:"
        for j in 1:nout
            filename = nout > 1 ? "hall_of_fame_output$(j).csv" : "hall_of_fame.csv"
            output_file = joinpath(output_directory, filename)
            println("  - ", output_file)
        end
    end
    return nothing
end

include("MLJInterface.jl")
using .MLJInterfaceModule:
    get_options,
    SRRegressor,
    MultitargetSRRegressor,
    SRTestRegressor,
    MultitargetSRTestRegressor,
    machine,
    fit!,
    predict,
    report

# Hack to get static analysis to work from within tests:
@ignore include("../test/runtests.jl")

# TODO: Hack to force ConstructionBase version
using ConstructionBase: ConstructionBase as _

include("precompile.jl")
redirect_stdout(devnull) do
    redirect_stderr(devnull) do
        return do_precompilation(Val(:precompile))
    end
end

end #module SR
