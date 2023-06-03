module SymbolicRegressionUnitfulExt

if isdefined(Base, :get_extension)
    import Unitful: Units, uparse, dimension, ustrip, Quantity, DimensionError
    import Unitful: @u_str, @dimension
    using SymbolicRegression: Node, Options, tree_mapreduce
    import SymbolicRegression.CoreModule.DatasetModule: get_units
    import SymbolicRegression.CheckConstraintsModule: violates_dimensional_constraints
else
    import ..Unitful: Units, uparse, dimension, ustrip, Quantity, DimensionError
    import ..Unitful: @u_str, @dimension
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

# Make a new dimension for "wildcards":
# @dimension 𝐖 "𝐖" _Wildcard
# @unit W "W" Wildcard

struct DimensionalOutput
    val::Number  # Should hold any quantity
    wildcard::Bool
    violates::Bool
end

_hasmethod(op::F, ::T) where {F,T} = hasmethod(op, Tuple{T})
_hasmethod(op::F, ::T1, ::T2) where {F,T1,T2} = hasmethod(op, Tuple{T1,T2})
unit_eltype(::Type{Quantity{T}}) where {T} = T
unit_eltype(::Type{T}) where {T} = T

"""See if the function does not affect dimension full input"""
function wildcard_propagate(op::F, ::Type{T}, l_wild::Bool) where {F,T}
    !l_wild && return false
    # Anything that allows units should preserve the wildcard
    @catch_method_error begin
        op(T(1) * u"m")
        return true
    end
    return false
end
function wildcard_propagate(op::F, ::Type{T}, l_wild::Bool, r_wild::Bool) where {F,T}
    !l_wild && !r_wild && return false
    # Examples where the units are controlled by a constant (=wildcard):
    # (c*x + d*y) = also wildcard.
    # c*x + y = not wildcard.
    # c * x = wildcard
    # c / x = wildcard
    # x / c = wildcard
    # x * c = wildcard
    # x + c = not wildcard
    # x - c = not wildcard
    # c^x = not wildcard

    if l_wild && r_wild
        # Method should allow units on either side:
        # TODO: Finish
    end
    return false
end

function leaf_eval(x::AbstractArray{T}, variable_units, t::Node{T}) where {T}
    if t.constant
        return DimensionalOutput(t.val::T * u"1", true, false)
    else
        return DimensionalOutput(x[t.feature] * variable_units[t.feature], false, false)
    end
end
function deg1_eval(op::F, l::DimensionalOutput) where {F}
    l.violates && return l

    @catch_method_error return DimensionalOutput(
        op(l.val), wildcard_propagate(op, unit_eltype(l.val), l.wildcard), false
    )
    l.wildcard && return DimensionalOutput(op(ustrip(l.val)), false, false)
    return DimensionalOutput(l.val, false, true)
end
function deg2_eval(op::F, l::DimensionalOutput, r::DimensionalOutput) where {F}
    l.violates && return l
    r.violates && return r

    @catch_method_error return DimensionalOutput(
        op(l.val, r.val),
        wildcard_propagate(op, unit_eltype(l.val), l.wildcard, r.wildcard),
        false,
    )
    # TODO: Instead of ustrip(), it should be a mapping
    #       to the required units.
    l.wildcard && @catch_method_error return DimensionalOutput(
        op(ustrip(l.val), r.val),
        wildcard_propagate(op, unit_eltype(l.val), false, r.wildcard),
        false,
    )
    r.wildcard && @catch_method_error return DimensionalOutput(
        op(l.val, ustrip(r.val)),
        wildcard_propagate(op, unit_eltype(l.val), l.wildcard, false),
        false,
    )
    l.wildcard &&
        r.wildcard &&
        return DimensionalOutput(op(ustrip(l.val), ustrip(r.val)), false, false)

    return DimensionalOutput(l.val, false, true)
end

@inline degn_eval(operators, t, l) = deg1_eval(operators.unaops[t.op], l)
@inline function degn_eval(operators, t, l, r)
    return deg2_eval(operators.binops[t.op], l, r)
end

function violates_dimensional_constraints(
    tree::Node, variable_units, x::AbstractVector, options::Options
)
    operators = options.operators
    # We propagate (quantity, has_constant). If `has_constant`,
    # we are free to change the type.
    dimensional_result = tree_mapreduce(
        t -> leaf_eval(x, variable_units, t),
        identity,
        (args...) -> degn_eval(operators, args...),
        tree,
        DimensionalOutput,
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
