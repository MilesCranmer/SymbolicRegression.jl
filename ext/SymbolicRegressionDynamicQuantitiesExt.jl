module SymbolicRegressionUnitfulExt

import Tricks: static_hasmethod

if isdefined(Base, :get_extension)
    import DynamicQuantities: Dimensions, Quantity, DimensionError
    import DynamicQuantities: dimension, ustrip, uparse
    import SymbolicRegression: Node, Options, tree_mapreduce
    import SymbolicRegression.CoreModule.DatasetModule: get_units
    import SymbolicRegression.CheckConstraintsModule: violates_dimensional_constraints
else
    import ..DynamicQuantities: Dimensions, Quantity, DimensionError
    import ..DynamicQuantities: dimension, ustrip, uparse
    import ..SymbolicRegression: Node, Options, tree_mapreduce
    import ..SymbolicRegression.CoreModule.DatasetModule: get_units
    import ..SymbolicRegression.CheckConstraintsModule: violates_dimensional_constraints
end

d_eltype(::Dimensions{R}) where {R} = R
const DEFAULT_DIM = Dimensions()
const DEFAULT_DIM_TYPE = d_eltype(DEFAULT_DIM)
q_one(::Type{T}, ::Type{R}) where {T,R} = one(Quantity{T,R})

# https://discourse.julialang.org/t/performance-of-hasmethod-vs-try-catch-on-methoderror/99827/14
# Faster way to catch method errors:
@enum IsGood::Int8 begin
    Good
    Bad
    Undefined
end
const SafeFunctions = Dict{Type,IsGood}()
const SafeFunctionsLock = Threads.SpinLock()

function safe_call(f::F, x::T, default::D) where {F,T<:Tuple,D}
    status = get(SafeFunctions, Tuple{F,T}, Undefined)
    status == Good && return (f(x...)::D, true)
    status == Bad && return (default, false)
    return lock(SafeFunctionsLock) do
        output = try
            (f(x...)::D, true)
        catch e
            !isa(e, MethodError) && rethrow(e)
            (default, false)
        end
        if output[2]
            SafeFunctions[Tuple{F,T}] = Good
        else
            SafeFunctions[Tuple{F,T}] = Bad
        end
        return output
    end
end
macro return_if_good(T, op, inputs)
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
Base.one(::Type{W}) where {T,R,W<:WildcardQuantity{T,R}} = W(q_one(T, R), false, false)
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
            return W(q_one(T, R), false, true)
        end
    end
end
function Base.:^(l::W, r::W)::W where {T,R,W<:WildcardQuantity{T,R}}
    l.violates && return l
    r.violates && return r
    # TODO: Does this need to check for other violations? (See `safe_pow`)
    if has_no_dims(r.val)
        return W(l.val^r.val, l.wildcard, false)
    elseif r.wildcard
        return W(l.val^ustrip(r.val), l.wildcard, false)
    else
        return W(q_one(T, R), false, true)
    end
end

function Base.sqrt(l::W) where {W<:WildcardQuantity}
    return l.violates ? l : W(sqrt(l.val), l.wildcard, false)
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
    !isfinite(l) && return W(q_one(T, R), false, true)

    static_hasmethod(op, Tuple{W}) && @return_if_good(W, op, (l,))
    l.wildcard && return W(Quantity(op(ustrip(l.val))::T, R), false, false)
    return W(q_one(T, R), false, true)
end
@inline function deg2_eval(op::F, l::W, r::W) where {F,T,R,W<:WildcardQuantity{T,R}}
    l.violates && return l
    r.violates && return r
    (!isfinite(l) || !isfinite(r)) && return W(q_one(T, R), false, true)
    static_hasmethod(op, Tuple{W,W}) && @return_if_good(W, op, (l, r))
    static_hasmethod(op, Tuple{T,W}) &&
        l.wildcard &&
        @return_if_good(W, op, (ustrip(l.val), r))
    static_hasmethod(op, Tuple{W,T}) &&
        r.wildcard &&
        @return_if_good(W, op, (l, ustrip(r.val)))
    # TODO: Should this also check for methods that take quantities as input?
    l.wildcard &&
        r.wildcard &&
        return W(Quantity(op(ustrip(l.val), ustrip(r.val))::T, R), false, false)
    return W(q_one(T, R), false, true)
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

#! format: off
get_units(::Type{T}, x::AbstractString) where {T} = convert(Quantity{T,DEFAULT_DIM_TYPE}, uparse(x))
get_units(::Type{T}, x::Quantity) where {T} = convert(Quantity{T,DEFAULT_DIM_TYPE}, x)
get_units(::Type{T}, x::Dimensions) where {T} = convert(Quantity{T,DEFAULT_DIM_TYPE}, 1.0 * x)
get_units(::Type{T}, x::Number) where {T} = Quantity(convert(T, x), DEFAULT_DIM)

get_units(::Type{T}, x::AbstractVector) where {T} = Quantity{T,DEFAULT_DIM_TYPE}[get_units(T, xi) for xi in x]
get_units(::Type{T}, x::NamedTuple) where {T} = NamedTuple((k => get_units(T, x[k]) for k in keys(x)))
#! format: on

end
