module InterfaceDynamicQuantitiesModule

import DynamicQuantities:
    UnionAbstractQuantity,
    AbstractDimensions,
    AbstractQuantity,
    Dimensions,
    SymbolicDimensions,
    Quantity,
    dimension,
    uparse,
    sym_uparse,
    dim_type,
    DEFAULT_DIM_BASE_TYPE

"""
    get_units(T, D, x, f)

Gets unit information from a vector or scalar. The first two
types are the default numeric type and dimensions type, respectively.
The third argument is the value to get units from, and the fourth
argument is a function for parsing strings (in case a string is passed)
"""
function get_units(args...)
    return error(
        "Unit information must be passed as one of `AbstractDimensions`, `AbstractQuantity`, `AbstractString`, `Real`.",
    )
end
function get_units(_, _, ::Nothing, ::Function)
    return nothing
end
function get_units(::Type{T}, ::Type{D}, x::AbstractString, f::Function) where {T,D}
    isempty(x) && return one(Quantity{T,D})
    return convert(Quantity{T,D}, f(x))
end
function get_units(::Type{T}, ::Type{D}, x::Quantity, ::Function) where {T,D}
    return convert(Quantity{T,D}, x)
end
function get_units(::Type{T}, ::Type{D}, x::AbstractDimensions, ::Function) where {T,D}
    return convert(Quantity{T,D}, Quantity(one(T), x))
end
function get_units(::Type{T}, ::Type{D}, x::Real, ::Function) where {T,D}
    return Quantity(convert(T, x), D)::Quantity{T,D}
end
function get_units(::Type{T}, ::Type{D}, x::AbstractVector, f::Function) where {T,D}
    return Quantity{T,D}[get_units(T, D, xi, f) for xi in x]
end
# TODO: Allow for AbstractQuantity output here

"""
    get_si_units(::Type{T}, units)

Gets the units with Dimensions{DEFAULT_DIM_BASE_TYPE} type from a vector or scalar.
"""
function get_si_units(::Type{T}, units) where {T}
    return get_units(T, Dimensions{DEFAULT_DIM_BASE_TYPE}, units, uparse)
end

"""
    get_sym_units(::Type{T}, units)

Gets the units with SymbolicDimensions{DEFAULT_DIM_BASE_TYPE} type from a vector or scalar.
"""
function get_sym_units(::Type{T}, units) where {T}
    return get_units(T, SymbolicDimensions{DEFAULT_DIM_BASE_TYPE}, units, sym_uparse)
end

"""
    get_dimensions_type(A, default_dimensions)

Recursively finds the dimension type from an array, or,
if no quantity is found, returns the default type.
"""
function get_dimensions_type(A::AbstractArray, default::Type{D}) where {D}
    for a in A
        # Look through columns for any dimensions (so we can return the correct type)
        if typeof(a) <: UnionAbstractQuantity
            return dim_type(a)
        end
    end
    return D
end
function get_dimensions_type(
    ::AbstractArray{Q}, default::Type
) where {Q<:UnionAbstractQuantity}
    return dim_type(Q)
end
function get_dimensions_type(_, default::Type{D}) where {D}
    return D
end

end
