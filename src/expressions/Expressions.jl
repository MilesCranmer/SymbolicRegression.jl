module ExpressionsModule

include("InterfaceDynamicExpressions.jl")
include("ExpressionBuilder.jl")
include("ComposableExpression.jl")
include("TemplateExpression.jl")
include("TemplateExpressionMacro.jl")

using .InterfaceDynamicExpressionsModule:
    @extend_operators, require_copy_to_workers, make_example_inputs
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

end
