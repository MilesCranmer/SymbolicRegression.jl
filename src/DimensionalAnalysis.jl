module DimensionalAnalysisModule

using DynamicExpressions: AbstractExpression, AbstractExpressionNode, get_tree
using DynamicQuantities: Quantity, DimensionError, AbstractQuantity, constructorof
using BorrowChecker: @&, @take

using ..CoreModule: AbstractOptions, Dataset
using ..UtilsModule: safe_call

import DynamicQuantities: dimension, ustrip
import ..CoreModule.OperatorsModule: safe_pow, safe_sqrt

"""
    @maybe_return_call(T, op, (args...))

Basically, we try to evaluate the operator. If
the method is defined AND there is no dimension error,
we return. Otherwise, continue.
"""
macro maybe_return_call(T, op, inputs)
    result = gensym()
    successful = gensym()
    quote
        try
            $(result), $(successful) = safe_call($(esc(op)), $(esc(inputs)), one($(esc(T))))
            $(successful) && valid($(result)) && return $(result)
        catch e
            !isa(e, DimensionError) && rethrow(e)
        end
        false
    end
end

function safe_sqrt(x::Q) where {T,Q<:AbstractQuantity{T}}
    ustrip(x) < 0 && return sqrt(abs(x)) * T(NaN)
    return sqrt(x)
end

"""
    WildcardQuantity{Q<:AbstractQuantity}

A wrapper for a `AbstractQuantity` that allows for a wildcard feature, indicating
there is a free constant whose dimensions are not yet determined.
Also stores a flag indicating whether an expression is dimensionally consistent.
"""
struct WildcardQuantity{Q<:AbstractQuantity}
    val::Q
    wildcard::Bool
    violates::Bool
end

ustrip(w::WildcardQuantity) = ustrip(w.val)
dimension(w::WildcardQuantity) = dimension(w.val)
valid(x::WildcardQuantity) = !x.violates

Base.one(::Type{W}) where {Q,W<:WildcardQuantity{Q}} = return W(one(Q), false, false)
Base.isfinite(w::WildcardQuantity) = isfinite(w.val)

same_dimensions(x::WildcardQuantity, y::WildcardQuantity) = dimension(x) == dimension(y)
has_no_dims(x::Quantity) = iszero(dimension(x))

# Overload *, /, +, -, ^ for WildcardQuantity, as
# we want wildcards to propagate through these operations.
for op in (:(Base.:*), :(Base.:/))
    @eval function $(op)(l::W, r::W) where {W<:WildcardQuantity}
        l.violates && return l
        r.violates && return r
        return W($(op)(l.val, r.val), l.wildcard || r.wildcard, false)
    end
end
for op in (:(Base.:+), :(Base.:-))
    @eval function $(op)(l::W, r::W) where {Q,W<:WildcardQuantity{Q}}
        l.violates && return l
        r.violates && return r
        if same_dimensions(l, r)
            return W($(op)(l.val, r.val), l.wildcard && r.wildcard, false)
        elseif l.wildcard && r.wildcard
            return W(
                constructorof(Q)($(op)(ustrip(l), ustrip(r)), typeof(dimension(l))),
                true,
                false,
            )
        elseif l.wildcard
            return W($(op)(constructorof(Q)(ustrip(l), dimension(r)), r.val), false, false)
        elseif r.wildcard
            return W($(op)(l.val, constructorof(Q)(ustrip(r), dimension(l))), false, false)
        else
            return W(one(Q), false, true)
        end
    end
end
function Base.:^(l::W, r::W) where {Q,W<:WildcardQuantity{Q}}
    l.violates && return l
    r.violates && return r
    if (has_no_dims(l.val) || l.wildcard) && (has_no_dims(r.val) || r.wildcard)
        # Require both base and power to be dimensionless:
        x = ustrip(l)
        y = ustrip(r)
        return W(safe_pow(x, y) * one(Q), false, false)
    else
        return W(one(Q), false, true)
    end
end

function Base.sqrt(l::W) where {W<:WildcardQuantity}
    return l.violates ? l : W(safe_sqrt(l.val), l.wildcard, false)
end
function Base.cbrt(l::W) where {W<:WildcardQuantity}
    return l.violates ? l : W(cbrt(l.val), l.wildcard, false)
end
function Base.abs(l::W) where {W<:WildcardQuantity}
    return l.violates ? l : W(abs(l.val), l.wildcard, false)
end
function Base.inv(l::W) where {W<:WildcardQuantity}
    return l.violates ? l : W(inv(l.val), l.wildcard, false)
end

