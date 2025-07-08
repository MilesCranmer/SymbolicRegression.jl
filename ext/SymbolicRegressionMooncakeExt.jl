module SymbolicRegressionMooncakeExt

using DynamicExpressions: DynamicExpressions as DE
using SymbolicRegression: SymbolicRegression as SR
using SymbolicRegression.ConstantOptimizationModule: count_constants_for_optimization
using Mooncake: Mooncake

function DE.extract_gradient(
    gradient::Mooncake.Tangent, ex::SR.TemplateExpression{T}
) where {T}
    n_const = count_constants_for_optimization(ex)
    out = Array{T}(undef, n_const)
    i = firstindex(out)
    for (tree_gradient, tree) in zip(values(gradient.fields.trees), values(ex.trees))
        if !(tree_gradient isa Mooncake.NoTangent)
            grad_array = DE.extract_gradient(tree_gradient, tree)
            @inbounds for g in grad_array
                i = DE.pack_scalar_constants!(out, i, g)
            end
        else
            num_constants = count_constants_for_optimization(tree)
            if num_constants > 0
                @inbounds for _ in 1:num_constants
                    i = DE.pack_scalar_constants!(out, i, zero(T))
                end
            end
        end
    end
    if SR.has_params(ex)
        for (param_gradient, param) in zip(
            values(gradient.fields.metadata.fields._data.parameters),
            values(ex.metadata.parameters),
        )
            if !(param_gradient isa Mooncake.NoTangent)
                @inbounds for g in param_gradient.fields._data
                    i = DE.pack_scalar_constants!(out, i, g)
                end
            else
                @inbounds for _ in 1:length(param)
                    i = DE.pack_scalar_constants!(out, i, zero(T))
                end
            end
        end
    end
    return out
end
function DE.extract_gradient(gradient::Mooncake.Tangent, ex::SR.ComposableExpression)
    return DE.extract_gradient(gradient.fields.tree, DE.get_tree(ex))
end

end
