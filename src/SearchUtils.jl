"""Functions to help with the main loop of SymbolicRegression.jl.

This includes: process management, stdin reading, checking for early stops."""
module SearchUtilsModule

import Printf: @printf, @sprintf
using Distributed
import StatsBase: mean

import ..UtilsModule: subscriptify
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
    npops::Int, datasets::Vector{D}, options::Options
) where {T,L,D<:Dataset{T,L}}
    return [
        [
            Population(d; population_size=1, options=options, nfeatures=d.nfeatures) for
            i in 1:npops
        ] for d in datasets
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

function check_for_loss_threshold(hallOfFame, options::Options)::Bool
    options.early_stop_condition === nothing && return false

    # Check if all nout are below stopping condition.
    for hof in hallOfFame
        stop_conditions = [
            exists &&
            options.early_stop_condition(member.loss, compute_complexity(member, options))
            for (exists, member) in zip(hof.exists, hof.members)
        ]
        if any(stop_conditions)
            # This means some expressions hit the stop condition.
        else
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
    progress_bar::WrappedProgressBar,
    hall_of_fame::HallOfFame{T,L},
    dataset::Dataset{T,L},
    options::Options,
    equation_speed::Vector{Float32},
    head_node_occupation::Float64,
    parallelism=:serial,
) where {T,L}
    equation_strings = string_dominating_pareto_curve(
        hall_of_fame, dataset, options; width=progress_bar.bar.width
    )
    # TODO - include command about "q" here.
    load_string = if length(equation_speed) > 0
        average_speed = sum(equation_speed) / length(equation_speed)
        @sprintf(
            "Expressions evaluated per second: %-5.2e. ",
            round(average_speed, sigdigits=3)
        )
    else
        @sprintf("Expressions evaluated per second: [.....]. ")
    end
    load_string *= get_load_string(; head_node_occupation, parallelism)
    load_string *= @sprintf("Press 'q' and then <enter> to stop execution early.\n")
    equation_strings = load_string * equation_strings
    set_multiline_postfix!(progress_bar, equation_strings)
    manually_iterate!(progress_bar)
    return nothing
end

function print_search_state(
    hall_of_fames,
    datasets;
    options::Options,
    equation_speed::Vector{Float32},
    total_cycles::Int,
    cycles_remaining::Vector{Int},
    head_node_occupation::Float64,
    parallelism=:serial,
    width::Union{Integer,Nothing}=nothing,
)
    twidth = (width === nothing) ? 100 : max(100, width::Integer)
    nout = length(datasets)
    average_speed = sum(equation_speed) / length(equation_speed)

    @printf("\n")
    @printf("Expressions evaluated per second: %.3e\n", round(average_speed, sigdigits=3))
    load_string = get_load_string(; head_node_occupation, parallelism)
    print(load_string)
    cycles_elapsed = total_cycles * nout - sum(cycles_remaining)
    @printf(
        "Progress: %d / %d total iterations (%.3f%%)\n",
        cycles_elapsed,
        total_cycles * nout,
        100.0 * cycles_elapsed / total_cycles / nout
    )

    print("="^twidth * "\n")
    for (j, (hall_of_fame, dataset)) in enumerate(zip(hall_of_fames, datasets))
        if nout > 1
            @printf("Best equations for output %d\n", j)
        end
        equation_strings = string_dominating_pareto_curve(
            hall_of_fame, dataset, options; width=width
        )
        print(equation_strings * "\n")
        print("="^twidth * "\n")
    end
    return print("Press 'q' and then <enter> to stop execution early.\n")
end

function load_saved_hall_of_fame(saved_state)
    hall_of_fame = saved_state[2]
    hall_of_fame = if isa(hall_of_fame, HallOfFame)
        [hall_of_fame]
    else
        hall_of_fame
    end
    return [copy_hall_of_fame(hof) for hof in hall_of_fame]
end
load_saved_hall_of_fame(::Nothing)::Nothing = nothing

function get_population(
    pops::Vector{Vector{Population{T,L}}}; out::Int, pop::Int
)::Population{T,L} where {T,L}
    return pops[out][pop]
end
function get_population(
    pops::Matrix{Population{T,L}}; out::Int, pop::Int
)::Population{T,L} where {T,L}
    return pops[out, pop]
end
function load_saved_population(saved_state; out::Int, pop::Int)
    saved_pop = get_population(saved_state[1]; out=out, pop=pop)
    return copy_population(saved_pop)
end
load_saved_population(::Nothing; kws...) = nothing

function construct_datasets(
    X,
    y,
    weights,
    variable_names,
    display_variable_names,
    y_variable_names,
    X_units,
    y_units,
    loss_type,
)
    nout = size(y, 1)
    return [
        Dataset(
            X,
            y[j, :];
            weights=(weights === nothing ? weights : weights[j, :]),
            variable_names=variable_names,
            display_variable_names=display_variable_names,
            y_variable_name=if y_variable_names === nothing
                if nout > 1
                    "y$(subscriptify(j))"
                else
                    if variable_names === nothing || "y" ∉ variable_names
                        "y"
                    else
                        "target"
                    end
                end
            elseif isa(y_variable_names, AbstractVector)
                y_variable_names[j]
            else
                y_variable_names
            end,
            X_units=X_units,
            y_units=isa(y_units, AbstractVector) ? y_units[j] : y_units,
            loss_type=loss_type,
        ) for j in 1:nout
    ]
end

end