# Define dimensionally-aware evaluation routine:
@inline function deg0_eval(
    x::AbstractVector{T},
    x_units::Vector{Q},
    t::AbstractExpressionNode{T},
    allow_wildcards::Bool,
) where {T,R,Q<:AbstractQuantity{T,R}}
    if t.constant
        return WildcardQuantity{Q}(Quantity(t.val, R), allow_wildcards, false)
    else
        return WildcardQuantity{Q}(
            (@inbounds x[t.feature]) * (@inbounds x_units[t.feature]), false, false
        )
    end
end
@inline function deg1_eval(
    op::F, l::W
) where {F,T,Q<:AbstractQuantity{T},W<:WildcardQuantity{Q}}
    l.violates && return l
    !isfinite(l) && return W(one(Q), false, true)

    hasmethod(op, Tuple{W}) && @maybe_return_call(W, op, (l,))
    l.wildcard && return W(Quantity(op(ustrip(l))::T), false, false)
    return W(one(Q), false, true)
end
@inline function deg2_eval(
    op::F, l::W, r::W
) where {F,T,Q<:AbstractQuantity{T},W<:WildcardQuantity{Q}}
    l.violates && return l
    r.violates && return r
    (!isfinite(l) || !isfinite(r)) && return W(one(Q), false, true)
    hasmethod(op, Tuple{W,W}) && @maybe_return_call(W, op, (l, r))
    hasmethod(op, Tuple{T,W}) && l.wildcard && @maybe_return_call(W, op, (ustrip(l), r))
    hasmethod(op, Tuple{W,T}) && r.wildcard && @maybe_return_call(W, op, (l, ustrip(r)))
    l.wildcard &&
        r.wildcard &&
        return W(Quantity(op(ustrip(l), ustrip(r))::T), false, false)
    return W(one(Q), false, true)
end

function violates_dimensional_constraints_dispatch(
    tree::AbstractExpressionNode{T},
    x_units::Vector{Q},
    x::AbstractVector{T},
    operators,
    allow_wildcards,
) where {T,Q<:AbstractQuantity{T}}
    if tree.degree == 0
        return deg0_eval(x, x_units, tree, allow_wildcards)::WildcardQuantity{Q}
    elseif tree.degree == 1
        l = violates_dimensional_constraints_dispatch(
            tree.l, x_units, x, operators, allow_wildcards
        )
        return deg1_eval((@inbounds operators.unaops[tree.op]), l)::WildcardQuantity{Q}
    else
        l = violates_dimensional_constraints_dispatch(
            tree.l, x_units, x, operators, allow_wildcards
        )
        r = violates_dimensional_constraints_dispatch(
            tree.r, x_units, x, operators, allow_wildcards
        )
        return deg2_eval((@inbounds operators.binops[tree.op]), l, r)::WildcardQuantity{Q}
    end
end

"""
    violates_dimensional_constraints(tree::AbstractExpressionNode, dataset::Dataset, options::@&(AbstractOptions))

Checks whether an expression violates dimensional constraints.
"""
function violates_dimensional_constraints(
    tree::AbstractExpressionNode, dataset::Dataset, options::@&(AbstractOptions)
)
    X = dataset.X
    return violates_dimensional_constraints(
        tree, dataset.X_units, dataset.y_units, (@view X[:, 1]), options
    )
end
function violates_dimensional_constraints(
    tree::AbstractExpression, dataset::Dataset, options::@&(AbstractOptions)
)
    return violates_dimensional_constraints(get_tree(tree), dataset, options)
end
function violates_dimensional_constraints(
    tree::AbstractExpressionNode{T},
    X_units::AbstractVector{<:Quantity},
    y_units::Union{Quantity,Nothing},
    x::AbstractVector{T},
    options::@&(AbstractOptions),
) where {T}
    allow_wildcards = !(options.dimensionless_constants_only)
    dimensional_output = violates_dimensional_constraints_dispatch(
        tree, X_units, x, options.operators, allow_wildcards
    )
    # ^ Eventually do this with map_treereduce. However, right now it seems
    # like we are passing around too many arguments, which slows things down.
    violates = dimensional_output.violates
    if y_units !== nothing
        violates |= (
            !dimensional_output.wildcard &&
            dimension(dimensional_output) != dimension(y_units)
        )
    end
    return violates
end
function violates_dimensional_constraints(
    ::AbstractExpressionNode{T},
    ::Nothing,
    ::Quantity,
    ::AbstractVector{T},
    ::@&(AbstractOptions),
) where {T}
    return error("This should never happen. Please submit a bug report.")
end
function violates_dimensional_constraints(
    ::AbstractExpressionNode{T},
    ::Nothing,
    ::Nothing,
    ::AbstractVector{T},
    ::@&(AbstractOptions),
) where {T}
    return false
end

end
