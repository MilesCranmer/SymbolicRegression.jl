module ComposableExpressionModule

using Compat: Fix
using DispatchDoctor: @unstable
using ForwardDiff: ForwardDiff
using DynamicExpressions:
    AbstractExpression,
    Expression,
    AbstractExpressionNode,
    AbstractOperatorEnum,
    OperatorEnum,
    Metadata,
    constructorof,
    get_metadata,
    eval_tree_array,
    set_node!,
    get_contents,
    with_contents,
    with_metadata,
    DynamicExpressions as DE
using DynamicExpressions.InterfacesModule:
    ExpressionInterface, Interfaces, @implements, all_ei_methods_except, Arguments
using DynamicExpressions.ValueInterfaceModule: is_valid_array

using ..ConstantOptimizationModule: ConstantOptimizationModule as CO
using ..CoreModule: get_safe_op

abstract type AbstractComposableExpression{T,N} <: AbstractExpression{T,N} end

"""
    ComposableExpression{T,N,D} <: AbstractComposableExpression{T,N} <: AbstractExpression{T,N}

A symbolic expression representing a mathematical formula as an expression tree (`tree::N`) with associated metadata (`metadata::Metadata{D}`). Used to construct and manipulate expressions in symbolic regression tasks.

Example:

Create variables `x1` and `x2`, and build an expression `f = x1 * sin(x2)`:

```julia
operators = OperatorEnum(; binary_operators=(+, *, /, -), unary_operators=(sin, cos))
variable_names = ["x1", "x2"]
x1 = ComposableExpression(Node(Float64; feature=1); operators, variable_names)
x2 = ComposableExpression(Node(Float64; feature=2); operators, variable_names)
f = x1 * sin(x2)
# ^This now references the first and second arguments of things passed to it:

f(x1, x1) # == x1 * sin(x1)
f(randn(5), randn(5)) # == randn(5) .* sin.(randn(5))

# You can even pass it to itself:
f(f, f) # == (x1 * sin(x2)) * sin((x1 * sin(x2)))
```
"""
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

"""
    ValidVector{A<:AbstractVector}

A wrapper for an AbstractVector paired with a validity flag (valid::Bool).
It represents a vector along with a boolean indicating whether the data is valid.
This is useful in computations where certain operations might produce invalid data
(e.g., division by zero), allowing the validity to propagate through calculations.
Operations on `ValidVector` instances automatically handle the valid flag: if all
operands are valid, the result is valid; if any operand is invalid, the result is
marked invalid.

You will need to work with this to do highly custom operations with
`ComposableExpression` and `TemplateExpression`.

# Fields:

- `x::A`: The vector data.
- `valid::Bool`: Indicates if the data is valid.
"""
struct ValidVector{A<:AbstractVector}
    x::A
    valid::Bool
end
ValidVector(x::Tuple{Vararg{Any,2}}) = ValidVector(x...)

function (ex::AbstractComposableExpression)(x)
    return error("ComposableExpression does not support input of type $(typeof(x))")
end
function (ex::AbstractComposableExpression)(
    x::AbstractVector, _xs::Vararg{AbstractVector,N}
) where {N}
    __xs = (x, _xs...)
    # Wrap it up for the recursive call
    xs = map(Base.Fix2(ValidVector, true), __xs)
    result = ex(xs...)
    # Unwrap it
    if _is_valid(result)
        return _get_value(result)
    else
        # TODO: Make this more general. Like checking if the eltype is numeric.
        x = _get_value(result)
        nan = convert(eltype(x), NaN)
        return x .* nan
    end
