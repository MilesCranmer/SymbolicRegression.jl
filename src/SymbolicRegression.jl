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
    include("interfaces/Interfaces.jl")
    include("config/Config.jl")
    include("expressions/Expressions.jl")
    include("evaluation/Evaluation.jl")
    include("evolution/Evolution.jl")
    include("search/Search.jl")
    include("plugins/Plugins.jl")

    __dispatch_doctor_unsable_test() = Val(rand(1:10))
end

using .InterfacesModule:
    DATA_TYPE,
    LOSS_TYPE,
    TraceType,
    Dataset,
    BasicDataset,
    SubDataset,
    max_features,
    is_weighted,
    batch,
    has_units
using .ConfigModule: use_batching, Options, ComplexityMapping, WarmStartIncompatibleError
using .InterfacesModule: AbstractOptions, create_expression
using .ConfigModule: MutationWeights, sample_mutation
using .InterfacesModule:
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
    ConstantMutationContext,
    AbstractCrossover,
    SubtreeCrossover,
    default_crossovers,
    AbstractExpressionSpec,
    ExpressionSpec,
    init_value,
    parse_scope,
    sample_value,
    mutate_value
using .ConfigModule:
    get_safe_op,
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
    atanh_clip
using .InterfacesModule:
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
    plugin_crossovers
using .UtilsModule: is_anonymous_function, strictmap, @ignore, get_birth_order
using .EvaluationModule: compute_complexity, check_constraints
using .EvolutionModule:
    gen_random_tree, gen_random_tree_fixed_size, random_node, crossover_trees
using .ExpressionsModule: @extend_operators, require_copy_to_workers, make_example_inputs
using .EvaluationModule: eval_loss, eval_cost, update_baseline_loss!, score_func
using .EvolutionModule:
    optimize_constants,
    get_constants_for_optimization,
    set_constants_for_optimization!,
    extract_gradient_for_optimization,
    get_optimizable_parameters,
    set_optimizable_parameters!,
    extract_optimizable_gradient,
    AbstractPopMember,
    PopMember,
    reset_birth!,
    popmember_type,
    expression_type,
    Population,
    best_sub_pop,
    best_of_sample,
    HallOfFame,
    calculate_pareto_frontier,
    string_dominating_pareto_curve,
    update_hall_of_fame!,
    mutate!,
    condition_mutation_weights!,
    MutationResult,
    crossover,
    CrossoverResult,
    s_r_cycle,
    optimize_and_simplify_population
using .SearchModule: WrappedProgressBar
using .EvolutionModule:
    initialize_trace!,
    new_trace,
    next_trace_iteration,
    trace_iteration_start!,
    write_trace,
    migrate!
using .SearchModule:
    AbstractSearchState,
    SearchState,
    AbstractRuntimeOptions,
    RuntimeOptions,
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
using .SearchModule.SearchUtilsModule: ExternalStop, StdinReader
using .SearchModule: AbstractSRLogger, SRLogger
using .SearchModule.LoggingModule: get_logger
using .ExpressionsModule:
    TemplateExpression,
    TemplateStructure,
    TemplateExpressionSpec,
    ParamVector,
    has_params,
    ValidVector,
    TemplateReturnError,
    AbstractComposableExpression,
    ComposableExpression,
    ValidVectorMixError,
    ValidVectorAccessError,
    embed_metadata,
    strip_metadata,
    @template_spec
using .PluginsModule:
    AdaptiveParsimonyPlugin,
    AdaptiveMutationWeightsPlugin,
    MutationBurstPlugin,
    SimulatedAnnealingPlugin

using .SearchModule:
    equation_search,
    _equation_search,
    _validate_options,
    _create_workers,
    _initialize_search!,
    _preserve_loaded_state!,
    _warmup_search!,
    _main_search_loop!,
    _tear_down!,
    _format_output,
    _dispatch_s_r_cycle,
    _info_dump,
    test_operator,
    get_test_inputs,
    assert_operators_well_defined,
    test_option_configuration,
    test_dataset_configuration,
    move_functions_to_workers,
    copy_definition_to_workers,
    fetch_all,
    test_function_on_workers,
    activate_env_on_workers,
    import_module_on_workers,
    test_module_on_workers,
    test_entire_pipeline,
    configure_workers,
    TEST_TYPE,
    TEST_INPUTS
using Random: MersenneTwister

@stable default_mode = "disable" begin
    include("deprecates.jl")
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
