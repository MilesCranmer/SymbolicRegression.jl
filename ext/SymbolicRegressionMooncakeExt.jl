module SymbolicRegressionMooncakeExt

using DynamicExpressions: DynamicExpressions as DE
using SymbolicRegression: SymbolicRegression as SR
using Mooncake: Mooncake

# TODO: Remove this hack once Mooncake.jl is updated:
if !applicable(Mooncake.tangent_type, Union{Mooncake.NoFData,Float32}, Mooncake.NoRData)
    @eval function Mooncake.tangent_type(
        ::Type{Union{Mooncake.NoFData,T}}, ::Type{Mooncake.NoRData}
    ) where {T}
        return Union{Mooncake.NoTangent,Mooncake.tangent_type(T)}
    end
end
if !applicable(Mooncake.tangent_type, Mooncake.NoFData, Union{Mooncake.NoRData,Float32})
    @eval function Mooncake.tangent_type(
        ::Type{Mooncake.NoFData}, ::Type{Union{Mooncake.NoRData,T}}
    ) where {T<:Base.IEEEFloat}
        return Union{Mooncake.NoTangent,Mooncake.tangent_type(T)}
    end
end

function DE.extract_gradient(
    gradient::Mooncake.Tangent, ex::SR.TemplateExpression{T}
) where {T}
    arrays = Vector{T}[]
    for (tree_gradient, tree) in zip(values(gradient.fields.trees), values(ex.trees))
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
            values(gradient.fields.metadata.fields._data.parameters),
            values(ex.metadata.parameters),
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
