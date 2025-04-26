module InterfaceDynamicExpressionsModule

using BorrowChecker: @&, @take
using Printf: @sprintf
using DispatchDoctor: @stable
using Compat: Fix
using DynamicExpressions:
    DynamicExpressions as DE,
    OperatorEnum,
    GenericOperatorEnum,
    AbstractExpression,
    AbstractExpressionNode,
    Node,
    GraphNode,
    EvalOptions
using DynamicQuantities: dimension, ustrip
using ..CoreModule: AbstractOptions, Dataset
using ..CoreModule.OptionsModule: inverse_binopmap, inverse_unaopmap
using ..UtilsModule: subscriptify

"""
    eval_tree_array(tree::Union{AbstractExpression,AbstractExpressionNode}, X::AbstractArray, options::AbstractOptions; kws...)

Evaluate a binary tree (equation) over a given input data matrix. The
operators contain all of the operators used. This function fuses doublets
and triplets of operations for lower memory usage.

This function can be represented by the following pseudocode:

```
function eval(current_node)
    if current_node is leaf
        return current_node.value
    elif current_node is degree 1
        return current_node.operator(eval(current_node.left_child))
    else
        return current_node.operator(eval(current_node.left_child), eval(current_node.right_child))
```
The bulk of the code is for optimizations and pre-emptive NaN/Inf checks,
which speed up evaluation significantly.

# Arguments
- `tree::Union{AbstractExpression,AbstractExpressionNode}`: The root node of the tree to evaluate.
- `X::AbstractArray`: The input data to evaluate the tree on.
- `options::AbstractOptions`: Options used to define the operators used in the tree.

# Returns
- `(output, complete)::Tuple{AbstractVector, Bool}`: the result,
    which is a 1D array, as well as if the evaluation completed
    successfully (true/false). A `false` complete means an infinity
    or nan was encountered, and a large loss should be assigned
    to the equation.
"""
@stable(
    default_mode = "disable",
    default_union_limit = 2,
    function DE.eval_tree_array(
        tree::Union{AbstractExpressionNode,AbstractExpression},
        X::AbstractMatrix,
        options::@&(AbstractOptions);
        turbo=nothing,
        bumper=nothing,
        kws...,
    )
        A = expected_array_type(X, typeof(tree))
        eval_options = EvalOptions(;
            turbo=something(turbo, @take(options.turbo)),
            bumper=something(bumper, @take(options.bumper)),
        )
        out, complete = DE.eval_tree_array(
            tree, X, DE.get_operators(tree, @take(options)); eval_options, kws...
        )
        if isnothing(out)
            return nothing, false
        else
            return out::A, complete::Bool
        end
    end
)

"""Improve type inference by telling Julia the expected array returned."""
function expected_array_type(X::AbstractArray, ::Type)
    return typeof(similar(X, axes(X, 2)))
end
expected_array_type(X::AbstractArray, ::Type, ::Val{:eval_grad_tree_array}) = typeof(X)
expected_array_type(::Matrix{T}, ::Type) where {T} = Vector{T}
expected_array_type(::SubArray{T,2,Matrix{T}}, ::Type) where {T} = Vector{T}

"""
    eval_diff_tree_array(tree::Union{AbstractExpression,AbstractExpressionNode}, X::AbstractArray, options::AbstractOptions, direction::Int)

Compute the forward derivative of an expression, using a similar
structure and optimization to eval_tree_array. `direction` is the index of a particular
variable in the expression. e.g., `direction=1` would indicate derivative with
respect to `x1`.

# Arguments

- `tree::Union{AbstractExpression,AbstractExpressionNode}`: The expression tree to evaluate.
- `X::AbstractArray`: The data matrix, with each column being a data point.
- `options::AbstractOptions`: The options containing the operators used to create the `tree`.
- `direction::Int`: The index of the variable to take the derivative with respect to.

# Returns

- `(evaluation, derivative, complete)::Tuple{AbstractVector, AbstractVector, Bool}`: the normal evaluation,
    the derivative, and whether the evaluation completed as normal (or encountered a nan or inf).
"""
function DE.eval_diff_tree_array(
    tree::Union{AbstractExpression,AbstractExpressionNode},
    X::AbstractArray,
    options::AbstractOptions,
    direction::Int,
)
    # TODO: Add `AbstractExpression` implementation in `Expression.jl`
    A = expected_array_type(X, typeof(tree))
    out, grad, complete = DE.eval_diff_tree_array(
        DE.get_tree(tree), X, DE.get_operators(tree, options), direction
    )
    return out::A, grad::A, complete::Bool
