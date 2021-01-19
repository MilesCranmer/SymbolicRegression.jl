# From https://github.com/wherrera10/ThreadSafeDicts.jl

module ThreadSafeDicts

import Base.getindex, Base.setindex!, Base.get!, Base.get, Base.empty!, Base.pop!
import Base.haskey, Base.delete!, Base.print, Base.iterate, Base.length

export ThreadSafeDict

struct ThreadSafeDict{K, V} <: AbstractDict{K, V}
    dlock::Threads.SpinLock
    d::Dict
    ThreadSafeDict{K, V}() where V where K = new(Threads.SpinLock(), Dict{K, V}())
    ThreadSafeDict{K, V}(itr) where V where K = new(Threads.SpinLock(), Dict{K, V}(itr))
end
ThreadSafeDict() = ThreadSafeDict{Any,Any}()

function getindex(dic::ThreadSafeDict, k)
    lock(dic.dlock)
    v = getindex(dic.d, k)
    unlock(dic.dlock)
    return v
end

function setindex!(dic::ThreadSafeDict, k, v)
    lock(dic.dlock)
    h = setindex!(dic.d, k, v)
    unlock(dic.dlock)
    return h
end

function haskey(dic::ThreadSafeDict, k)
    lock(dic.dlock)
    b = haskey(dic.d, k)
    unlock(dic.dlock)
    return b
end

function get(dic::ThreadSafeDict, k, v)
    lock(dic.dlock)
    v = get(dic.d, k, v)
    unlock(dic.dlock)
    return v
end

function get!(dic::ThreadSafeDict, k, v)
    lock(dic.dlock)
    v = get!(dic.d, k, v)
    unlock(dic.dlock)
    return v
end

function pop!(dic::ThreadSafeDict)
    lock(dic.dlock)
    p = pop!(dic.d)
    unlock(dic.dlock)
    return p
end

function empty!(dic::ThreadSafeDict)
    lock(dic.dlock)
    d = empty!(dic.d)
    unlock(dic.dlock)
    return d
end

function delete!(dic::ThreadSafeDict, k)
    lock(dic.dlock)
    p = delete!(dic.d, k)
    unlock(dic.dlock)
    return p
end

function length(dic::ThreadSafeDict)
    lock(dic.dlock)
    len = length(dic.d)
    unlock(dic.dlock)
    return len
end

function iterate(dic::ThreadSafeDict)
    lock(dic.dlock)
    p = iterate(dic.d)
    unlock(dic.dlock)
    return p
end

function iterate(dic::ThreadSafeDict, i)
    lock(dic.dlock)
    p = iterate(dic.d, i)
    unlock(dic.dlock)
    return p
end  

function print(io::IO, dic::ThreadSafeDict)
    print(io, "Dict was ", islocked(dic.dlock) ? "locked" : "unlocked", ", contents: ")
    lock(dic.dlock)
    print(io, dic.d)
    unlock(dic.dlock)
end

end
