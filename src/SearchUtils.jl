"""Functions to help with the main loop of SymbolicRegression.jl.

This includes: process management, stdin reading, checking for early stops."""
module SearchUtilsModule

using Printf: @printf, @sprintf
using Distributed
using StatsBase: mean
using DispatchDoctor: @unstable

using DynamicExpressions: AbstractExpression, string_tree
using ..UtilsModule: subscriptify
using ..CoreModule: Dataset, Options, MAX_DEGREE, RecordType
using ..ComplexityModule: compute_complexity
using ..PopulationModule: Population
using ..PopMemberModule: PopMember
using ..HallOfFameModule:
    HallOfFame, calculate_pareto_frontier, string_dominating_pareto_curve
using ..ProgressBarsModule: WrappedProgressBar, set_multiline_postfix!, manually_iterate!
using ..AdaptiveParsimonyModule: update_frequencies!, RunningSearchStatistics

"""
    RuntimeOptions{N,PARALLELISM,DIM_OUT,RETURN_STATE}

Parameters for a search that are passed to `equation_search` directly,
rather than set within `Options`. This is to differentiate between
parameters that relate to processing and the duration of the search,
and parameters dealing with the search hyperparameters itself.
"""
Base.@kwdef struct RuntimeOptions{PARALLELISM,DIM_OUT,RETURN_STATE}
    niterations::Int64
    total_cycles::Int64
    numprocs::Int64
    init_procs::Union{Vector{Int},Nothing}
    addprocs_function::Function
    exeflags::Cmd
    runtests::Bool
    verbosity::Int64
    progress::Bool
    parallelism::Val{PARALLELISM}
    dim_out::Val{DIM_OUT}
    return_state::Val{RETURN_STATE}
end
@unstable @inline function Base.getproperty(
    roptions::RuntimeOptions{P,D,R}, name::Symbol
) where {P,D,R}
    if name == :parallelism
        return P
    elseif name == :dim_out
        return D
    elseif name == :return_state
        return R
    else
        getfield(roptions, name)
    end
end
function Base.propertynames(roptions::RuntimeOptions)
    return (Base.fieldnames(typeof(roptions))..., :parallelism, :dim_out, :return_state)
end

"""A simple dictionary to track worker allocations."""
const WorkerAssignments = Dict{Tuple{Int,Int},Int}

function next_worker(worker_assignment::WorkerAssignments, procs::Vector{Int})::Int
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

function assign_next_worker!(
    worker_assignment::WorkerAssignments; pop, out, parallelism, procs
)::Int
    if parallelism == :multiprocessing
        worker_idx = next_worker(worker_assignment, procs)
        worker_assignment[(out, pop)] = worker_idx
        return worker_idx
    else
        return 0
    end
end

const DefaultWorkerOutputType{P,H} = Tuple{P,H,RecordType,Float64}

function get_worker_output_type(
    ::Val{PARALLELISM}, ::Type{PopType}, ::Type{HallOfFameType}
) where {PARALLELISM,PopType,HallOfFameType}
    if PARALLELISM == :serial
        DefaultWorkerOutputType{PopType,HallOfFameType}
    elseif PARALLELISM == :multiprocessing
        Future
    else
        Task
    end
end

#! format: off
extract_from_worker(p::DefaultWorkerOutputType, _, _) = p
extract_from_worker(f::Future, ::Type{P}, ::Type{H}) where {P,H} = fetch(f)::DefaultWorkerOutputType{P,H}
extract_from_worker(t::Task, ::Type{P}, ::Type{H}) where {P,H} = fetch(t)::DefaultWorkerOutputType{P,H}
#! format: on

