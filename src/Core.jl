module CoreModule

include("Utils.jl")
include("ProgramConstants.jl")
include("Dataset.jl")
include("MutationWeights.jl")
include("OptionsStruct.jl")
include("Operators.jl")
include("Options.jl")

using .ProgramConstantsModule:
    MAX_DEGREE, BATCH_DIM, FEATURE_DIM, RecordType, DATA_TYPE, LOSS_TYPE
using .DatasetModule: Dataset
using .MutationWeightsModule: MutationWeights, sample_mutation
using .OptionsStructModule: Options, ComplexityMapping
using .OptionsModule: Options
using .OperatorsModule:
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
    safe_acosh,
    neg,
    greater,
    cond,
    relu,
    logical_or,
    logical_and,
    gamma,
    erf,
    erfc,
    atanh_clip

end