end

"""
    eval_grad_tree_array(tree::Union{AbstractExpression,AbstractExpressionNode}, X::AbstractArray, options::AbstractOptions; variable::Bool=false)

Compute the forward-mode derivative of an expression, using a similar
structure and optimization to eval_tree_array. `variable` specifies whether
we should take derivatives with respect to features (i.e., `X`), or with respect
to every constant in the expression.

# Arguments

- `tree::Union{AbstractExpression,AbstractExpressionNode}`: The expression tree to evaluate.
- `X::AbstractArray`: The data matrix, with each column being a data point.
- `options::AbstractOptions`: The options containing the operators used to create the `tree`.
- `variable::Bool`: Whether to take derivatives with respect to features (i.e., `X` - with `variable=true`),
    or with respect to every constant in the expression (`variable=false`).

# Returns

- `(evaluation, gradient, complete)::Tuple{AbstractVector, AbstractArray, Bool}`: the normal evaluation,
    the gradient, and whether the evaluation completed as normal (or encountered a nan or inf).
"""
function DE.eval_grad_tree_array(
    tree::Union{AbstractExpression,AbstractExpressionNode},
    X::AbstractArray,
    options::AbstractOptions;
    kws...,
)
    A = expected_array_type(X, typeof(tree))
    dA = expected_array_type(X, typeof(tree), Val(:eval_grad_tree_array))
    out, grad, complete = DE.eval_grad_tree_array(
        tree, X, DE.get_operators(tree, options); kws...
    )
    return out::A, grad::dA, complete::Bool
end

"""
    differentiable_eval_tree_array(tree::AbstractExpressionNode, X::AbstractArray, options::AbstractOptions)

Evaluate an expression tree in a way that can be auto-differentiated.
"""
function DE.differentiable_eval_tree_array(
    tree::Union{AbstractExpression,AbstractExpressionNode},
    X::AbstractArray,
    options::AbstractOptions,
)
    # TODO: Add `AbstractExpression` implementation in `Expression.jl`
    A = expected_array_type(X, typeof(tree))
    out, complete = DE.differentiable_eval_tree_array(
        DE.get_tree(tree), X, DE.get_operators(tree, options)
    )
    return out::A, complete::Bool
end

const WILDCARD_UNIT_STRING = "[?]"

"""
    string_tree(tree::AbstractExpressionNode, options::AbstractOptions; kws...)

Convert an equation to a string.

# Arguments

- `tree::AbstractExpressionNode`: The equation to convert to a string.
- `options::AbstractOptions`: The options holding the definition of operators.
- `variable_names::Union{Array{String, 1}, Nothing}=nothing`: what variables
    to print for each feature.
"""
@inline function DE.string_tree(
    tree::Union{AbstractExpression,AbstractExpressionNode},
    options::AbstractOptions;
    pretty::Bool=false,
    X_sym_units=nothing,
    y_sym_units=nothing,
    variable_names=nothing,
    display_variable_names=variable_names,
    kws...,
)
    if !pretty
        tree = tree isa GraphNode ? convert(Node, tree) : tree
        return DE.string_tree(
            tree,
            DE.get_operators(tree, options);
            f_variable=string_variable_raw,
            variable_names,
            pretty,
        )
    end

    if X_sym_units !== nothing || y_sym_units !== nothing
        return DE.string_tree(
            tree,
            DE.get_operators(tree, options);
            f_variable=Fix{3}(string_variable, X_sym_units),
            f_constant=let
                unit_placeholder =
                    options.dimensionless_constants_only ? "" : WILDCARD_UNIT_STRING
                Fix{2}(
                    Fix{3}(string_constant, unit_placeholder), options.v_print_precision
                )
            end,
            variable_names=display_variable_names,
            pretty,
            kws...,
        )
    else
        return DE.string_tree(
            tree,
            DE.get_operators(tree, options);
            f_variable=string_variable,
            f_constant=Fix{2}(Fix{3}(string_constant, ""), options.v_print_precision),
            variable_names=display_variable_names,
            pretty,
            kws...,
        )
    end
