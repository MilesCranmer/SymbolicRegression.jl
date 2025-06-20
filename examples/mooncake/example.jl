using SymbolicRegression, Mooncake, MLJBase, DifferentiationInterface
import DynamicExpressions as DE

Mooncake.tangent_type(::Type{<:Base.TTY}) = Mooncake.NoTangent
Mooncake.tangent_type(::Type{<:Options}) = Mooncake.NoTangent
function DE.extract_gradient(gradient::Mooncake.Tangent, ex::Expression{T}) where {T}
    # gradient.fields.tree
    tree = DE.get_tree(ex)
    num_constants = count(t -> t.degree == 0 && t.constant, tree)
    ar = Vector{T}(undef, num_constants)
    _extract_gradient!(ar, gradient.fields.tree, tree)
    return ar
end
function _extract_gradient!(
    ar, gradient, tree::DE.AbstractExpressionNode{T,2}, i=firstindex(ar)
) where {T}
    gradient isa Mooncake.NoTangent && return i

    if tree.degree == 0
        if tree.constant
            ar[i] = gradient.val::T
            i = nextind(ar, i)
        end
    elseif tree.degree == 1
        i = _extract_gradient!(ar, DE.get_child(gradient, 1), DE.get_child(tree, 1), i)
    else
        i = _extract_gradient!(ar, DE.get_child(gradient, 1), DE.get_child(tree, 1), i)
        i = _extract_gradient!(ar, DE.get_child(gradient, 2), DE.get_child(tree, 2), i)
    end
    return i
end

X = (; x=randn(100), y=randn(100), z=randn(100))
y = @. 2 * cos(X.x) + X.y^2 - 4 * X.z

model = SRRegressor(;
    binary_operators=(+, *, /, -),
    unary_operators=(cos, exp),
    autodiff_backend=AutoMooncake(; config=nothing),
    parallelism=:serial,
)
mach = machine(model, X, y)
fit!(mach)
