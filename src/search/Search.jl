module SearchModule

using Distributed

using Pkg: Pkg

using Random: seed!, shuffle!
using ProgressMeter: finish!
using DynamicExpressions: GraphNode, set_default_variable_names!, node_type

using LossFunctions: SupervisedLoss
using Compat: Fix

using DispatchDoctor: @stable, @unstable
using ..SymbolicRegression: SymbolicRegression, PACKAGE_VERSION

include("ProgressBars.jl")
include("SearchUtils.jl")
include("Logging.jl")

using ..InterfacesModule:
    DATA_TYPE, LOSS_TYPE, Dataset, max_features, is_weighted, has_units
using ..ConfigModule: use_batching, Options
using ..InterfacesModule: AbstractOptions, create_expression

using ..InterfacesModule:
    init_value,
    sample_value,
    init_plugin_states,
    on_search_start!,
    on_search_end!,
    on_generation_end!,
    fork_plugin_state,
    refresh_worker_plugin_state
using ..UtilsModule: is_anonymous_function, strictmap

using ..EvolutionModule: gen_random_tree
using ..ExpressionsModule: require_copy_to_workers, make_example_inputs
using ..EvaluationModule: eval_cost, update_baseline_loss!

using ..EvolutionModule:
    PopMember,
    popmember_type,
    expression_type,
    Population,
    best_sub_pop,
    HallOfFame,
    calculate_pareto_frontier,
    string_dominating_pareto_curve,
    update_hall_of_fame!

using ..EvolutionModule: s_r_cycle, optimize_and_simplify_population
using .ProgressBarsModule: WrappedProgressBar
using ..EvolutionModule:
    initialize_trace!,
    new_trace,
    next_trace_iteration,
    trace_iteration_start!,
    write_trace,
    migrate!
using .SearchUtilsModule:
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
using .LoggingModule: AbstractSRLogger, SRLogger
using ..ExpressionsModule: TemplateExpression

using ..ExpressionsModule: embed_metadata, strip_metadata

include("Configure.jl")
@unstable include("EquationSearch.jl")

end
