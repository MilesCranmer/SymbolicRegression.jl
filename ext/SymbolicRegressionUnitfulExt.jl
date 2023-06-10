module SymbolicRegressionUnitfulExt

if isdefined(Base, :get_extension)
    import DynamicQuantities: Dimensions, Quantity, dimension, ustrip
    using Unitful: Unitful, uparse, FreeUnits, NoDims
    import SymbolicRegression: Node, Options, tree_mapreduce
    import SymbolicRegression.CoreModule.DatasetModule: get_units
    import SymbolicRegression.CheckConstraintsModule: violates_dimensional_constraints
    import Tricks: static_hasmethod
    import Compat: splat
else
    import ..DynamicQuantities: Dimensions, Quantity, dimension, ustrip
    using ..Unitful: Unitful, uparse, FreeUnits, NoDims
    import ..SymbolicRegression: Node, Options, tree_mapreduce
    import ..SymbolicRegression.CoreModule.DatasetModule: get_units
    import ..SymbolicRegression.CheckConstraintsModule: violates_dimensional_constraints
    import ..Tricks: static_hasmethod
    import ..Compat: splat
end

d_eltype(d::Dimensions{R}) where {R} = R
const DEFAULT_DIM_TYPE = d_eltype(Dimensions())
q_one(T) = Quantity(one(T), DEFAULT_DIM_TYPE)

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
    WildcardQuantity{T}

A wrapper for `Quantity{T,R}` that allows for a wildcard feature, indicating
there is a free constant whose dimensions are not yet determined.
Also stores a flag indicating whether an expression is dimensionally consistent.
"""
struct WildcardQuantity{T,R}
    val::Quantity{T,R}
    wildcard::Bool
    violates::Bool

    global function unsafe_wildcard_quantity(
        ::Type{_T}, ::Type{_R}, val, w, vio
    ) where {_T,_R}
        return new{_T,_R}(val, w, vio)
    end
end

function (::Type{W})(
    v::Quantity{T2,R2}, wildcard::Bool, violates::Bool
) where {T,R,W<:WildcardQuantity{T,R},T2,R2}
    @assert T2 == T "Found unmatched types $(typeof(v)) != $(W) because $(T2) != $(T)"
    @assert R == R2 "Found unmatched types $(typeof(v)) != $(W) because $(R2) != $(R)"
    return unsafe_wildcard_quantity(T, R, v, wildcard, violates)
end
valid(x::WildcardQuantity) = !x.violates
Base.one(::Type{W}) where {T,R,W<:WildcardQuantity{T,R}} = W(q_one(T), false, false)
Base.isfinite(x::WildcardQuantity) = isfinite(x.val)
same_dimensions(x::Quantity, y::Quantity) = dimension(x) == dimension(y)
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
        if same_dimensions(l.val, r.val)
            return W($(op)(l.val, r.val), l.wildcard && r.wildcard, false)
        elseif l.wildcard && r.wildcard
            return W(
                Quantity($(op)(ustrip(l.val), ustrip(r.val)), DEFAULT_DIM_TYPE), true, false
            )
        elseif l.wildcard
            return W(
                $(op)(Quantity(ustrip(l.val), dimension(r.val), DEFAULT_DIM_TYPE), r.val),
                false,
                false,
            )
        elseif r.wildcard
            return W($(op)(l.val, Quantity(ustrip(r.val), dimension(l.val))), false, false)
        else
            return W(q_one(T), false, true)
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
        return W(q_one(T), false, true)
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
    x::AbstractVector{T}, variable_units, t::Node{T}, ::Type{W}
) where {T,R,W<:WildcardQuantity{T,R}}
    t.constant && return W(Quantity(t.val::T, DEFAULT_DIM_TYPE), true, false)
    return W(
        Quantity((@inbounds x[t.feature]), (@inbounds variable_units[t.feature])),
        false,
        false,
    )
end
@inline function deg1_eval(op::F, l::W) where {F,T,R,W<:WildcardQuantity{T,R}}
    l.violates && return l
    !isfinite(l) && return W(q_one(T), false, true)

    static_hasmethod(op, Tuple{W}) && @return_if_good(W, op, (l,))
    l.wildcard && return W(Quantity(op(ustrip(l.val))::T, DEFAULT_DIM_TYPE), false, false)
    return W(q_one(T), false, true)
end
@inline function deg2_eval(op::F, l::W, r::W) where {F,T,R,W<:WildcardQuantity{T,R}}
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
        return W(
            Quantity(op(ustrip(l.val), ustrip(r.val))::T, DEFAULT_DIM_TYPE), false, false
        )
    return W(q_one(T), false, true)
end

function violates_dimensional_constraints_dispatch(
    tree::Node{T}, variable_units::AbstractVector, x::AbstractVector{T}, operators
) where {T}
    W = WildcardQuantity{T,DEFAULT_DIM_TYPE}
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
    return Dimensions{DEFAULT_DIM_TYPE}[
        unitful_to_dynamic(parse_to_free_unit(xi)) for xi in x
    ]
end

end
