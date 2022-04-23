module CoreModule

include("ProgramConstants.jl")
include("Dataset.jl")
include("Equation.jl")
include("Operators.jl")
include("Options.jl")

import .ProgramConstantsModule: CONST_TYPE, MAX_DEGREE, BATCH_DIM, FEATURE_DIM, RecordType, SRConcurrency, SRSerial, SRThreaded, SRDistributed
import .DatasetModule: Dataset
import .EquationModule: Node, copyNode, stringTree, printTree
import .OptionsModule: Options
import .OperatorsModule: plus, sub, mult, square, cube, pow, div, log_abs, log2_abs, log10_abs, log1p_abs, sqrt_abs, acosh_abs, neg, greater, greater, relu, logical_or, logical_and, gamma, erf, erfc, atanh_clip

end
