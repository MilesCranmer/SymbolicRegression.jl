using SymbolicRegression, Mooncake, MLJBase, DifferentiationInterface, LoopVectorization
import DynamicExpressions as DE

Mooncake.tangent_type(::Type{<:Base.TTY}) = Mooncake.NoTangent
function Mooncake.tangent_type(
    ::Type{Union{Mooncake.NoFData,T}}, ::Type{Mooncake.NoRData}
) where {T}
    return Union{Mooncake.NoTangent,Mooncake.tangent_type(T)}
end
function Mooncake.tangent_type(
    ::Type{Mooncake.NoFData}, ::Type{Union{Mooncake.NoRData,F}}
) where {F<:Union{Float16,Float32,Float64}}
    return Union{Mooncake.NoTangent,F}
end

X = (; x=randn(100), y=randn(100), z=randn(100))
y = @. 2 * cos(X.x) + X.y^2 - 4 * X.z

expression_spec = @template_spec(expressions = (f, g), parameters = (p1=3,),) do x, y, z
    return f(x, y) + g(z) + p1[1] + p1[2]
end

function DE.extract_gradient(
    gradient::Mooncake.Tangent, ex::TemplateExpression{T}
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
    if hasproperty(ex.metadata, :parameters)
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
    rand() < 0.0001 && @show out
    return out
end
function DE.extract_gradient(gradient::Mooncake.Tangent, ex::ComposableExpression)
    return DE.extract_gradient(gradient.fields.tree, get_tree(ex))
end

model = SRRegressor(;
    binary_operators=(+, *, /, -),
    unary_operators=(cos, exp),
    autodiff_backend=AutoMooncake(; config=nothing),
    expression_spec=expression_spec,
    parallelism=:serial,
)
mach = machine(model, X, y)
fit!(mach)
