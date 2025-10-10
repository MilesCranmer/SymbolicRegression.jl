module InterfaceDataTypesModule

using Random: AbstractRNG

"""
    init_value(::Type)

Return a zero value, or other trivial initalized value for the given type.
"""
init_value(::Type{T}) where {T<:Number} = zero(T)
function init_value(::Type{T}) where {T}
    return error("No `init_value` method defined for type $T. Please define one.")
end

"""
    sample_value(::Type, options::AbstractOptions)

Return a random value of the given type.
"""
sample_value(rng::AbstractRNG, ::Type{T}, _) where {T<:Number} = randn(rng, T)
function sample_value(::AbstractRNG, ::Type{T}, _) where {T}
    return error("No `sample_value` method defined for type $T. Please define one.")
end

"""
    mutate_value(rng::AbstractRNG, val, temperature, options)

Return a mutated value of the given type.
"""
function mutate_value(::AbstractRNG, ::T, _, _) where {T}
    return error("No `mutate_value` method defined for type $T. Please define one.")
end

end
