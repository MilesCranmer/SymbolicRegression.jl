module SymbolicRegressionUnitfulExt

if isdefined(Base, :get_extension)
    import Unitful: Units, uparse, dimension, ustrip, Quantity, DimensionError
    import Unitful: @u_str, @dimension, NoDims, unit, FreeUnits
    using SymbolicRegression: Node, Options, tree_mapreduce
    import SymbolicRegression.CoreModule.DatasetModule: get_units
    import SymbolicRegression.CheckConstraintsModule: violates_dimensional_constraints
    import Tricks: static_hasmethod
    import Compat: splat
else
    import ..Unitful: Units, uparse, dimension, ustrip, Quantity, DimensionError
    import ..Unitful: @u_str, @dimension, NoDims, unit, FreeUnits
    using ..SymbolicRegression: Node, Options, tree_mapreduce
    import ..SymbolicRegression.CoreModule.DatasetModule: get_units
    import ..SymbolicRegression.CheckConstraintsModule: violates_dimensional_constraints
    import ..Tricks: static_hasmethod
    import ..Compat: splat
end

# https://discourse.julialang.org/t/performance-of-hasmethod-vs-try-catch-on-methoderror/99827/14
# Faster way to catch method errors:
struct FuncWrapper{F}
    f::F
end
function safe_call(f::F, x::T, default=one(T)) where {F,T}
    wrapper = FuncWrapper{F}(f)
    static_hasmethod(wrapper, Tuple{T}) && return wrapper(x)
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
    return output
end

macro return_if_good(T, op, inputs)
    result = gensym()
    quote
        try
            $(result) = safe_call(splat($(esc(op))), $(esc(inputs)), one($(esc(T))))
            $(result)[2] && return $(result)[1]
            false
        catch e
            !isa(e, DimensionError) && rethrow(e)
            false
        end
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
function Base.one(::Type{W}) where {T,W<:WildcardDimensionWrapper{T}}
    return W(one(Quantity{T}), false, false)
end
Base.isfinite(x::WildcardDimensionWrapper) = isfinite(x.val)
same_dimensions(x::Quantity, y::Quantity) = dimension(x) == dimension(y)
has_no_dims(x::Quantity) = dimension(x) == NoDims
const DIMENSIONLESS = FreeUnits{(),NoDims,nothing}
@inline function create_quantity(x::T, u::FreeUnits) where {T}
    # Only required because Unitful.jl tries to create regular floats otherwise...
    return Quantity{T,dimension(u),typeof(u)}(x)
end
@inline q_one(::Type{T}) where {T} = create_quantity(one(T), DIMENSIONLESS())

# Overload *, /, +, -, ^ for WildcardDimensionWrapper, as
# we want wildcards to propagate through these operations.
for op in (:(Base.:*), :(Base.:/))
    @eval function $(op)(l::W, r::W) where {T,W<:WildcardDimensionWrapper{T}}
        l.violates && return l
        return W($(op)(l.val, r.val), l.wildcard || r.wildcard, false)
    end
end
for op in (:(Base.:+), :(Base.:-))
    @eval function $(op)(l::W, r::W)::W where {T,W<:WildcardDimensionWrapper{T}}
        (l.violates || r.violates) && return l
        if same_dimensions(l.val, r.val)
            return W($(op)(l.val, r.val), l.wildcard && r.wildcard, false)
        elseif l.wildcard && r.wildcard
            return W($(op)(ustrip(l.val), ustrip(r.val)), l.wildcard && r.wildcard, false)
        elseif l.wildcard
            return W($(op)(ustrip(l.val) * unit(r.val), r.val), false, false)
        elseif r.wildcard
            return W($(op)(l.val, ustrip(r.val) * unit(l.val)), false, false)
        else
            return W(q_one(T), false, true)
        end
    end
end
function Base.:^(l::W, r::W)::W where {T,W<:WildcardDimensionWrapper{T}}
    (l.violates || r.violates) && return l
    # TODO: Does this need to check for other violations? (See `safe_pow`)
    if has_no_dims(r.val)
        return W(l.val^r.val, l.wildcard, false)
    elseif r.wildcard
        return W(l.val^ustrip(r.val), l.wildcard, false)
    else
        return W(q_one(T), false, true)
    end
end

# Define dimensionally-aware evaluation routine:
@inline function deg0_eval(
    x::AbstractVector{T}, variable_units, t::Node{T}, ::Type{W}
) where {T,W<:WildcardDimensionWrapper{T}}
    t.constant && return W(t.val::T, true, false)
    return W(create_quantity(x[t.feature], variable_units[t.feature]), false, false)
end
function deg1_eval(op::F, l::W)::W where {F,T,W<:WildcardDimensionWrapper{T}}
    l.violates && return l
    !isfinite(l) && return W(q_one(T), false, true)

    static_hasmethod(op, Tuple{W}) && @return_if_good(W, op, (l,))
    l.wildcard && return W(op(ustrip(l.val))::T, false, false)
    return W(q_one(T), false, true)
end
function deg2_eval(op::F, l::W, r::W)::W where {F,T,W<:WildcardDimensionWrapper{T}}
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
    l.wildcard && r.wildcard && return W(op(ustrip(l.val), ustrip(r.val))::T, false, false)
    return W(q_one(T), false, true)
end

@inline degn_eval(operators, t, l) = deg1_eval(operators.unaops[t.op], l)
@inline degn_eval(operators, t, l, r) = deg2_eval(operators.binops[t.op], l, r)

function violates_dimensional_constraints(
    tree::Node{T}, variable_units::Tuple, x::AbstractVector{T}, options::Options
) where {T}
    W = WildcardDimensionWrapper{T}
    operators = options.operators
    # We propagate (quantity, has_constant). If `has_constant`,
    # we are free to change the type.
    dimensional_result = tree_mapreduce(
        t -> deg0_eval(x, variable_units, t, W)::W,
        identity,
        (t, args...) -> degn_eval(operators, t, args...)::W,
        tree,
        W,
    )
    # TODO: Should also check against output type.
    return dimensional_result.violates
end

function parse_to_free_unit(xi::AbstractString)
    xi_parsed = uparse(xi)
    isa(xi_parsed, FreeUnits) && return xi_parsed
    return DIMENSIONLESS()
end
parse_to_free_unit(xi::FreeUnits) = xi
parse_to_free_unit(::Number) = DIMENSIONLESS()

function get_units(x::AbstractVector)
    return Tuple(map(parse_to_free_unit, x))
end

end
