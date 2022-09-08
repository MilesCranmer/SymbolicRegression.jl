module CoreModule

include("ProgramConstants.jl")
include("Dataset.jl")
include("OptionsStruct.jl")
include("Equation.jl")
include("Operators.jl")
include("Options.jl")

import .ProgramConstantsModule:
    CONST_TYPE,
    MAX_DEGREE,
    BATCH_DIM,
    FEATURE_DIM,
    RecordType,
    SRConcurrency,
    SRSerial,
    SRThreaded,
    SRDistributed
import .DatasetModule: Dataset
import .OptionsStructModule: Options
import .EquationModule: Node, copy_node, string_tree, print_tree
import .OptionsModule: Options
import .OperatorsModule:
    plus,
    sub,
    mult,
    square,
    cube,
    pow,
    pow_nan,
    div,
    log_nan,
    log2_nan,
    log10_nan,
    log1p_nan,
    sqrt_nan,
    acosh_nan,
    neg,
    greater,
    greater,
    relu,
    logical_or,
    logical_and,
    gamma,
    erf,
    erfc,
    atanh_clip

end