end
function string_variable_raw(feature, variable_names)
    if variable_names === nothing || feature > length(variable_names)
        return "x" * string(feature)
    else
        return variable_names[feature]
    end
end
function string_variable(feature, variable_names, variable_units=nothing)
    base = if variable_names === nothing || feature > length(variable_names)
        "x" * subscriptify(feature)
    else
        variable_names[feature]
    end
    if variable_units !== nothing
        base *= format_dimensions(variable_units[feature])
    end
    return base
end
function string_constant(val, ::Val{precision}, unit_placeholder) where {precision}
    if typeof(val) <: Real
        return sprint_precision(val, Val(precision)) * unit_placeholder
    else
        return "(" * string(val) * ")" * unit_placeholder
    end
end
function format_dimensions(::Nothing)
    return ""
end
function format_dimensions(u)
    if isone(ustrip(u))
        dim = dimension(u)
        if iszero(dim)
            return ""
        else
            return "[" * string(dim) * "]"
        end
    else
        return "[" * string(u) * "]"
    end
end
@generated function sprint_precision(x, ::Val{precision}) where {precision}
    fmt_string = "%.$(precision)g"
    return :(@sprintf($fmt_string, x))
end

"""
    print_tree(tree::AbstractExpressionNode, options::AbstractOptions; kws...)

Print an equation

# Arguments

- `tree::AbstractExpressionNode`: The equation to convert to a string.
- `options::AbstractOptions`: The options holding the definition of operators.
- `variable_names::Union{Array{String, 1}, Nothing}=nothing`: what variables
    to print for each feature.
"""
function DE.print_tree(
    tree::Union{AbstractExpression,AbstractExpressionNode}, options::AbstractOptions; kws...
)
    return DE.print_tree(tree, DE.get_operators(tree, options); kws...)
end
function DE.print_tree(
    io::IO,
    tree::Union{AbstractExpression,AbstractExpressionNode},
    options::AbstractOptions;
    kws...,
)
    return DE.print_tree(io, tree, DE.get_operators(tree, options); kws...)
end

"""
    @extend_operators options

Extends all operators defined in this options object to work on the
`AbstractExpressionNode` type. While by default this is already done for operators defined
in `Base` when you create an options and pass `define_helper_functions=true`,
this does not apply to the user-defined operators. Thus, to do so, you must
apply this macro to the operator enum in the same module you have the operators
defined.
"""
macro extend_operators(options)
    operators = :($(options).operators)
    type_requirements = AbstractOptions
    alias_operators = gensym("alias_operators")
    return quote
        if !isa($(options), $type_requirements)
            error("You must pass an options type to `@extend_operators`.")
        end
        $alias_operators = $define_alias_operators($operators)
        $(DE).@extend_operators $alias_operators
    end |> esc
end
function define_alias_operators(operators)
    # We undo some of the aliases so that the user doesn't need to use, e.g.,
    # `safe_pow(x1, 1.5)`. They can use `x1 ^ 1.5` instead.
    constructor = isa(operators, OperatorEnum) ? OperatorEnum : GenericOperatorEnum
    return constructor(;
        binary_operators=inverse_binopmap.(operators.binops),
        unary_operators=inverse_unaopmap.(operators.unaops),
        define_helper_functions=false,
        empty_old_operators=false,
    )
end

function (tree::Union{AbstractExpression,AbstractExpressionNode})(
    X, options::AbstractOptions; kws...
)
    return tree(
        X,
        DE.get_operators(tree, options);
        turbo=options.turbo,
        bumper=options.bumper,
        kws...,
    )
end
function DE.EvaluationHelpersModule._grad_evaluator(
    tree::Union{AbstractExpression,AbstractExpressionNode},
    X,
    options::AbstractOptions;
    kws...,
)
    return DE.EvaluationHelpersModule._grad_evaluator(
        tree, X, DE.get_operators(tree, options); turbo=options.turbo, kws...
    )
end

# Allows special handling of class columns in MLJInterface.jl
handles_class_column(::Type{<:AbstractExpression}) = false

end
