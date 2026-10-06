module InterfacesModule

include("ProgramConstants.jl")
include("OptionsInterface.jl")
include("InterfaceDynamicQuantities.jl")
include("Dataset.jl")
include("Mutations.jl")
include("Crossovers.jl")
include("ExpressionSpec.jl")
include("InterfaceDataTypes.jl")
include("Plugin.jl")

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
    plugin_crossovers
using .OptionsInterfaceModule: AbstractOptions, create_expression

end
