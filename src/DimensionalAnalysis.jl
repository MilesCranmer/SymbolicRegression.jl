module DimensionalAnalysisModule

import DynamicExpressions: Node
import DynamicQuantities: Dimensions, Quantity, DimensionError
import DynamicQuantities: dimension, ustrip, uparse
import Tricks: static_hasmethod

import ..CoreModule: Options, Dataset
import ..CoreModule.OperatorsModule: safe_pow, safe_sqrt
import ..UtilsModule: @maybe_return_call

function safe_sqrt(x::Quantity{T,R})::Quantity{T,R} where {T<:AbstractFloat,R}
    ustrip(x) < 0 && return sqrt(abs(x)) * Quantity(T(NaN), R)
    return sqrt(x)
end

"""
    WildcardQuantity{T}

A wrapper for `Quantity{T,R}` that allows for a wildcard feature, indicating
there is a free constant whose dimensions are not yet determined.
Also stores a flag indicating whether an expression is dimensionally consistent.
"""
struct WildcardQuantity{T,R}
    val::Quantity{T,R}
    wildcard::Bool
    violates::Bool
end

valid(x::WildcardQuantity) = !x.violates
function Base.one(::Type{W}) where {T,R,W<:WildcardQuantity{T,R}}
    return W(one(Quantity{T,R}), false, false)
end
Base.isfinite(w::WildcardQuantity) = isfinite(w.val)
dimension(w::WildcardQuantity) = dimension(w.val)
same_dimensions(x::WildcardQuantity, y::WildcardQuantity) = dimension(x) == dimension(y)
has_no_dims(x::Quantity) = iszero(dimension(x))

# Overload *, /, +, -, ^ for WildcardQuantity, as
# we want wildcards to propagate through these operations.
for op in (:(Base.:*), :(Base.:/))
    @eval function $(op)(l::W, r::W) where {T,R,W<:WildcardQuantity{T,R}}
        l.violates && return l
        r.violates && return r
        return W($(op)(l.val, r.val), l.wildcard || r.wildcard, false)
    end
end
for op in (:(Base.:+), :(Base.:-))
    @eval function $(op)(l::W, r::W)::W where {T,R,W<:WildcardQuantity{T,R}}
        l.violates && return l
        r.violates && return r
        if same_dimensions(l, r)
            return W($(op)(l.val, r.val), l.wildcard && r.wildcard, false)
        elseif l.wildcard && r.wildcard
            return W(Quantity($(op)(ustrip(l.val), ustrip(r.val)), R), true, false)
        elseif l.wildcard
            return W($(op)(Quantity(ustrip(l.val), dimension(r.val)), r.val), false, false)
        elseif r.wildcard
            return W($(op)(l.val, Quantity(ustrip(r.val), dimension(l.val))), false, false)
        else
            return W(one(Quantity{T,R}), false, true)
        end
    end
end
function Base.:^(l::W, r::W)::W where {T,R,W<:WildcardQuantity{T,R}}
    l.violates && return l
    r.violates && return r
    if (has_no_dims(l.val) || l.wildcard) && (has_no_dims(r.val) || r.wildcard)
        # Require both base and power to be dimensionless:
        x = ustrip(l.val)
        y = ustrip(r.val)
        return W(safe_pow(x, y) * one(Quantity{T,R}), false, false)
    else
        return W(one(Quantity{T,R}), false, true)
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

# Define dimensionally-aware evaluation routine:
@inline function deg0_eval(
    x::AbstractVector{T}, x_units::Vector{Quantity{T,R}}, t::Node{T}
) where {T,R}
    t.constant && return WildcardQuantity{T,R}(Quantity(t.val::T, R), true, false)
    return WildcardQuantity{T,R}(
        (@inbounds x[t.feature]) * (@inbounds x_units[t.feature]), false, false
    )
end
@inline function deg1_eval(op::F, l::W) where {F,T,R,W<:WildcardQuantity{T,R}}
    l.violates && return l
    !isfinite(l) && return W(one(Quantity{T,R}), false, true)

    static_hasmethod(op, Tuple{W}) && @maybe_return_call(W, op, (l,))
    l.wildcard && return W(Quantity(op(ustrip(l.val))::T, R), false, false)
    return W(one(Quantity{T,R}), false, true)
end
@inline function deg2_eval(op::F, l::W, r::W) where {F,T,R,W<:WildcardQuantity{T,R}}
    l.violates && return l
    r.violates && return r
    (!isfinite(l) || !isfinite(r)) && return W(one(Quantity{T,R}), false, true)
    static_hasmethod(op, Tuple{W,W}) && @maybe_return_call(W, op, (l, r))
    static_hasmethod(op, Tuple{T,W}) &&
        l.wildcard &&
        @maybe_return_call(W, op, (ustrip(l.val), r))
    static_hasmethod(op, Tuple{W,T}) &&
        r.wildcard &&
        @maybe_return_call(W, op, (l, ustrip(r.val)))
    # TODO: Should this also check for methods that take quantities as input?
    l.wildcard &&
        r.wildcard &&
        return W(Quantity(op(ustrip(l.val), ustrip(r.val))::T, R), false, false)
    return W(one(Quantity{T,R}), false, true)
end

function violates_dimensional_constraints_dispatch(
    tree::Node{T}, x_units::Vector{Quantity{T,R}}, x::AbstractVector{T}, operators
) where {T,R}
    if tree.degree == 0
        return deg0_eval(x, x_units, tree)::WildcardQuantity{T,R}
    elseif tree.degree == 1
        l = violates_dimensional_constraints_dispatch(tree.l, x_units, x, operators)
        return deg1_eval((@inbounds operators.unaops[tree.op]), l)::WildcardQuantity{T,R}
    else
        l = violates_dimensional_constraints_dispatch(tree.l, x_units, x, operators)
        r = violates_dimensional_constraints_dispatch(tree.r, x_units, x, operators)
        return deg2_eval((@inbounds operators.binops[tree.op]), l, r)::WildcardQuantity{T,R}
    end
end

"""
    violates_dimensional_constraints(tree::Node, dataset::Dataset, options::Options)

Checks whether an expression violates dimensional constraints.
"""
function violates_dimensional_constraints(tree::Node, dataset::Dataset, options::Options)
    X = dataset.X
    return violates_dimensional_constraints(tree, dataset.units, (@view X[:, 1]), options)
end
function violates_dimensional_constraints(_, ::Nothing, _, _)
    return false
end
function violates_dimensional_constraints(
    tree::Node{T}, units::NamedTuple, x::AbstractVector{T}, options::Options
) where {T}
    # TODO: Should also check against output type.
    dimensional_output = violates_dimensional_constraints_dispatch(
        tree, units.X, x, options.operators
    )
    return dimensional_output.violates || (
        !dimensional_output.wildcard && dimension(dimensional_output) != dimension(units.y)
    )
    # ^ Eventually do this with map_treereduce. However, right now it seems
    # like we are passing around too many arguments, which slows things down.
end

end
