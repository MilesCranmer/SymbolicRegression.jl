module SymbolicRegressionUnitfulExt

if isdefined(Base, :get_extension)
    import DynamicQuantities: Dimensions, Quantity, valid, dimension, ustrip
    using Unitful: Unitful, uparse, FreeUnits, NoDims
    import SymbolicRegression: Node, Options, tree_mapreduce
    import SymbolicRegression.CoreModule.DatasetModule: get_units
    import SymbolicRegression.CheckConstraintsModule: violates_dimensional_constraints
    import Tricks: static_hasmethod
    import Compat: splat
else
    import ..DynamicQuantities: Dimensions, Quantity, valid, dimension, ustrip
    using ..Unitful: Unitful, uparse, FreeUnits, NoDims
    import ..SymbolicRegression: Node, Options, tree_mapreduce
    import ..SymbolicRegression.CoreModule.DatasetModule: get_units
    import ..SymbolicRegression.CheckConstraintsModule: violates_dimensional_constraints
    import ..Tricks: static_hasmethod
    import ..Compat: splat
end

q_one(T) = Quantity(one(T))

# https://discourse.julialang.org/t/performance-of-hasmethod-vs-try-catch-on-methoderror/99827/14
# Faster way to catch method errors:
struct FuncWrapper{F}
    f::F
end
@inline function safe_call(f::F, x::T, default::D=one(T)) where {F,T,D}
    wrapper = FuncWrapper{F}(f)
    static_hasmethod(wrapper, Tuple{T}) && return wrapper(x)::Tuple{D,Bool}
    output = try
        (f(x), true)
    catch e
        !isa(e, MethodError) && rethrow(e)
        (default, false)
    end
    if output[2]
        @eval (w::FuncWrapper{$F})(x::$T) = (w.f(x), true)
    else
        @eval (::FuncWrapper{$F})(::$T) = ($default, false)
    end
    return output::Tuple{D,Bool}
end
macro return_if_good(T, op, inputs)
    result = gensym()
    successful = gensym()
    quote
        $(result), $(successful) = safe_call(
            splat($(esc(op))), $(esc(inputs)), one($(esc(T)))
        )
        if $(successful) && valid($(result))
            return $(result)
        end
        false
    end
end

"""
    WildcardDimensionWrapper{T}

A wrapper for `Quantity{T}` that allows for a wildcard feature, indicating
there is a free constant whose dimensions are not yet determined.
Also stores a flag indicating whether an expression is dimensionally consistent.
"""
struct WildcardDimensionWrapper{T}
    val::Quantity{T}
    wildcard::Bool
    violates::Bool
end
valid(x::WildcardDimensionWrapper) = (!x.violates) && valid(x.val)
Base.one(::Type{W}) where {T,W<:WildcardDimensionWrapper{T}} = W(q_one(T), false, false)
Base.isfinite(x::WildcardDimensionWrapper) = isfinite(x.val)
same_dimensions(x::Quantity, y::Quantity) = dimension(x) == dimension(y)
has_no_dims(x::Quantity) = iszero(dimension(x))

# Overload *, /, +, -, ^ for WildcardDimensionWrapper, as
# we want wildcards to propagate through these operations.
for op in (:(Base.:*), :(Base.:/))
    @eval function $(op)(l::W, r::W) where {T,W<:WildcardDimensionWrapper{T}}
        l.violates && return l
        r.violates && return r
        return W($(op)(l.val, r.val), l.wildcard || r.wildcard, false)
    end
end
for op in (:(Base.:+), :(Base.:-))
    @eval function $(op)(l::W, r::W)::W where {T,W<:WildcardDimensionWrapper{T}}
        l.violates && return l
        r.violates && return r
        if same_dimensions(l.val, r.val)
            return W($(op)(l.val, r.val), l.wildcard && r.wildcard, false)
        elseif l.wildcard && r.wildcard
            return W(Quantity($(op)(ustrip(l.val), ustrip(r.val))), true, false)
        elseif l.wildcard
            return W($(op)(Quantity(ustrip(l.val), dimension(r.val)), r.val), false, false)
        elseif r.wildcard
            return W($(op)(l.val, Quantity(ustrip(r.val), dimension(l.val))), false, false)
        else
            return W(q_one(T), false, true)
        end
    end
