module CacheModule

using LFUDACache: LFUDA
using DynamicExpressions: AbstractExpressionNode
using ..CoreModule: Options, Dataset, DATA_TYPE, LOSS_TYPE

struct Cache{T<:DATA_TYPE,L<:LOSS_TYPE,N<:AbstractExpressionNode{T}}
    cache::LFUDA{UInt64,L}
end

function Cache{T,L,N}(; maxsize::Integer=1000) where {T,L,N}
    return Cache{T,L,N}(LFUDA{UInt64,L}(; maxsize))
end

for f in (:length, :isempty)
    @eval Base.$(f)(cache::Cache) = Base.$(f)(cache.cache)
end
for f in (:haskey, :getindex, :delete!)
    @eval Base.$(f)(cache::Cache, key) = Base.$(f)(cache.cache, hash(key))
end
function Base.get(cache::Cache, key, default)
    return Base.get(cache.cache, hash(key), default)
end
function Base.get!(cache::Cache, key, default; size::Integer=1)
    return Base.get!(cache.cache, hash(key), default; size)
end
function Base.get!(default::Base.Callable, cache::Cache, key; size::Integer=1)
    return Base.get!(default, cache.cache, hash(key); size)
end
function Base.setindex!(cache::Cache, value, key; size::Integer=1)
    return Base.setindex!(cache.cache, value, hash(key); size)
end

end