macro sr_spawner(expr, kws...)
    # Extract parallelism and worker_idx parameters from kws
    @assert length(kws) == 2
    @assert all(ex -> ex.head == :(=), kws)
    @assert any(ex -> ex.args[1] == :parallelism, kws)
    @assert any(ex -> ex.args[1] == :worker_idx, kws)
    parallelism = kws[findfirst(ex -> ex.args[1] == :parallelism, kws)::Int].args[2]
    worker_idx = kws[findfirst(ex -> ex.args[1] == :worker_idx, kws)::Int].args[2]
    return quote
        if $(parallelism) == :serial
            $(expr)
        elseif $(parallelism) == :multiprocessing
            @spawnat($(worker_idx), $(expr))
        elseif $(parallelism) == :multithreading
            Threads.@spawn($(expr))
        else
            error("Invalid parallel type ", string($(parallelism)), ".")
        end
    end |> esc
end

function init_dummy_pops(
    npops::Int, datasets::Vector{D}, options::Options
) where {T,L,D<:Dataset{T,L}}
    return [
        [
            Population(d; population_size=1, options=options, nfeatures=d.nfeatures) for
            _ in 1:npops
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

function check_for_loss_threshold(halls_of_fame, options::Options)::Bool
    return _check_for_loss_threshold(halls_of_fame, options.early_stop_condition, options)
end

function _check_for_loss_threshold(_, ::Nothing, ::Options)
    return false
end
function _check_for_loss_threshold(halls_of_fame, f::F, options::Options) where {F}
    return all(halls_of_fame) do hof
        any(hof.members[hof.exists]) do member
            f(member.loss, compute_complexity(member, options))::Bool
        end
    end
end

function check_for_timeout(start_time::Float64, options::Options)::Bool
    return options.timeout_in_seconds !== nothing &&
           time() - start_time > options.timeout_in_seconds::Float64
end

function check_max_evals(num_evals, options::Options)::Bool
    return options.max_evals !== nothing && options.max_evals::Int <= sum(sum, num_evals)
end

"""
This struct is used to monitor resources.

Whenever we check a channel, we record if it was empty or not.
This gives us a measure for how much of a bottleneck there is
at the head worker.
"""
Base.@kwdef mutable struct ResourceMonitor
    population_ready::Vector{Bool} = Bool[]
    max_recordings::Int
    start_reporting_at::Int
    window_size::Int
end

function record_channel_state!(monitor::ResourceMonitor, state)
    push!(monitor.population_ready, state)
    if length(monitor.population_ready) > monitor.max_recordings
        popfirst!(monitor.population_ready)
    end
    return nothing
end

function estimate_work_fraction(monitor::ResourceMonitor)::Float64
    if length(monitor.population_ready) <= monitor.start_reporting_at
        return 0.0  # Can't estimate from only one interval, due to JIT.
    end
    return mean(monitor.population_ready[(end - (monitor.window_size - 1)):end])
end

function get_load_string(; head_node_occupation::Float64, parallelism=:serial)
    if parallelism == :serial || head_node_occupation == 0.0
        return ""
    end
    return ""
    ## TODO: Debug why populations are always ready
    # out = @sprintf("Head worker occupation: %.1f%%", head_node_occupation * 100)

    # raise_usage_warning = head_node_occupation > 0.4
    # if raise_usage_warning
    #     out *= "."
    #     out *= " This is high, and will prevent efficient resource usage."
    #     out *= " Increase `ncycles_per_iteration` to reduce load on head worker."
    # end

    # out *= "\n"
    # return out
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
    return [copy(hof) for hof in hall_of_fame]
end
load_saved_hall_of_fame(::Nothing)::Nothing = nothing

function get_population(
    pops::Vector{Vector{P}}; out::Int, pop::Int
)::P where {P<:Population}
    return pops[out][pop]
end
function get_population(pops::Matrix{P}; out::Int, pop::Int)::P where {P<:Population}
    return pops[out, pop]
end
function load_saved_population(saved_state; out::Int, pop::Int)
    saved_pop = get_population(saved_state[1]; out=out, pop=pop)
    return copy(saved_pop)
end
load_saved_population(::Nothing; kws...) = nothing

"""
    SearchState{PopType,HallOfFameType,WorkerOutputType,ChannelType}

The state of a search, including the populations, worker outputs, tasks, and
channels. This is used to manage the search and keep track of runtime variables
in a single struct.
"""
Base.@kwdef struct SearchState{T,L,N<:AbstractExpression{T},WorkerOutputType,ChannelType}
    procs::Vector{Int}
    we_created_procs::Bool
    worker_output::Vector{Vector{WorkerOutputType}}
    tasks::Vector{Vector{Task}}
    channels::Vector{Vector{ChannelType}}
    worker_assignment::WorkerAssignments
    task_order::Vector{Tuple{Int,Int}}
    halls_of_fame::Vector{HallOfFame{T,L,N}}
    last_pops::Vector{Vector{Population{T,L,N}}}
    best_sub_pops::Vector{Vector{Population{T,L,N}}}
    all_running_search_statistics::Vector{RunningSearchStatistics}
    num_evals::Vector{Vector{Float64}}
    cycles_remaining::Vector{Int}
    cur_maxsizes::Vector{Int}
    stdin_reader::StdinReader
    record::Base.RefValue{RecordType}
end

function save_to_file(
    dominating, nout::Integer, j::Integer, dataset::Dataset{T,L}, options::Options
) where {T,L}
    output_file = options.output_file
    if nout > 1
        output_file = output_file * ".out$j"
    end
    dominating_n = length(dominating)

    complexities = Vector{Int}(undef, dominating_n)
    losses = Vector{L}(undef, dominating_n)
    strings = Vector{String}(undef, dominating_n)

    Threads.@threads for i in 1:dominating_n
        member = dominating[i]
        complexities[i] = compute_complexity(member, options)
        losses[i] = member.loss
        strings[i] = string_tree(
            member.tree, options; variable_names=dataset.variable_names
        )
    end

    s = let
        tmp_io = IOBuffer()

        println(tmp_io, "Complexity,Loss,Equation")
        for i in 1:dominating_n
            println(tmp_io, "$(complexities[i]),$(losses[i]),\"$(strings[i])\"")
        end

        String(take!(tmp_io))
    end

    # Write file twice in case exit in middle of filewrite
    for out_file in (output_file, output_file * ".bkup")
        open(out_file, "w") do io
            write(io, s)
        end
    end
    return nothing
end

"""
    get_cur_maxsize(; options, total_cycles, cycles_remaining)

For searches where the maxsize gradually increases, this function returns the
current maxsize.
"""
function get_cur_maxsize(; options::Options, total_cycles::Int, cycles_remaining::Int)
    cycles_elapsed = total_cycles - cycles_remaining
    fraction_elapsed = 1.0f0 * cycles_elapsed / total_cycles
    in_warmup_period = fraction_elapsed <= options.warmup_maxsize_by

    if options.warmup_maxsize_by > 0 && in_warmup_period
        return 3 + floor(
            Int, (options.maxsize - 3) * fraction_elapsed / options.warmup_maxsize_by
        )
    else
        return options.maxsize
    end
end

function construct_datasets(
    X,
    y,
    weights,
    variable_names,
    display_variable_names,
    y_variable_names,
    X_units,
    y_units,
    extra,
    ::Type{L},
) where {L}
    nout = size(y, 1)
    return [
        Dataset(
            X,
            y[j, :],
            L;
            index=j,
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
            extra=extra,
        ) for j in 1:nout
    ]
end

function update_hall_of_fame!(
    hall_of_fame::HallOfFame, members::Vector{PM}, options::Options
) where {PM<:PopMember}
    for member in members
        size = compute_complexity(member, options)
        valid_size = 0 < size < options.maxsize + MAX_DEGREE
        if !valid_size
            continue
        end
        not_filled = !hall_of_fame.exists[size]
        better_than_current = member.score < hall_of_fame.members[size].score
        if not_filled || better_than_current
            hall_of_fame.members[size] = copy(member)
            hall_of_fame.exists[size] = true
        end
    end
end

end
