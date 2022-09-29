"""Functions to help with the main loop of SymbolicRegression.jl.

This includes: process management, stdin reading, checking for early stops."""
module SearchUtilsModule

using Distributed
import ..CoreModule: SRThreaded, SRSerial, SRDistributed, Dataset, Options
import ..EquationUtilsModule: compute_complexity
import ..HallOfFameModule: HallOfFame, calculate_pareto_frontier

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

function check_for_early_stop(
    options::Options,
    datasets::AbstractVector{Dataset},
    hallOfFame::AbstractVector{HallOfFame},
)::Bool
    options.earlyStopCondition === nothing && return false

    # Check if all nout are below stopping condition.
    for (dataset, hof) in zip(datasets, hallOfFame)
        dominating = calculate_pareto_frontier(dataset, hof, options)
        # Check if zero size:
        length(dominating) == 0 && return false

        stop_conditions = [
            options.earlyStopCondition(
                member.loss, compute_complexity(member.tree, options)
            ) for member in dominating
        ]
        if !(any(stop_conditions))
            return false
        end
    end
    return true
end

end