end
function Base.:^(l::W, r::W)::W where {T,W<:WildcardDimensionWrapper{T}}
    l.violates && return l
    r.violates && return r
    # TODO: Does this need to check for other violations? (See `safe_pow`)
    if has_no_dims(r.val)
        return W(l.val^r.val, l.wildcard, false)
    elseif r.wildcard
        return W(l.val^ustrip(r.val), l.wildcard, false)
    else
        return W(q_one(T), false, true)
    end
end

Base.sqrt(l::WildcardDimensionWrapper) = l.violates ? l : W(sqrt(l.val), l.wildcard, false)
Base.cbrt(l::WildcardDimensionWrapper) = l.violates ? l : W(cbrt(l.val), l.wildcard, false)
Base.abs(l::WildcardDimensionWrapper) = l.violates ? l : W(abs(l.val), l.wildcard, false)

# Define dimensionally-aware evaluation routine:
@inline function deg0_eval(
    x::AbstractVector{T}, variable_units, t::Node{T}, ::Type{W}
) where {T,W<:WildcardDimensionWrapper{T}}
    t.constant && return W(Quantity(t.val::T), true, false)
    return W(Quantity(x[t.feature], variable_units[t.feature]), false, false)
end
@inline function deg1_eval(op::F, l::W) where {F,T,W<:WildcardDimensionWrapper{T}}
    l.violates && return l
    !isfinite(l) && return W(q_one(T), false, true)

    static_hasmethod(op, Tuple{W}) && @return_if_good(W, op, (l,))
    l.wildcard && return W(Quantity(op(ustrip(l.val))::T), false, false)
    return W(q_one(T), false, true)
end
@inline function deg2_eval(op::F, l::W, r::W) where {F,T,W<:WildcardDimensionWrapper{T}}
    l.violates && return l
    r.violates && return r
    (!isfinite(l) || !isfinite(r)) && return W(q_one(T), false, true)
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
        return W(Quantity(op(ustrip(l.val), ustrip(r.val))::T), false, false)
    return W(q_one(T), false, true)
end

function violates_dimensional_constraints_dispatch(
    tree::Node{T}, variable_units::AbstractVector, x::AbstractVector{T}, operators
) where {T}
    W = WildcardDimensionWrapper{T}
    if tree.degree == 0
        return deg0_eval(x, variable_units, tree, W)::W
    elseif tree.degree == 1
        l = violates_dimensional_constraints_dispatch(tree.l, variable_units, x, operators)
        return deg1_eval(operators.unaops[tree.op], l)::W
    else
        l = violates_dimensional_constraints_dispatch(tree.l, variable_units, x, operators)
        r = violates_dimensional_constraints_dispatch(tree.r, variable_units, x, operators)
        return deg2_eval(operators.binops[tree.op], l, r)::W
    end
end

function violates_dimensional_constraints(
    tree::Node{T}, variable_units::AbstractVector, x::AbstractVector{T}, options::Options
) where {T}
    # TODO: Should also check against output type.
    return violates_dimensional_constraints_dispatch(
        tree, variable_units, x, options.operators
    ).violates
    # ^ Eventually do this with map_treereduce. However, right now it seems
    # like we are passing around too many arguments, which slows things down.
end

function UnitfulDimensionless()
    return Unitful.FreeUnits{(),NoDims,nothing}()
end
function parse_to_free_unit(xi::AbstractString)
    xi_parsed = uparse(xi)
    isa(xi_parsed, FreeUnits) && return xi_parsed
    return UnitfulDimensionless()
end
parse_to_free_unit(xi::FreeUnits) = xi
parse_to_free_unit(::Number) = UnitfulDimensionless()

unitful_to_dynamic(x::Unitful.Quantity) = dimension(convert(Quantity, x))
unitful_to_dynamic(x::FreeUnits) = unitful_to_dynamic(1.0 * x)

function get_units(x::AbstractVector)
    return Dimensions[unitful_to_dynamic(parse_to_free_unit(xi)) for xi in x]
end

end
