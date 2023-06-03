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

const QuantityOrFloat{T} = Union{Quantity{T},T}
Base.@kwdef struct WildcardDimensionWrapper{T}
    val::QuantityOrFloat{T} = one(T)
    wildcard::Bool = false
    violates::Bool = false
end
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
        dim_l = dimension(l.val)
        dim_r = dimension(r.val)
        if dim_l == dim_r
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
    dim_l = dimension(l.val)
    dim_r = dimension(r.val)
    if dim_r == NoDims
        return WildcardDimensionWrapper{T}(; val=l.val^r.val, wildcard=l.wildcard)
    elseif r.wildcard
        return WildcardDimensionWrapper{T}(; val=l.val^ustrip(r.val), wildcard=l.wildcard)
    else
        return WildcardDimensionWrapper{T}(; violates=true)
    end
end

# Make a new dimension for "wildcards":
@inline function leaf_eval(x::AbstractVector{T}, variable_units, t::Node{T}) where {T}
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
    @catch_method_error return op(l)
    l.wildcard &&
        return WildcardDimensionWrapper{T}(; val=op(ustrip(l.val)), wildcard=false)
    return WildcardDimensionWrapper{T}(; violates=true)
end
function deg2_eval(
    op::F, l::WildcardDimensionWrapper{T}, r::WildcardDimensionWrapper{T}
) where {F,T}
    (l.violates || r.violates) && return l
    @catch_method_error return op(l, r)
    l.wildcard && @catch_method_error return op(ustrip(l.val), r)
    r.wildcard && @catch_method_error return op(l, ustrip(r.val))
    l.wildcard &&
        r.wildcard &&
        return WildcardDimensionWrapper{T}(;
            val=op(ustrip(l.val), ustrip(r.val)), wildcard=false
        )
    return WildcardDimensionWrapper{T}(; violates=true)
end
@inline degn_eval(operators, t, l) = deg1_eval(operators.unaops[t.op], l)
@inline degn_eval(operators, t, l, r) = deg2_eval(operators.binops[t.op], l, r)

function violates_dimensional_constraints(
    tree::Node{T}, variable_units, x::AbstractVector{T}, options::Options
) where {T}
    operators = options.operators
    # We propagate (quantity, has_constant). If `has_constant`,
    # we are free to change the type.
    dimensional_result = tree_mapreduce(
        t -> leaf_eval(x, variable_units, t),
        identity,
        (args...) -> degn_eval(operators, args...),
        tree,
        WildcardDimensionWrapper{T},
    )
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
