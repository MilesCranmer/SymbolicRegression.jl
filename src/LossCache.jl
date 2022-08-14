module LossCacheModule

"""
A simple thread-safe cache for recording losses of expressions.

Has a max size and will delete members with FIFO order.
"""
mutable struct LossCache{T<:Real}
    cache::Dict{UInt,T}
    thread_lock::Threads.SpinLock
    fifo_keys::Vector{UInt}
    max_size::Int
end

function LossCache(cache::Dict{UInt,T}; max_size::Int=100_000) where {T<:Real}
    return LossCache{T}(cache, Threads.SpinLock(), UInt[], max_size)
end

"""Removes the oldest entry from the cache."""
function _unsafe_trim!(cache::LossCache{T}) where {T<:Real}
    if length(cache.fifo_keys) > cache.max_size
        key_to_remove = popfirst!(cache.fifo_keys)
        pop!(cache.cache, key_to_remove)
    end
    return nothing
end

function Base.haskey(cache::LossCache{T}, key::UInt)::Bool where {T<:Real}
    lock(cache.thread_lock) do
        return haskey(cache.cache, key)
    end
end

function Base.getindex(cache::LossCache{T}, key::UInt)::T where {T<:Real}
    lock(cache.thread_lock) do
        return cache.cache[key]
    end
end

function Base.setindex!(cache::LossCache{T}, value::T, key::UInt) where {T<:Real}
    lock(cache.thread_lock) do
        cache.cache[key] = value
        push!(cache.fifo_keys, key)
        _unsafe_trim!(cache)
    end
end

function Base.get!(f::Function, cache::LossCache{T}, key::UInt) where {T<:Real}
    lock(cache.thread_lock) do
        if haskey(cache.cache, key)
            output = cache.cache[key]
        else
            output = f()
            cache.cache[key] = output
            push!(cache.fifo_keys, key)
            _unsafe_trim!(cache)
        end
        return output
    end
end

end