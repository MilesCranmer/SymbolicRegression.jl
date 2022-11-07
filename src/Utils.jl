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

function check_numeric(n)
    return tryparse(Float64, n) !== nothing
end

function is_anonymous_function(op)
    op_string = string(nameof(op))
    return length(op_string) > 1 && op_string[1] == '#' && check_numeric(op_string[2:2])
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

const max_ops = 1024
const vals = ntuple(i -> Val(i), max_ops)

end
