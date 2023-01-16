"""Functions to help with the main loop of SymbolicRegression.jl.

This includes: process management, stdin reading, checking for early stops."""
module SearchUtilsModule

import Printf: @printf, @sprintf
using Distributed
import StatsBase: mean

import ..CoreModule: Dataset, Options
import ..ComplexityModule: compute_complexity
import ..PopulationModule: Population, copy_population
import ..HallOfFameModule:
    HallOfFame, copy_hall_of_fame, calculate_pareto_frontier, string_dominating_pareto_curve
import ..ProgressBarsModule: WrappedProgressBar, set_multiline_postfix!, manually_iterate!

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
        if $(esc(parallel)) == :serial
            $(esc(expr))
        elseif $(esc(parallel)) == :multiprocessing
            @spawnat($(esc(p)), $(esc(expr)))
        elseif $(esc(parallel)) == :multithreading
            Threads.@spawn($(esc(expr)))
        else
            error("Invalid parallel type.")
        end
    end
end

function init_dummy_pops(
    nout::Int, npops::Int, datasets::Vector{Dataset{T}}, options::Options
)::Vector{Vector{Population{T}}} where {T}
    return [
        [
            Population(
                datasets[j]; npop=1, options=options, nfeatures=datasets[j].nfeatures
            ) for i in 1:npops
        ] for j in 1:nout
    ]
end

struct StdinReader{ST}
    can_read_user_input::Bool
    stream::ST
end

"""Start watching stream (like stdin) for user input."""
function watch_stream(stream)
    can_read_user_input = isreadable(stream)

    can_read_user_input && try
        Base.start_reading(stream)
        bytes = bytesavailable(stream)
        if bytes > 0
            # Clear out initial data
            read(stream, bytes)
        end
    catch err
        if isa(err, MethodError)
            can_read_user_input = false
        else
            throw(err)
        end
    end
    return StdinReader(can_read_user_input, stream)
end

"""Close the stdin reader and stop reading."""
function close_reader!(reader::StdinReader)
    if reader.can_read_user_input
        Base.stop_reading(reader.stream)
    end
end

"""Check if the user typed 'q' and <enter> or <ctl-c>."""
function check_for_user_quit(reader::StdinReader)::Bool
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

function check_for_loss_threshold(
    datasets::AbstractVector{Dataset{T}},
    hallOfFame::AbstractVector{HallOfFame{T}},
    options::Options,
)::Bool where {T}
    options.early_stop_condition === nothing && return false

    # Check if all nout are below stopping condition.
    for (dataset, hof) in zip(datasets, hallOfFame)
        dominating = calculate_pareto_frontier(dataset, hof, options)
        # Check if zero size:
        length(dominating) == 0 && return false

        stop_conditions = [
            options.early_stop_condition(
                member.loss, compute_complexity(member.tree, options)
            ) for member in dominating
        ]
        if !(any(stop_conditions))
            return false
        end
    end
    return true
end

function check_for_timeout(start_time::Float64, options::Options)::Bool
    return options.timeout_in_seconds !== nothing &&
           time() - start_time > options.timeout_in_seconds
end

function check_max_evals(num_evals, options::Options)::Bool
    return options.max_evals !== nothing && options.max_evals <= sum(sum, num_evals)
end

const TIME_TYPE = Float64

"""This struct is used to monitor resources."""
Base.@kwdef mutable struct ResourceMonitor
    """The time the search started."""
    absolute_start_time::TIME_TYPE = time()
    """The time the head worker started doing work."""
    start_work::TIME_TYPE = Inf
    """The time the head worker finished doing work."""
    stop_work::TIME_TYPE = Inf

    num_starts::UInt = 0
    num_stops::UInt = 0
    work_intervals::Vector{TIME_TYPE} = TIME_TYPE[]
    rest_intervals::Vector{TIME_TYPE} = TIME_TYPE[]

    """Number of intervals to store."""
    num_intervals_to_store::Int
end

function start_work_monitor!(monitor::ResourceMonitor)
    monitor.start_work = time()
    monitor.num_starts += 1
    if monitor.num_stops > 0
        push!(monitor.rest_intervals, monitor.start_work - monitor.stop_work)
        if length(monitor.rest_intervals) > monitor.num_intervals_to_store
            popfirst!(monitor.rest_intervals)
        end
    end
    return nothing
end

function stop_work_monitor!(monitor::ResourceMonitor)
    monitor.stop_work = time()
    push!(monitor.work_intervals, monitor.stop_work - monitor.start_work)
    monitor.num_stops += 1
    @assert monitor.num_stops == monitor.num_starts
    if length(monitor.work_intervals) > monitor.num_intervals_to_store
        popfirst!(monitor.work_intervals)
    end
    return nothing
