module SymbolicRegressionUnitfulExt

if isdefined(Base, :get_extension)
    import Unitful: Units, uparse, @u_str, dimension, ustrip, Quantity, DimensionError
    using SymbolicRegression: Node, Options, tree_mapreduce
    import SymbolicRegression.CoreModule.DatasetModule: get_units
    import SymbolicRegression.CheckConstraintsModule: violates_dimensional_constraints
else
    import ..Unitful: Units, uparse, @u_str, dimension, ustrip, Quantity, DimensionError
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
function dimension_equivariant_deg1(op::F, ::Type{T}) where {F,T}
    example_input = one(T) * u"m/s"
    return dimension(op(example_input)) == dimension(example_input)
end
function dimension_equivariant_deg2(op::F, ::Type{T}) where {F,T}
    example_input = one(T) * u"m/s"
    example_input2 = example_input * 2
    return dimension(op(example_input, example_input2)) == dimension(example_input)
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
        op(l.val), l.wildcard && dimension_equivariant_deg1(op, unit_eltype(l.val)), false
    )
    if l.wildcard
        return DimensionalOutput(op(ustrip(l.val)), false, false)
    else
        return DimensionalOutput(l.val, false, true)
    end
end
function deg2_eval(op::F, l::DimensionalOutput, r::DimensionalOutput) where {F}
    l.violates && return l
    r.violates && return r

    @catch_method_error return DimensionalOutput(
        op(l.val, r.val),
        l.wildcard && dimension_equivariant_deg2(op, unit_eltype(l.val)),
        false,
    )
    l.wildcard && @catch_method_error return DimensionalOutput(
        op(ustrip(l.val), r.val),
        r.wildcard && dimension_equivariant_deg2(op, unit_eltype(l.val)),
        false,
    )
    r.wildcard && @catch_method_error return DimensionalOutput(
        op(l.val, ustrip(r.val)),
        l.wildcard && dimension_equivariant_deg2(op, unit_eltype(l.val)),
        false,
    )
    l.wildcard &&
        r.wildcard &&
        @catch_method_error return DimensionalOutput(
            op(ustrip(l.val), ustrip(r.val)), false, false
        )
    return DimensionalOutput(op(ustrip(l.val), ustrip(r.val)), false, true)
end

@inline degn_eval(operators, t, l) = deg1_eval(operators.unaops[t.op], l)
@inline degn_eval(operators, t, l, r) = deg2_eval(operators.binops[t.op], l, r)

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
