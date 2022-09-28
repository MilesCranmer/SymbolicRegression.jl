module UtilsModule

import Printf: @printf
using Distributed
import ..CoreModule: SRThreaded, SRSerial, SRDistributed

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

isgood(x::T) where {T<:Number} = !(isnan(x) || !isfinite(x))
isgood(x) = true
isbad(x) = !isgood(x)

macro return_on_false(flag, retval)
    :(
        if !$(esc(flag))
            return ($(esc(retval)), false)
        end
    )
end

# Returns two arrays
macro return_on_false2(flag, retval, retval2)
    :(
        if !$(esc(flag))
            return ($(esc(retval)), $(esc(retval2)), false)
        end
    )
end

function next_worker(worker_assignment::Dict{Tuple{Int,Int},Int}, procs::Vector{Int})::Int
    job_counts = Dict(proc => 0 for proc in procs)
    for (key, value) in worker_assignment
        @assert haskey(job_counts, value)
        job_counts[value] += 1
    end
    least_busy_worker = reduce(
        (proc1, proc2) -> (job_counts[proc1] <= job_counts[proc2] ? proc1 : proc2), procs
    )
    return least_busy_worker
end

function next_worker(worker_assignment::Dict{Tuple{Int,Int},Int}, procs::Nothing)::Int
    return 0
end

macro sr_spawner(parallel, p, expr)
    quote
        if $(esc(parallel)) == SRSerial
            $(esc(expr))
        elseif $(esc(parallel)) == SRDistributed
            @spawnat($(esc(p)), $(esc(expr)))
        else
            Threads.@spawn($(esc(expr)))
        end
    end
end

# Fastest way to check for NaN in an array.
# (due to optimizations in sum())
is_bad_array(array) = !isfinite(sum(array))

mutable struct StdinReader
    can_read_user_input::Bool
    stream::Union{Base.BufferStream,Base.TTY}
    StdinReader() = new()
end

"""Start watching stdin for user input."""
function watch_stdin!(reader::StdinReader; stream=stdin)
    reader.can_read_user_input = true
    reader.stream = stream
    try
        Base.start_reading(reader.stream)
        bytes = bytesavailable(reader.stream)
        if bytes > 0
            # Clear out initial data
            read(reader.stream, bytes)
        end
    catch err
        if isa(err, MethodError)
            reader.can_read_user_input = false
        else
            throw(err)
        end
    end
end

"""Check if the user typed 'q' and <enter> or <ctl-c>."""
function check_for_quit(reader::StdinReader)::Bool
    if reader.can_read_user_input
        bytes = bytesavailable(reader.stream)
        if bytes > 0
            # Read:
            data = read(reader.stream, bytes)
            control_c = 0x03
            quit = 0x71
            if length(data) > 1 && (data[end] == control_c || data[end - 1] == quit)
                return true
            end
        end
    end
    return false
end

"""Close the stdin reader and stop reading."""
function close_reader!(reader::StdinReader)
    if reader.can_read_user_input
        Base.stop_reading(reader.stream)
    end
end

end
