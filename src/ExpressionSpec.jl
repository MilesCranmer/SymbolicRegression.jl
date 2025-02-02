module ExpressionSpecModule

using DynamicExpressions: AbstractExpression, Expression, AbstractExpressionNode, Node

abstract type AbstractExpressionSpec end

"""
    ExpressionSpec <: AbstractExpressionSpec

(Experimental) Default specification for basic expressions without special options.
"""
Base.@kwdef struct ExpressionSpec{NT<:Type{<:AbstractExpressionNode}} <:
                   AbstractExpressionSpec
    node_type::NT = Node
end

get_expression_type(::ExpressionSpec) = Expression
get_expression_options(::ExpressionSpec) = NamedTuple()
get_node_type(spec::ExpressionSpec) = spec.node_type

end
