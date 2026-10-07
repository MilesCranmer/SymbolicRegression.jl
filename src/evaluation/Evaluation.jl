module EvaluationModule

include("Complexity.jl")
include("DimensionalAnalysis.jl")
include("CheckConstraints.jl")
include("InverseFunctions.jl")
include("EvaluateInverse.jl")
include("LossFunctions.jl")
include("TemplateExpression.jl")

using .ComplexityModule: compute_complexity
using .CheckConstraintsModule: check_constraints
using .LossFunctionsModule: eval_loss, eval_cost, update_baseline_loss!, score_func

end
