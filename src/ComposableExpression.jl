module ComposableExpressionModule

using DynamicExpressions:
    AbstractExpression,
    AbstractExpressionNode,
    AbstractOperatorEnum,
    Metadata,
    eval_tree_array,
    set_node!,
    DynamicExpressions as DE
using DynamicExpressions.InterfacesModule:
    ExpressionInterface, Interfaces, @implements, all_ei_methods_except, Arguments

abstract type AbstractComposableExpression{T,N} <: AbstractExpression{T,N} end

struct ComposableExpression{T,N<:AbstractExpressionNode{T},D<:NamedTuple} <:
       AbstractComposableExpression{T,N}
    tree::N
    metadata::Metadata{D}
end

@inline function ComposableExpression(
    tree::AbstractExpressionNode{T}; metadata...
) where {T}
    d = (; metadata...)
    return ComposableExpression(tree, Metadata(d))
end

DE.get_metadata(ex::AbstractComposableExpression) = ex.metadata
DE.get_contents(ex::AbstractComposableExpression) = ex.tree
DE.get_tree(ex::AbstractComposableExpression) = ex.tree

function DE.get_operators(
    ex::AbstractComposableExpression, operators::Union{AbstractOperatorEnum,Nothing}=nothing
)
    return something(operators, DE.get_metadata(ex).operators)
end
function DE.get_variable_names(
    ex::AbstractComposableExpression,
    variable_names::Union{Nothing,AbstractVector{<:AbstractString}}=nothing,
)
    return something(variable_names, DE.get_metadata(ex).variable_names)
end

function DE.get_scalar_constants(ex::AbstractComposableExpression)
    return DE.get_scalar_constants(DE.get_contents(ex))
end
function DE.set_scalar_constants!(ex::AbstractComposableExpression, constants, refs)
    return DE.set_scalar_constants!(DE.get_contents(ex), constants, refs)
end

function Base.copy(ex::AbstractComposableExpression)
    return ComposableExpression(copy(ex.tree), copy(ex.metadata))
end

@implements(
    ExpressionInterface{all_ei_methods_except(())}, ComposableExpression, [Arguments()]
)

struct VectorWrapper{A<:AbstractVector}
    value::A
    valid::Bool
end
VectorWrapper(x::Tuple{Vararg{Any,2}}) = VectorWrapper(x...)

function (ex::AbstractComposableExpression)(x)
    return error("ComposableExpression does not support input of type $(typeof(x))")
end
function (ex::AbstractComposableExpression)(x::AbstractVector, _xs::AbstractVector...)
    xs = (x, _xs...)
    # Wrap it up for the recursive call
    xs = ntuple(i -> VectorWrapper(xs[i], true), Val(length(xs)))
    result = ex(xs...)
    # Unwrap it
    if result.valid
        return result.value
    else
        nan = convert(eltype(result.value), NaN)
        return result.value .* nan
    end
end
function (ex::AbstractComposableExpression)(x::VectorWrapper, _xs::VectorWrapper...)
    xs = (x, _xs...)
    valid = all(xi -> xi.valid, xs)
    if !valid
        return VectorWrapper(first(xs).value, false)
    else
        X = Matrix(stack(map(xi -> xi.value, xs))')
        return VectorWrapper(eval_tree_array(ex, X))
    end
end
function (ex::AbstractComposableExpression)(
    x::AbstractComposableExpression, _xs::AbstractComposableExpression...
)
    xs = (x, _xs...)
    # To do this, we basically want to put the tree of x
    # into the position of variable 1, and so on!
    tree = copy(get_contents(ex))
    xs_trees = map(get_contents, xs)
    # TODO: This is a bit dangerous, no? We are assuming
    # that `foreach` won't try to go down the copied trees
    foreach(tree) do node
        if node.degree == 0 && !node.constant
            set_node!(node, copy(xs_trees[node.feature]))
        end
    end
    return with_contents(ex, tree)
end

# Basically we want to vectorize every single operation on VectorWrapper,
# so that the user can use it easily.

#! format: off
# First, binary operators:
for op in (
    :*, :/, :+, :-, :^, :÷, :mod, :log,
    :atan, :atand, :copysign, :flipsign,
    :&, :|, :⊻, ://, :\,
)
    @eval function Base.$(op)(x::VectorWrapper, y::VectorWrapper)
        return VectorWrapper(@. Base.$(op)(x.value, y.value))
    end
end

for op in (
    :sin, :cos, :tan, :sinh, :cosh, :tanh, :asin, :acos,
    :asinh, :acosh, :atanh, :sec, :csc, :cot, :asec, :acsc, :acot, :sech, :csch,
    :coth, :asech, :acsch, :acoth, :sinc, :cosc, :cosd, :cotd, :cscd, :secd,
    :sinpi, :cospi, :sind, :tand, :acosd, :acotd, :acscd, :asecd, :asind,
    :log, :log2, :log10, :log1p, :exp, :exp2, :exp10, :expm1, :frexp, :exponent,
    :float, :abs, :real, :imag, :conj, :unsigned,
    :nextfloat, :prevfloat, :transpose, :significand,
    :modf, :rem, :floor, :ceil, :round, :trunc,
    :inv, :sqrt, :cbrt, :abs2, :angle, :factorial,
    :(!), :-, :+, :sign, :identity,
)
    @eval function Base.$(op)(x::VectorWrapper)
        return VectorWrapper(@. Base.$(op)(x.value))
    end
end
#! format: on

end
