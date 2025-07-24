module InterfaceDynamicExpressionsModule

using Printf: @sprintf
using DispatchDoctor: @stable, @unstable
using Compat: Fix
using DynamicExpressions:
    DynamicExpressions as DE,
    AbstractOperatorEnum,
    OperatorEnum,
    GenericOperatorEnum,
    AbstractExpression,
    AbstractExpressionNode,
    Node,
    GraphNode,
    EvalOptions,
    Expression,
    default_node_type
using DynamicQuantities: dimension, ustrip
using ..CoreModule: AbstractOptions, Dataset, AbstractExpressionSpec
using ..CoreModule.OptionsModule: inverse_opmap
using ..CoreModule.ExpressionSpecModule:
    get_expression_type, get_expression_options, get_node_type
using ..UtilsModule: subscriptify

takes_eval_options(::Type{<:AbstractOperatorEnum}) = false
takes_eval_options(::Type{<:OperatorEnum}) = true
takes_eval_options(::T) where {T} = takes_eval_options(T)

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
        options::AbstractOptions;
        turbo=nothing,
        bumper=nothing,
        kws...,
    )
        A = expected_array_type(X, typeof(tree))
        operators = DE.get_operators(tree, options)
        eval_options_kws = if takes_eval_options(operators)
            (;
                eval_options=EvalOptions(;
                    turbo=something(turbo, options.turbo),
                    bumper=something(bumper, options.bumper),
                )
            )
        else
            NamedTuple()
        end
        out, complete = DE.eval_tree_array(tree, X, operators; eval_options_kws..., kws...)
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
function define_alias_operators(
    @nospecialize(operators::Union{OperatorEnum,GenericOperatorEnum})
)
    # We undo some of the aliases so that the user doesn't need to use, e.g.,
    # `safe_pow(x1, 1.5)`. They can use `x1 ^ 1.5` instead.
    constructor = isa(operators, OperatorEnum) ? OperatorEnum : GenericOperatorEnum
    @assert operators.ops isa Tuple{Vararg{Any,2}}
    # TODO: Support for 3-ary operators
    return constructor(;
        binary_operators=map(inverse_opmap, operators.ops[2]),
        unary_operators=map(inverse_opmap, operators.ops[1]),
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

# These functions allow you to declare functions that must be
# passed to worker nodes explicitly. See TemplateExpressions.jl for
# an example. This is used inside Configure.jl.
# COV_EXCL_START
require_copy_to_workers(::Type{<:AbstractExpression}) = false
function make_example_inputs(
    ::Type{<:AbstractExpression}, ::Type{T}, options, dataset
) where {T}
    return error(
        "`make_example_inputs` is not implemented for `$(typeof(options.expression_type))`."
    )
end
# COV_EXCL_STOP

"""
    parse_expression(ex::NamedTuple; kws...)

Extension of `parse_expression` to handle NamedTuple input for creating template expressions.
Each key in the NamedTuple should map to a string expression using #N placeholder syntax.

# Example
```julia
# With expression_spec (recommended for template expressions):
spec = TemplateExpressionSpec(; structure=TemplateStructure{(:f, :g)}(...))
parse_expression((; f="cos(#1) - 1.5", g="exp(#2) - #1"); expression_spec=spec, operators=operators, variable_names=["x1", "x2"])

# Or with explicit parameters:
parse_expression((; f="cos(#1) - 1.5", g="exp(#2) - #1"); expression_type=TemplateExpression, operators=operators, variable_names=["x1", "x2"])
```
"""
@unstable function DE.parse_expression(
    ex::NamedTuple;
    expression_spec::Union{AbstractExpressionSpec,Nothing}=nothing,
    expression_options::Union{NamedTuple,Nothing}=nothing,
    eval_options::Union{EvalOptions,Nothing}=nothing,
    operators::Union{AbstractOperatorEnum,Nothing}=nothing,
    binary_operators::Union{Vector{<:Function},Nothing}=nothing,
    unary_operators::Union{Vector{<:Function},Nothing}=nothing,
    variable_names::Union{AbstractVector,Nothing}=nothing,
    expression_type::Union{Type,Nothing}=nothing,
    node_type::Union{Type,Nothing}=nothing,
    kws...,
)
    if expression_spec !== nothing
        actual_expression_type = get_expression_type(expression_spec)
        actual_expression_options = get_expression_options(expression_spec)
        actual_node_type = get_node_type(expression_spec)
    else
        actual_expression_type = something(expression_type, Expression)
        actual_expression_options = expression_options
        actual_node_type = something(node_type, Node)
    end

    # For TemplateExpression, we need to create the full expression
    if actual_expression_options !== nothing &&
        hasfield(typeof(actual_expression_options), :structure)
        # Parse each sub-expression as Expression objects first, ensuring consistent types
        parsed_expressions = NamedTuple{keys(ex)}(
            map(values(ex)) do expr_str
                # Preprocess #N placeholders to variable names
                processed_str = expr_str
                if variable_names !== nothing
                    for (i, var_name) in enumerate(variable_names)
                        processed_str = replace(processed_str, "#$i" => var_name)
                    end
                end

                DE.parse_expression(
                    Meta.parse(processed_str);  # Need to parse string to Expr first
                    operators=operators,
                    binary_operators=binary_operators,
                    unary_operators=unary_operators,
                    variable_names=variable_names,
                    expression_type=Expression,  # Parse as regular expressions first
                    node_type=actual_node_type,
                    kws...,
                )
            end,
        )

        # Convert to ComposableExpression objects for TemplateExpression
        # We need to access ComposableExpression dynamically since it's loaded after this module
        ComposableExpression =
            getfield(
                parentmodule(@__MODULE__), :ComposableExpressionModule
            ).ComposableExpression

        # Ensure all expressions have the same element type by converting trees to Float64
        # Create eval_options kwargs conditionally
        eval_options_kws = if eval_options !== nothing
            (; eval_options=eval_options)
        else
            NamedTuple()
        end
        inner_expressions = NamedTuple{keys(parsed_expressions)}(
            map(values(parsed_expressions)) do expr
                # Convert node tree to Float64 if it's not already
                tree = if eltype(expr.tree) != Float64
                    convert(Node{Float64}, expr.tree)
                else
                    expr.tree
                end
                ComposableExpression(
                    tree; operators=operators, variable_names=nothing, eval_options_kws...
                )
            end,
        )

        # Create TemplateExpression using the constructor
        return actual_expression_type(
            inner_expressions;
            structure=actual_expression_options.structure,
            operators=operators,
            variable_names=nothing,
            kws...,
        )
    end

    # For non-template expressions or when expression_spec is not provided,
    # parse each expression in the NamedTuple
    parsed_expressions = NamedTuple{keys(ex)}(
        map(values(ex)) do expr_str
            # Preprocess #N placeholders to variable names
            processed_str = expr_str
            if variable_names !== nothing
                for (i, var_name) in enumerate(variable_names)
                    processed_str = replace(processed_str, "#$i" => var_name)
                end
            end

            DE.parse_expression(
                Meta.parse(processed_str);  # Need to parse string to Expr first
                operators=operators,
                binary_operators=binary_operators,
                unary_operators=unary_operators,
                variable_names=variable_names,
                expression_type=actual_expression_type,
                node_type=actual_node_type,
                kws...,
            )
        end,
    )
    return parsed_expressions
end

end
