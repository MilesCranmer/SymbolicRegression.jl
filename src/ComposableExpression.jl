module ComposableExpressionModule

using DispatchDoctor: @unstable
using DynamicExpressions:
    AbstractExpression,
    Expression,
    AbstractExpressionNode,
    AbstractOperatorEnum,
    Metadata,
    constructorof,
    get_metadata,
    eval_tree_array,
    set_node!,
    get_contents,
    with_contents,
    DynamicExpressions as DE
using DynamicExpressions.InterfacesModule:
    ExpressionInterface, Interfaces, @implements, all_ei_methods_except, Arguments

using ..ConstantOptimizationModule: ConstantOptimizationModule as CO

abstract type AbstractComposableExpression{T,N} <: AbstractExpression{T,N} end

struct ComposableExpression{
    T,
    N<:AbstractExpressionNode{T},
    D<:@NamedTuple{operators::O, variable_names::V} where {O<:AbstractOperatorEnum,V},
} <: AbstractComposableExpression{T,N}
    tree::N
    metadata::Metadata{D}
end

@inline function ComposableExpression(
    tree::AbstractExpressionNode{T}; metadata...
) where {T}
    d = (; metadata...)
    return ComposableExpression(tree, Metadata(d))
end

@unstable DE.constructorof(::Type{<:ComposableExpression}) = ComposableExpression

DE.get_metadata(ex::AbstractComposableExpression) = ex.metadata
DE.get_contents(ex::AbstractComposableExpression) = ex.tree
DE.get_tree(ex::AbstractComposableExpression) = ex.tree

function DE.get_operators(
    ex::AbstractComposableExpression, operators::Union{AbstractOperatorEnum,Nothing}=nothing
)
    return @something(operators, DE.get_metadata(ex).operators)
end
function DE.get_variable_names(
    ex::AbstractComposableExpression,
    variable_names::Union{Nothing,AbstractVector{<:AbstractString}}=nothing,
)
    return @something(variable_names, DE.get_metadata(ex).variable_names, Some(nothing))
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

function Base.convert(::Type{E}, ex::AbstractComposableExpression) where {E<:Expression}
    return constructorof(E)(get_contents(ex), get_metadata(ex))
end

for name in (:combine_operators, :simplify_tree!)
    @eval function DE.$name(
        ex::AbstractComposableExpression{T,N},
        operators::Union{AbstractOperatorEnum,Nothing}=nothing,
    ) where {T,N}
        inner_ex = DE.$name(convert(Expression, ex), operators)
        return with_contents(ex, inner_ex)
    end
end

function CO.count_constants_for_optimization(ex::AbstractComposableExpression)
    return CO.count_constants_for_optimization(convert(Expression, ex))
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

function apply_operator(op::F, x...) where {F<:Function}
    if all(_is_valid, x)
        vx = map(_get_value, x)
        return VectorWrapper(op.(vx...), true)
    else
        return VectorWrapper(_get_value(first(x)), false)
    end
end
_is_valid(x::VectorWrapper) = x.valid
_is_valid(x) = true
_get_value(x::VectorWrapper) = x.value
_get_value(x) = x

#! format: off
# First, binary operators:
for op in (
    :*, :/, :+, :-, :^, :÷, :mod, :log,
    :atan, :atand, :copysign, :flipsign,
    :&, :|, :⊻, ://, :\,
)
    @eval begin
        Base.$(op)(x::VectorWrapper, y::VectorWrapper) = apply_operator(Base.$(op), x, y)
        Base.$(op)(x::VectorWrapper, y::Number) = apply_operator(Base.$(op), x, y)
        Base.$(op)(x::Number, y::VectorWrapper) = apply_operator(Base.$(op), x, y)
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
    @eval Base.$(op)(x::VectorWrapper) = apply_operator(Base.$(op), x)
end
#! format: on

end
