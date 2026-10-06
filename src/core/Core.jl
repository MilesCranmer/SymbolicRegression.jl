module CoreModule

function create_expression end

include("ProgramConstants.jl")
include("Dataset.jl")
include("Mutations.jl")
include("Crossovers.jl")
include("MutationWeights.jl")
include("OptionsStruct.jl")
include("Operators.jl")
include("ExpressionSpec.jl")
include("Plugin.jl")
include("Options.jl")
include("InterfaceDataTypes.jl")

using .ProgramConstantsModule: MaybeTrace, TraceType, DATA_TYPE, LOSS_TYPE
using .DatasetModule:
    Dataset,
    BasicDataset,
    SubDataset,
    is_weighted,
    has_units,
    max_features,
    batch,
    get_indices,
    get_full_dataset,
    dataset_fraction
using .MutationWeightsModule: MutationWeights, sample_mutation
using .MutationsModule:
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
    ConstantMutationContext,
    BUILTIN_MUTATION_TYPES,
    default_mutations
using .CrossoversModule:
    AbstractCrossover, SubtreeCrossover, BUILTIN_CROSSOVER_TYPES, default_crossovers
using .OptionsStructModule:
    AbstractOptions,
    Options,
    ComplexityMapping,
    specialized_options,
    operator_specialization,
    use_batching,
    get_batch_size,
    batching_required,
    WarmStartIncompatibleError,
    check_warm_start_compatibility
using .OperatorsModule:
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
using .ExpressionSpecModule:
    AbstractExpressionSpec,
    ExpressionSpec,
    get_expression_type,
    get_expression_options,
    get_node_type
using .InterfaceDataTypesModule: init_value, parse_scope, sample_value, mutate_value
using .PluginModule:
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
    tournament_cost_multiplier,
    mutation_acceptance_multiplier,
    MutationAcceptanceContext,
    fork_plugin_state,
    refresh_worker_plugin_state,
    resolve_init_member,
    MutationStepResult,
    wrap_mutation_step,
    on_cycle_start!,
    prepare_mutation_context,
    condition_mutation!,
    plugin_mutations,
    plugin_crossovers,
    default_adaptive_parsimony_plugin,
    default_simulated_annealing_plugin,
    default_adaptive_mutation_weights_plugin

end
