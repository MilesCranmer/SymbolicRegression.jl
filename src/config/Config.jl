module ConfigModule

include("MutationWeights.jl")
include("OptionsStruct.jl")
include("Operators.jl")
include("PluginDefaults.jl")
include("Options.jl")

using .MutationWeightsModule: MutationWeights, sample_mutation
using ..InterfacesModule.OptionsInterfaceModule: AbstractOptions
using .OptionsStructModule:
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
using .PluginDefaultsModule:
    default_adaptive_parsimony_plugin,
    default_simulated_annealing_plugin,
    default_adaptive_mutation_weights_plugin

end
