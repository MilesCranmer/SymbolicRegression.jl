module ComposableExpressionModule

using DynamicExpressions:
    AbstractExpression,
    AbstractExpressionNode,
    AbstractOperatorEnum,
    Metadata,
    eval_tree_array,
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

@implements(
    ExpressionInterface{all_ei_methods_except(())}, ComposableExpression, [Arguments()]
)

struct ResultOk{A<:AbstractVector}
    value::A
    ok::Bool
end
ResultOk(x::Tuple{Vararg{Any,2}}) = ResultOk(x...)

function (ex::AbstractComposableExpression)(x)
    return error("ComposableExpression does not support input of type $(typeof(x))")
end
function (ex::AbstractComposableExpression)(x::AbstractVector, _xs::AbstractVector...)
    xs = (x, _xs...)
    # Wrap it up for the recursive call
    xs = ntuple(i -> ResultOk(xs[i], true), Val(length(xs)))
    result_ok = ex(xs...)
    # Unwrap it
    if result_ok.ok
        return result_ok.value
    else
        nan = convert(eltype(result_ok.value), NaN)
        return result_ok.value .* nan
    end
end
function (ex::AbstractComposableExpression)(x::ResultOk, _xs::ResultOk...)
    xs = (x, _xs...)
    ok = all(xi -> xi.ok, xs)
    if !ok
        return ResultOk(first(xs).value, false)
    end
    X = Matrix(stack(map(xi -> xi.value, xs)...)')
    return ResultOk(eval_tree_array(ex, X))
end

end