end
function (ex::AbstractComposableExpression)(
    x::ValidVector, _xs::Vararg{ValidVector,N}
) where {N}
    xs = (x, _xs...)
    valid = all(_is_valid, xs)
    if !valid
        return ValidVector(_get_value(first(xs)), false)
    else
        X = Matrix(stack(map(_get_value, xs))')
        return ValidVector(eval_tree_array(ex, X))
    end
end
function (ex::AbstractComposableExpression{T})() where {T}
    X = Matrix{T}(undef, 0, 1)  # Value is irrelevant as it won't be used
    out, _ = eval_tree_array(ex, X)  # TODO: The valid is not used; not sure how to incorporate
    return only(out)::T
end
function (ex::AbstractComposableExpression)(
    x::AbstractComposableExpression, _xs::Vararg{AbstractComposableExpression,N}
) where {N}
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

# Basically we want to vectorize every single operation on ValidVector,
# so that the user can use it easily.

function apply_operator(op::F, x::Vararg{Any,N}) where {F<:Function,N}
    if all(_is_valid, x)
        vx = map(_get_value, x)
        safe_op = get_safe_op(op)
        result = safe_op.(vx...)
        return ValidVector(result, is_valid_array(result))
    else
        example_vector =
            something(map(xi -> xi isa ValidVector ? xi : nothing, x)...)::ValidVector
        return ValidVector(_get_value(example_vector), false)
    end
end
_is_valid(x::ValidVector) = x.valid
_is_valid(x) = true
_get_value(x::ValidVector) = x.x
_get_value(x) = x

#! format: off
# First, binary operators:
for op in (
    :*, :/, :+, :-, :^, :÷, :mod, :log,
    :atan, :atand, :copysign, :flipsign,
    :&, :|, :⊻, ://, :\,
)
    @eval begin
        Base.$(op)(x::ValidVector, y::ValidVector) = apply_operator(Base.$(op), x, y)
        Base.$(op)(x::ValidVector, y::Number) = apply_operator(Base.$(op), x, y)
        Base.$(op)(x::Number, y::ValidVector) = apply_operator(Base.$(op), x, y)
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
    @eval Base.$(op)(x::ValidVector) = apply_operator(Base.$(op), x)
end
#! format: on

Base.@enum ConstantDerivative::UInt8 Zero One NegOne Other

"""
    D(ex::AbstractComposableExpression, feature::Integer)

Compute the derivative of `ex` with respect to the `feature`-th variable.
Returns a new `ComposableExpression` with an expanded set of operators.
"""
function D(ex::AbstractComposableExpression, feature::Integer)
    metadata = DE.get_metadata(ex)
    raw_metadata = getfield(metadata, :_data)  # TODO: Upstream this so we can load this
    operators = DE.get_operators(ex)
    mult_idx = findfirst(==(*), operators.binops)::Integer
    plus_idx = findfirst(==(+), operators.binops)::Integer
    nbin = length(operators.binops)
    nuna = length(operators.unaops)
    tree = DE.get_contents(ex)
    operators_with_derivatives = _expand_operators(operators)
    evaluates_to_constant = map(
        op -> if op == _zero
            Zero
        elseif op == _one
            One
        elseif op == _n_one
            NegOne
        else
            Other
        end, operators_with_derivatives.binops
    )
    ctx = SymbolicDerivativeContext(;
        feature, plus_idx, mult_idx, nbin, nuna, evaluates_to_constant
    )
    d_tree = _symbolic_derivative(tree, ctx)
    return with_metadata(
        with_contents(ex, d_tree); raw_metadata..., operators=operators_with_derivatives
    )
end

Base.@kwdef struct SymbolicDerivativeContext{TUP}
    feature::Int
    plus_idx::Int
    mult_idx::Int
    nbin::Int
    nuna::Int
    evaluates_to_constant::TUP
end

function _symbolic_derivative(
    tree::N, ctx::SymbolicDerivativeContext
) where {T,N<:AbstractExpressionNode{T}}
    # NOTE: We cannot mutate the tree here! Since we use it twice.

    # Quick test to see if we have any dependence on the feature, so
    # we can return 0 for the branch
    any_dependence = any(tree) do node
        node.degree == 0 && !node.constant && node.feature == ctx.feature
    end

    if !any_dependence
        return constructorof(N)(; val=zero(T))
    elseif tree.degree == 0 # && any_dependence
        return constructorof(N)(; val=one(T))
    elseif tree.degree == 1
        # f(g(x)) => f'(g(x)) * g'(x)
        f_prime_op = tree.op + ctx.nuna

        ### We do some simplification based on zero/one derivatives ###
        g_prime = _symbolic_derivative(tree.l, ctx)
        if g_prime.degree == 0 && g_prime.constant && iszero(g_prime.val)
            return g_prime
        else
            f_prime = constructorof(N)(; op=f_prime_op, l=tree.l)

            if g_prime.degree == 0 && g_prime.constant && isone(g_prime.val)
                return f_prime
            else
                return constructorof(N)(; op=ctx.mult_idx, l=f_prime, r=g_prime)
            end
        end
    else  # tree.degree == 2
        # f(g(x), h(x)) => f^(1,0)(g(x), h(x)) * g'(x) + f^(0,1)(g(x), h(x)) * h'(x)
        f_prime_left_op = tree.op + ctx.nbin
        f_prime_right_op = tree.op + 2 * ctx.nbin
        f_prime_left_evaluates_to = ctx.evaluates_to_constant[f_prime_left_op]
        f_prime_right_evaluates_to = ctx.evaluates_to_constant[f_prime_right_op]

        ### We do some simplification based on zero/one derivatives ###
        first_term = if f_prime_left_evaluates_to == Zero

            # Simplify and just give zero
            constructorof(N)(; val=zero(T))
        else
            g_prime = _symbolic_derivative(tree.l, ctx)

            if f_prime_left_evaluates_to == One ||
                (g_prime.degree == 0 && g_prime.constant && iszero(g_prime.val))
                # Simplify and just give g_prime
                g_prime
            else
                f_prime_left = if f_prime_left_evaluates_to == NegOne
                    constructorof(N)(; val=-one(T))
                else
                    constructorof(N)(; op=f_prime_left_op, l=tree.l, r=tree.r)
                end

                if g_prime.degree == 0 && g_prime.constant && isone(g_prime.val)
                    f_prime_left
                else
                    constructorof(N)(; op=ctx.mult_idx, l=f_prime_left, r=g_prime)
                end
            end
        end

        second_term = if f_prime_right_evaluates_to == Zero
            # Simplify and just give zero
            constructorof(N)(; val=zero(T))
        else
            h_prime = _symbolic_derivative(tree.r, ctx)
            if f_prime_right_evaluates_to == One ||
                (h_prime.degree == 0 && h_prime.constant && iszero(h_prime.val))
                # Simplify and just give h_prime
                h_prime
            else
                f_prime_right = if f_prime_right_evaluates_to == NegOne
                    constructorof(N)(; val=-one(T))
                else
                    constructorof(N)(; op=f_prime_right_op, l=tree.l, r=tree.r)
                end
                if h_prime.degree == 0 && h_prime.constant && isone(h_prime.val)
                    f_prime_right
                else
                    constructorof(N)(; op=ctx.mult_idx, l=f_prime_right, r=h_prime)
                end
            end
        end

        # Simplify if either term is zero
        if first_term.degree == 0 && first_term.constant && iszero(first_term.val)
            return second_term
        elseif second_term.degree == 0 && second_term.constant && iszero(second_term.val)
            return first_term
        else
            return constructorof(N)(; op=ctx.plus_idx, l=first_term, r=second_term)
        end
    end
end

struct OperatorDerivative{F,degree,arg} <: Function
    op::F
end

function Base.show(io::IO, g::OperatorDerivative{F,degree,arg}) where {F,degree,arg}
    print(io, "∂")
    if degree == 2
        if arg == 1
            print(io, "₁")
        elseif arg == 2
            print(io, "₂")
        end
    end
    print(io, g.op)
    return nothing
end
Base.show(io::IO, ::MIME"text/plain", g::OperatorDerivative) = show(io, g)

# Generic derivatives:
function (d::OperatorDerivative{F,1,1})(x) where {F}
    return ForwardDiff.derivative(d.op, x)
end
function (d::OperatorDerivative{F,2,1})(x, y) where {F}
    return ForwardDiff.derivative(Fix{2}(d.op, y), x)
end
function (d::OperatorDerivative{F,2,2})(x, y) where {F}
    return ForwardDiff.derivative(Fix{1}(d.op, x), y)
end
function operator_derivative(op::F, ::Val{degree}, ::Val{arg}) where {F,degree,arg}
    return OperatorDerivative{F,degree,arg}(op)
end

#! format: off
# Special Cases
## Unary
operator_derivative(::typeof(sin), ::Val{1}, ::Val{1}) = cos
operator_derivative(::typeof(cos), ::Val{1}, ::Val{1}) = (-) ∘ sin
operator_derivative(::typeof((-) ∘ sin), ::Val{1}, ::Val{1}) = (-) ∘ cos
operator_derivative(::typeof((-) ∘ cos), ::Val{1}, ::Val{1}) = sin
operator_derivative(::typeof(exp), ::Val{1}, ::Val{1}) = exp

## Binary
# TODO: We assume that left/right are symmetric here!
_zero(x, _) = zero(x)
_one(x, _) = one(x)
_n_one(x, _) = -one(x)
operator_derivative(::typeof(_zero), ::Val{2}, ::Val{1}) = _zero
operator_derivative(::typeof(_zero), ::Val{2}, ::Val{2}) = _zero
operator_derivative(::typeof(_one), ::Val{2}, ::Val{1}) = _zero
operator_derivative(::typeof(_one), ::Val{2}, ::Val{2}) = _zero
operator_derivative(::typeof(_n_one), ::Val{2}, ::Val{1}) = _zero
operator_derivative(::typeof(_n_one), ::Val{2}, ::Val{2}) = _zero

### Addition
operator_derivative(::typeof(+), ::Val{2}, ::Val{1}) = _one
operator_derivative(::typeof(+), ::Val{2}, ::Val{2}) = _one
operator_derivative(::typeof(-), ::Val{2}, ::Val{1}) = _one
operator_derivative(::typeof(-), ::Val{2}, ::Val{2}) = _n_one

### Multiplication
operator_derivative(::typeof(*), ::Val{2}, ::Val{1}) = last ∘ tuple
operator_derivative(::typeof(*), ::Val{2}, ::Val{2}) = first ∘ tuple
operator_derivative(::typeof(first ∘ tuple), ::Val{2}, ::Val{1}) = _one
operator_derivative(::typeof(first ∘ tuple), ::Val{2}, ::Val{2}) = _zero
operator_derivative(::typeof(last ∘ tuple), ::Val{2}, ::Val{1}) = _zero
operator_derivative(::typeof(last ∘ tuple), ::Val{2}, ::Val{2}) = _one

### Division
struct DivMonomial{C,XP,YNP} <: Function end
function (m::DivMonomial{C,XP,YNP})(x, y) where {C,XP,YNP}
    return C * (XP == 0 ? one(x) : x^XP) / (y^YNP)
end
operator_derivative(::typeof(/), ::Val{2}, ::Val{1}) = DivMonomial{1,0,1}()
operator_derivative(::typeof(/), ::Val{2}, ::Val{2}) = DivMonomial{-1,1,2}()
operator_derivative(::DivMonomial{C,XP,YNP}, ::Val{2}, ::Val{1}) where {C,XP,YNP} =
    iszero(XP) ? _zero : DivMonomial{C * XP,XP - 1,YNP}()
operator_derivative(::DivMonomial{C,XP,YNP}, ::Val{2}, ::Val{2}) where {C,XP,YNP} =
    DivMonomial{-C * YNP,XP,YNP + 1}()
#! format: on

DE.get_op_name(::typeof(first ∘ tuple)) = "first"
DE.get_op_name(::typeof(last ∘ tuple)) = "last"
DE.get_op_name(::typeof((-) ∘ sin)) = "-sin"
DE.get_op_name(::typeof((-) ∘ cos)) = "-cos"

function DE.get_op_name(::DivMonomial{C,XP,YNP}) where {C,XP,YNP}
    return join(("((x, y) -> ", string(C), "x^", string(XP), "/y^", string(YNP), ")"))
end

function _expand_operators(operators::OperatorEnum)
    unaops = operators.unaops
    binops = operators.binops
    new_unaops = ntuple(
        i -> if i <= length(unaops)
            unaops[i]
        else
            operator_derivative(unaops[i - length(unaops)], Val(1), Val(1))
        end,
        Val(2 * length(unaops)),
    )
    new_binops = ntuple(
        i -> if i <= length(binops)
            binops[i]
        elseif i <= 2 * length(binops)
            operator_derivative(binops[i - length(binops)], Val(2), Val(1))
        else
            operator_derivative(binops[i - 2 * length(binops)], Val(2), Val(2))
        end,
        Val(3 * length(binops)),
    )
    return OperatorEnum(new_binops, new_unaops)
end

end
