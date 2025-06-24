module SymbolicRegressionMooncakeExt

using DynamicExpressions: DynamicExpressions as DE
using SymbolicRegression: SymbolicRegression as SR
using Mooncake: Mooncake

function DE.extract_gradient(
    gradient::Mooncake.Tangent, ex::SR.TemplateExpression{T}
) where {T}
    arrays = Vector{T}[]
    for (tree_gradient, tree) in zip(values(gradient.fields.trees), ex.trees)
        if !(tree_gradient isa Mooncake.NoTangent)
            push!(arrays, DE.extract_gradient(tree_gradient, tree))
        else
            num_constants = DE.count_scalar_constants(tree)
            if num_constants > 0
                push!(arrays, zeros(T, num_constants))
            end
        end
    end
    if SR.has_params(ex)
        for (param_gradient, param) in zip(
            values(gradient.fields.metadata.fields._data.parameters), ex.metadata.parameters
        )
            if !(param_gradient isa Mooncake.NoTangent)
                push!(arrays, param_gradient.fields._data)
            else
                push!(arrays, zeros(T, length(param)))
            end
        end
    end
    out = vcat(arrays...)
    return out
end
function DE.extract_gradient(gradient::Mooncake.Tangent, ex::SR.ComposableExpression)
    return DE.extract_gradient(gradient.fields.tree, DE.get_tree(ex))
end

end