end

function estimate_work_fraction(monitor::ResourceMonitor)::Float64
    if monitor.num_stops <= 1
        return 0.0  # Can't estimate from only one interval, due to JIT.
    end
    work_intervals = monitor.work_intervals
    rest_intervals = monitor.rest_intervals
    # Trim 1st, in case we are still in the first interval.
    if monitor.num_stops <= monitor.num_intervals_to_store + 1
        work_intervals = work_intervals[2:end]
        rest_intervals = rest_intervals[2:end]
    end
    return mean(work_intervals) / (mean(work_intervals) + mean(rest_intervals))
end

function get_load_string(; head_node_occupation::Float64, parallelism=:serial)
    parallelism == :serial && return ""
    out = @sprintf("Head worker occupation: %.1f%%", head_node_occupation * 100)

    raise_usage_warning = head_node_occupation > 0.2
    if raise_usage_warning
        out *= "."
        out *= " This is high, and will prevent efficient resource usage."
        out *= " Increase `ncyclesperiteration` to reduce load on head worker."
    end

    out *= "\n"
    return out
end

function update_progress_bar!(
    progress_bar::WrappedProgressBar;
    hall_of_fame::HallOfFame{T},
    dataset::Dataset{T},
    options::Options,
    head_node_occupation::Float64,
    parallelism=:serial,
) where {T}
    equation_strings = string_dominating_pareto_curve(hall_of_fame, dataset, options)
    # TODO - include command about "q" here.
    load_string = get_load_string(; head_node_occupation, parallelism)
    load_string *= @sprintf("Press 'q' and then <enter> to stop execution early.\n")
    equation_strings = load_string * equation_strings
    set_multiline_postfix!(progress_bar, equation_strings)
    manually_iterate!(progress_bar)
    return nothing
end

function print_search_state(
    hall_of_fames::Vector{HallOfFame{T}},
    datasets::Vector{Dataset{T}};
    options::Options,
    equation_speed::Vector{Float32},
    total_cycles::Int,
    cycles_remaining::Vector{Int},
    head_node_occupation::Float64,
    parallelism=:serial,
) where {T}
    nout = length(datasets)
    average_speed = sum(equation_speed) / length(equation_speed)

    @printf("\n")
    @printf("Cycles per second: %.3e\n", round(average_speed, sigdigits=3))
    load_string = get_load_string(; head_node_occupation, parallelism)
    print(load_string)
    cycles_elapsed = total_cycles * nout - sum(cycles_remaining)
    @printf(
        "Progress: %d / %d total iterations (%.3f%%)\n",
        cycles_elapsed,
        total_cycles * nout,
        100.0 * cycles_elapsed / total_cycles / nout
    )

    @printf("==============================\n")
    for (j, (hall_of_fame, dataset)) in enumerate(zip(hall_of_fames, datasets))
        if nout > 1
            @printf("Best equations for output %d\n", j)
        end
        equation_strings = string_dominating_pareto_curve(hall_of_fame, dataset, options)
        print(equation_strings)
        @printf("==============================\n")
    end
    @printf("Press 'q' and then <enter> to stop execution early.\n")
end

const StateType{T} = Tuple{
    Union{Vector{Vector{Population{T}}},Matrix{Population{T}}},
    Union{HallOfFame{T},Vector{HallOfFame{T}}},
}

function load_saved_hall_of_fame(saved_state::StateType{T})::Vector{HallOfFame{T}} where {T}
    hall_of_fame = saved_state[2]
    if !isa(hall_of_fame, Vector{HallOfFame{T}})
        hall_of_fame = [hall_of_fame]
    end
    return [copy_hall_of_fame(hof) for hof in hall_of_fame]
end
load_saved_hall_of_fame(::Nothing)::Nothing = nothing

function get_population(
    pops::Vector{Vector{Population{T}}}; out::Int, pop::Int
)::Population{T} where {T}
    return pops[out][pop]
end
function get_population(
    pops::Matrix{Population{T}}; out::Int, pop::Int
)::Population{T} where {T}
    return pops[out, pop]
end
function load_saved_population(
    saved_state::StateType{T}; out::Int, pop::Int
)::Population{T} where {T}
    saved_pop = get_population(saved_state[1]; out=out, pop=pop)
    return copy_population(saved_pop)
end

load_saved_population(::Nothing; kws...) = nothing

end
