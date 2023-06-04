"""Useful functions to be used throughout the library."""
module UtilsModule

import Printf: @printf

function debug(verbosity, string...)
    if verbosity > 0
        println(string...)
    end
end

function debug_inline(verbosity, string...)
    if verbosity > 0
        print(string...)
    end
end

pseudo_time = 0

function get_birth_order(; deterministic=false)::Int
    """deterministic gives a birth time with perfect resolution, but is not thread safe."""
    if deterministic
        global pseudo_time
        pseudo_time += 1
        return pseudo_time
    else
        resolution = 1e7
        return round(Int, resolution * time())
    end
end

function is_anonymous_function(op)
    op_string = string(nameof(op))
    return length(op_string) > 1 &&
           op_string[1] == '#' &&
           op_string[2] in ('1', '2', '3', '4', '5', '6', '7', '8', '9')
end

function recursive_merge(x::AbstractVector...)
    return cat(x...; dims=1)
end

function recursive_merge(x::AbstractDict...)
    return merge(recursive_merge, x...)
end

function recursive_merge(x...)
    return x[end]
end

"""
Tiny equivalent to StaticArrays.MVector

This is so we don't have to load StaticArrays, which takes a long time.
"""
mutable struct MutableTuple{S,T} <: AbstractVector{T}
    data::NTuple{S,T}
end
@inline Base.eltype(::MutableTuple{S,T}) where {S,T} = T
Base.@propagate_inbounds function Base.getindex(v::MutableTuple, i::Int)
    T = eltype(v)
    # Trick from MArray.jl
    return GC.@preserve v unsafe_load(
        Base.unsafe_convert(Ptr{T}, pointer_from_objref(v)), i
    )
end
Base.@propagate_inbounds function Base.setindex!(v::MutableTuple, x, i::Int)
    T = eltype(v)
    GC.@preserve v unsafe_store!(Base.unsafe_convert(Ptr{T}, pointer_from_objref(v)), x, i)
    return x
end
@inline Base.eachindex(::MutableTuple{S}) where {S} = Base.OneTo(S)
@inline Base.lastindex(::MutableTuple{S}) where {S} = S
@inline Base.firstindex(v::MutableTuple) = 1
Base.dataids(v::MutableTuple) = (UInt(pointer(v)),)
@inline function Base.convert(::Type{<:Vector}, v::MutableTuple{S,T}) where {S,T}
    x = Vector{T}(undef, S)
    @inbounds for i in eachindex(v)
        x[i] = v[i]
    end
    return x
end

const max_ops = 8192
const vals = ntuple(Val, max_ops)

"""Return the bottom k elements of x, and their indices."""
bottomk_fast(x, k) = _bottomk_dispatch(x, vals[k])

function _bottomk_dispatch(x::AbstractVector{T}, ::Val{k}) where {T,k}
    if k == 1
        return (p -> [p]).(findmin_fast(x))
    end
    indmin = MutableTuple{k,Int}(ntuple(_ -> 1, Val(k)))
    minval = MutableTuple{k,T}(ntuple(_ -> typemax(T), Val(k)))
    _bottomk!(x, minval, indmin)
    return convert(Vector{T}, minval), convert(Vector{Int}, indmin)
end
function _bottomk!(x, minval, indmin)
    @inbounds for i in eachindex(x)
        new_min = x[i] < minval[end]
        if new_min
            minval[end] = x[i]
            indmin[end] = i
            for ki in lastindex(minval):-1:(firstindex(minval) + 1)
                need_swap = minval[ki] < minval[ki - 1]
                if need_swap
                    minval[ki], minval[ki - 1] = minval[ki - 1], minval[ki]
                    indmin[ki], indmin[ki - 1] = indmin[ki - 1], indmin[ki]
                end
            end
        end
    end
    return nothing
end

# Thanks Chris Elrod
# https://discourse.julialang.org/t/why-is-minimum-so-much-faster-than-argmin/66814/9
function findmin_fast(x::AbstractVector{T}) where {T}
    indmin = 1
    minval = typemax(T)
    @inbounds @simd for i in eachindex(x)
        newmin = x[i] < minval
        minval = newmin ? x[i] : minval
        indmin = newmin ? i : indmin
    end
    return minval, indmin
end

function argmin_fast(x::AbstractVector{T}) where {T}
    return findmin_fast(x)[2]
end

function poisson_sample(λ::T) where {T}
    k, p, L = 0, one(T), exp(-λ)
    while p > L
        k += 1
        p *= rand(T)
    end
    return k - 1
end

end
