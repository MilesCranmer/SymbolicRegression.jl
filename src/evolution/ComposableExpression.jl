module ComposableExpressionEvolutionModule

using DynamicExpressions: DynamicExpressions as DE
using ...ExpressionsModule.ComposableExpressionModule: ComposableExpression
using ..ConstantOptimizationModule: ConstantOptimizationModule as CO

function CO.get_optimizable_parameters(ex::ComposableExpression, _options)
    return DE.get_scalar_constants(ex)
end
function CO.set_optimizable_parameters!(ex::ComposableExpression, x, refs)
    return DE.set_scalar_constants!(ex, x, refs)
end
function CO.extract_optimizable_gradient(grad, ex::ComposableExpression, _refs)
    return DE.extract_gradient(grad, ex)
end

end
