module SymbolicRegressionUnitfulExt

if isdefined(Base, :get_extension)
    import Unitful: Units, uparse, dimension, ustrip, Quantity, DimensionError
    import Unitful: @u_str, @dimension, NoDims, unit
    using SymbolicRegression: Node, Options, tree_mapreduce
    import SymbolicRegression.CoreModule.DatasetModule: get_units
    import SymbolicRegression.CheckConstraintsModule: violates_dimensional_constraints
else
    import ..Unitful: Units, uparse, dimension, ustrip, Quantity, DimensionError
    import ..Unitful: @u_str, @dimension, NoDims, unit
    using ..SymbolicRegression: Node, Options, tree_mapreduce
    import ..SymbolicRegression.CoreModule.DatasetModule: get_units
    import ..SymbolicRegression.CheckConstraintsModule: violates_dimensional_constraints
end

macro catch_method_error(ex)
    quote
        try
            $(esc(ex))
        catch e
            !isa(e, Union{MethodError,DimensionError}) && rethrow(e)
        end
    end
end

"""
    WildcardDimensionWrapper{T}

A wrapper for `Quantity{T}` that allows for a wildcard feature, indicating
there is a free constant whose dimensions are not yet determined.
Also stores a flag indicating whether an expression is dimensionally consistent.
"""
Base.@kwdef struct WildcardDimensionWrapper{T}
    val::Quantity{T} = one(Quantity{T})
    wildcard::Bool = false
    violates::Bool = false
end
Base.isfinite(x::WildcardDimensionWrapper) = isfinite(x.val)
same_dimensions(x::Quantity, y::Quantity) = dimension(x) == dimension(y)
has_no_dims(x::Quantity) = dimension(x) == NoDims

# Overload *, /, +, -, ^ for WildcardDimensionWrapper, as
# we want wildcards to propagate through these operations.
for op in (:(Base.:*), :(Base.:/))
    @eval function $(op)(
        l::WildcardDimensionWrapper{T}, r::WildcardDimensionWrapper{T}
    ) where {T}
        l.violates && return l
        return WildcardDimensionWrapper{T}(;
            val=$(op)(l.val, r.val), wildcard=l.wildcard || r.wildcard
        )
    end
end
for op in (:(Base.:+), :(Base.:-))
    @eval function $(op)(
        l::WildcardDimensionWrapper{T}, r::WildcardDimensionWrapper{T}
    ) where {T}
        (l.violates || r.violates) && return l
        if same_dimensions(l.val, r.val)
            return WildcardDimensionWrapper{T}(;
                val=$(op)(l.val, r.val), wildcard=l.wildcard && r.wildcard
            )
        elseif l.wildcard && r.wildcard
            return WildcardDimensionWrapper{T}(;
                val=$(op)(ustrip(l.val), ustrip(r.val)), wildcard=l.wildcard && r.wildcard
            )
        elseif l.wildcard
            return WildcardDimensionWrapper{T}(;
                val=$(op)(ustrip(l.val) * unit(r.val), r.val), wildcard=false
            )
        elseif r.wildcard
            return WildcardDimensionWrapper{T}(;
                val=$(op)(l.val, ustrip(r.val) * unit(l.val)), wildcard=false
            )
        else
            return WildcardDimensionWrapper{T}(; violates=true)
        end
    end
end
function Base.:^(l::WildcardDimensionWrapper{T}, r::WildcardDimensionWrapper{T}) where {T}
    (l.violates || r.violates) && return l
    # TODO: Does this need to check for other violations? (See `safe_pow`)
    if has_no_dims(r.val)
        return WildcardDimensionWrapper{T}(; val=l.val^r.val, wildcard=l.wildcard)
    elseif r.wildcard
        return WildcardDimensionWrapper{T}(; val=l.val^ustrip(r.val), wildcard=l.wildcard)
    else
        return WildcardDimensionWrapper{T}(; violates=true)
    end
end

# Define dimensionally-aware evaluation routine:
@inline function deg0_eval(x::AbstractVector{T}, variable_units, t::Node{T}) where {T}
    if t.constant
        return WildcardDimensionWrapper{T}(; val=t.val::T, wildcard=true)
    else
        return WildcardDimensionWrapper{T}(;
            val=x[t.feature] * variable_units[t.feature], wildcard=false
        )
    end
end
function deg1_eval(op::F, l::WildcardDimensionWrapper{T}) where {F,T}
    l.violates && return l
    !isfinite(l) && return WildcardDimensionWrapper{T}(; violates=true)

    @catch_method_error return op(l)::WildcardDimensionWrapper{T}
    l.wildcard &&
        return WildcardDimensionWrapper{T}(; val=op(ustrip(l.val))::T, wildcard=false)
    return WildcardDimensionWrapper{T}(; violates=true)
end
function deg2_eval(
    op::F, l::WildcardDimensionWrapper{T}, r::WildcardDimensionWrapper{T}
) where {F,T}
    (l.violates || r.violates) && return l
    (!isfinite(l) || !isfinite(r)) && return WildcardDimensionWrapper{T}(; violates=true)

    @catch_method_error return op(l, r)::WildcardDimensionWrapper{T}
    l.wildcard &&
        @catch_method_error return op(ustrip(l.val), r)::WildcardDimensionWrapper{T}
    r.wildcard &&
        @catch_method_error return op(l, ustrip(r.val))::WildcardDimensionWrapper{T}
    l.wildcard &&
        r.wildcard &&
        return WildcardDimensionWrapper{T}(;
            val=op(ustrip(l.val), ustrip(r.val))::T, wildcard=false
        )
    return WildcardDimensionWrapper{T}(; violates=true)
end

@inline degn_eval(operators, t, l) = deg1_eval(operators.unaops[t.op], l)
@inline degn_eval(operators, t, l, r) = deg2_eval(operators.binops[t.op], l, r)

function violates_dimensional_constraints(
    tree::Node{T},
    variable_units::Union{AbstractVector,Tuple{Any,Vararg{Any}}},
    x::AbstractVector{T},
    options::Options,
) where {T}
    operators = options.operators
    # We propagate (quantity, has_constant). If `has_constant`,
    # we are free to change the type.
    dimensional_result = tree_mapreduce(
        t -> deg0_eval(x, variable_units, t),
        identity,
        (t, args...) -> degn_eval(operators, t, args...),
        tree,
        WildcardDimensionWrapper{T},
    )::WildcardDimensionWrapper{T}
    # TODO: Should also check against output type.
    return dimensional_result.violates
end

function get_units(x::AbstractArray)
    return Tuple(
        map(x) do xi
            if isa(xi, AbstractString)
                return uparse(xi)
            else
                return xi
            end
        end,
    )
end

end
