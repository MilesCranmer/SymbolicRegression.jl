"""Functions to help with the main loop of SymbolicRegression.jl.

This includes: process management, stdin reading, checking for early stops."""
module SearchUtilsModule

using Printf: @printf, @sprintf
using Dates: Dates
using Distributed: Distributed, @spawnat, Future, procs, addprocs
using StatsBase: mean
using StyledStrings: @styled_str
using DispatchDoctor: @unstable
using Logging: AbstractLogger

using DynamicExpressions:
    AbstractExpression, string_tree, parse_expression, EvalOptions, with_type_parameters
using ..UtilsModule: subscriptify
using ..CoreModule: Dataset, AbstractOptions, Options, RecordType, max_features
using ..ComplexityModule: compute_complexity
using ..PopulationModule: Population
using ..PopMemberModule: PopMember
using ..HallOfFameModule: HallOfFame, string_dominating_pareto_curve
using ..ConstantOptimizationModule: optimize_constants
using ..ProgressBarsModule: WrappedProgressBar, manually_iterate!, barlen
using ..AdaptiveParsimonyModule: RunningSearchStatistics
using ..ExpressionBuilderModule: strip_metadata
using ..InterfaceDynamicExpressionsModule: takes_eval_options
using ..CheckConstraintsModule: check_constraints

function logging_callback! end

"""
    @filtered_async expr

Like `@async` but with error monitoring that ignores `Distributed.ProcessExitedException`
to avoid spam when worker processes exit normally.
"""
macro filtered_async(expr)
    return esc(
        quote
            $(Base).errormonitor(
                @async begin
                    try
                        $expr
                    catch ex
                        if !(ex isa $(Distributed).ProcessExitedException)
                            rethrow(ex)
                        end
                    end
                end
            )
        end,
    )
end

"""
    AbstractRuntimeOptions

An abstract type representing runtime configuration parameters for the symbolic regression algorithm.

`AbstractRuntimeOptions` is used by `equation_search` to control runtime aspects such
as parallelism and iteration limits. By subtyping `AbstractRuntimeOptions`, advanced users
can customize runtime behaviors by passing it to `equation_search`.

# See Also

- [`RuntimeOptions`](@ref): Default implementation used by `equation_search`.
- [`equation_search`](@ref SymbolicRegression.equation_search): Main function to perform symbolic regression.
- [`AbstractOptions`](@ref SymbolicRegression.CoreModule.OptionsStruct.AbstractOptions): See how to extend abstract types for customizing options.

"""
abstract type AbstractRuntimeOptions end

"""
    RuntimeOptions{PARALLELISM,DIM_OUT,RETURN_STATE,LOGGER} <: AbstractRuntimeOptions

Parameters for a search that are passed to `equation_search` directly,
rather than set within `Options`. This is to differentiate between
parameters that relate to processing and the duration of the search,
and parameters dealing with the search hyperparameters itself.
"""
struct RuntimeOptions{PARALLELISM,DIM_OUT,RETURN_STATE,LOGGER} <: AbstractRuntimeOptions
    niterations::Int64
    numprocs::Int64
    init_procs::Union{Vector{Int},Nothing}
    addprocs_function::Function
    worker_timeout::Float64
    exeflags::Cmd
    worker_imports::Union{Vector{Symbol},Nothing}
    runtests::Bool
    verbosity::Int64
    progress::Bool
    logger::Union{AbstractLogger,Nothing}
    parallelism::Val{PARALLELISM}
    dim_out::Val{DIM_OUT}
    return_state::Val{RETURN_STATE}
    run_id::String
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

@unstable function RuntimeOptions(;
    niterations::Int=10,
    nout::Int=1,
    parallelism=:multithreading,
    numprocs::Union{Int,Nothing}=nothing,
    procs::Union{Vector{Int},Nothing}=nothing,
    addprocs_function::Union{Function,Nothing}=nothing,
    heap_size_hint_in_bytes::Union{Integer,Nothing}=nothing,
    worker_timeout::Union{Real,Nothing}=nothing,
    worker_imports::Union{Vector{Symbol},Nothing}=nothing,
    runtests::Bool=true,
    return_state::VRS=nothing,
    run_id::Union{String,Nothing}=nothing,
    verbosity::Union{Int,Nothing}=nothing,
    progress::Union{Bool,Nothing}=nothing,
    v_dim_out::Val{DIM_OUT}=Val(nothing),
    logger=nothing,
    # Defined from options
    options_return_state::Val{ORS}=Val(nothing),
    options_verbosity::Union{Integer,Nothing}=nothing,
    options_progress::Union{Bool,Nothing}=nothing,
) where {DIM_OUT,ORS,VRS<:Union{Bool,Nothing,Val}}
    concurrency = if parallelism in (:multithreading, "multithreading")
        :multithreading
    elseif parallelism in (:multiprocessing, "multiprocessing")
        :multiprocessing
    elseif parallelism in (:serial, "serial")
        :serial
    else
        error(
            "Invalid parallelism mode: $parallelism. " *
            "You must choose one of :multithreading, :multiprocessing, or :serial.",
        )
        :serial
    end
    if concurrency in (:multithreading, :serial)
        !isnothing(numprocs) && error(
            "`numprocs` should not be set when using `parallelism=$(parallelism)`. Please use `:multiprocessing`.",
        )
        !isnothing(procs) && error(
            "`procs` should not be set when using `parallelism=$(parallelism)`. Please use `:multiprocessing`.",
        )
    end
    !isnothing(verbosity) &&
        !isnothing(options_verbosity) &&
        error(
            "You cannot set `verbosity` in both the search parameters " *
            "`AbstractOptions` and the call to `equation_search`.",
        )
    !isnothing(progress) &&
        !isnothing(options_progress) &&
        error(
            "You cannot set `progress` in both the search parameters " *
            "`AbstractOptions` and the call to `equation_search`.",
        )
    !isnothing(ORS) &&
        !isnothing(return_state) &&
        error(
            "You cannot set `return_state` in both the `AbstractOptions` and in the passed arguments.",
        )

    _numprocs::Int = if isnothing(numprocs)
        if isnothing(procs)
            4
        else
            length(procs)
        end
    else
        if isnothing(procs)
            numprocs
        else
            @assert length(procs) == numprocs
            numprocs
        end
    end

    _return_state = VRS <: Val ? first(VRS.parameters) : something(ORS, return_state, false)
    dim_out = something(DIM_OUT, nout > 1 ? 2 : 1)
    _verbosity = something(verbosity, options_verbosity, 1)
    _progress = something(progress, options_progress, (_verbosity > 0) && nout == 1)
    _addprocs_function = something(addprocs_function, addprocs)
    _worker_timeout = Float64(
        something(
            worker_timeout,
            tryparse(Float64, get(ENV, "JULIA_WORKER_TIMEOUT", "")),
            max(60, _numprocs^2),
        ),
    )
    _run_id = @something(run_id, generate_run_id())

    exeflags = if concurrency == :multiprocessing && isnothing(procs)
        heap_size_hint_in_megabytes = floor(
            Int,
            (@something(heap_size_hint_in_bytes, (Sys.free_memory() / _numprocs))) / 1024^2,
        )
        _verbosity > 0 &&
            isnothing(heap_size_hint_in_bytes) &&
            @info "Automatically setting `--heap-size-hint=$(heap_size_hint_in_megabytes)M` on each Julia process. You can configure this with the `heap_size_hint_in_bytes` parameter."

        `--heap-size=$(heap_size_hint_in_megabytes)M`
    else
        ``
    end

    return RuntimeOptions{concurrency,dim_out,_return_state,typeof(logger)}(
        niterations,
        _numprocs,
        procs,
        _addprocs_function,
        _worker_timeout,
        exeflags,
        worker_imports,
        runtests,
        _verbosity,
        _progress,
        logger,
        Val(concurrency),
        Val(dim_out),
        Val(_return_state),
        _run_id,
    )
end

function generate_run_id()
    date_str = Dates.format(Dates.now(), "yyyymmdd_HHMMSS")
    h = join(rand(['0':'9'; 'a':'z'; 'A':'Z'], 6))
    return "$(date_str)_$h"
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
            $(Distributed).@spawnat($(worker_idx), $(expr))
        elseif $(parallelism) == :multithreading
            $(Threads).@spawn($(expr))
        else
            error("Invalid parallel type ", string($(parallelism)), ".")
        end
    end |> esc
end

function init_dummy_pops(
    npops::Int, datasets::Vector{D}, options::AbstractOptions
) where {T,L,D<:Dataset{T,L}}
    prototype = Population(
        first(datasets);
        population_size=1,
        options=options,
        nfeatures=max_features(first(datasets), options),
    )
    # ^ Due to occasional inference issue, we manually specify the return type
    return [
        typeof(prototype)[
            if (i == 1 && j == 1)
                prototype
            else
                Population(
                    datasets[j];
                    population_size=1,
                    options=options,
                    nfeatures=max_features(datasets[j], options),
                )
            end for i in 1:npops
        ] for j in 1:length(datasets)
    ]
end

struct StdinReader
    can_read_user_input::Bool
    stream::IO
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
precompile(Tuple{typeof(watch_stream),Base.TTY})

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

function check_for_loss_threshold(halls_of_fame, options::AbstractOptions)::Bool
    return _check_for_loss_threshold(halls_of_fame, options.early_stop_condition, options)
end

function _check_for_loss_threshold(_, ::Nothing, ::AbstractOptions)
    return false
end
function _check_for_loss_threshold(halls_of_fame, f::F, options::AbstractOptions) where {F}
    return all(halls_of_fame) do hof
        any(hof.members[hof.exists]) do member
            f(member.loss, compute_complexity(member, options))::Bool
        end
    end
end

function check_for_timeout(start_time::Float64, options::AbstractOptions)::Bool
    return options.timeout_in_seconds !== nothing &&
           time() - start_time > options.timeout_in_seconds::Float64
end

function check_max_evals(num_evals, options::AbstractOptions)::Bool
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
    options::AbstractOptions,
    equation_speed::Vector{Float32},
    head_node_occupation::Float64,
    parallelism=:serial,
) where {T,L}
    # TODO - include command about "q" here.
    load_string = if length(equation_speed) > 0
        average_speed = sum(equation_speed) / length(equation_speed)
        @sprintf(
            "Full dataset evaluations per second: %-5.2e. ",
            round(average_speed, sigdigits=3)
        )
    else
        @sprintf("Full dataset evaluations per second: [.....]. ")
    end
    load_string *= get_load_string(; head_node_occupation, parallelism)
    load_string *= @sprintf("Press 'q' and then <enter> to stop execution early.")
    equation_strings = string_dominating_pareto_curve(
        hall_of_fame, dataset, options; width=barlen(progress_bar)
    )
    progress_bar.postfix = [
        (styled"{italic:Info}", styled"{italic:$load_string}"),
        (styled"{italic:Hall of Fame}", equation_strings),
    ]
    manually_iterate!(progress_bar)
    return nothing
end

function print_search_state(
    hall_of_fames,
    datasets;
    options::AbstractOptions,
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

    print("═"^twidth * "\n")
    for (j, (hall_of_fame, dataset)) in enumerate(zip(hall_of_fames, datasets))
        if nout > 1
            @printf("Best equations for output %d\n", j)
        end
        equation_strings = string_dominating_pareto_curve(
            hall_of_fame, dataset, options; width=width
        )
        print(equation_strings * "\n")
        print("═"^twidth * "\n")
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
    AbstractSearchState{T,L,N}

An abstract type encapsulating the internal state of the search process during symbolic regression.

`AbstractSearchState` instances hold information like populations and progress metrics,
used internally by `equation_search`. Subtyping `AbstractSearchState` allows
customization of search state management.

Look through the source of `equation_search` to see how this is used.

# See Also

- [`SearchState`](@ref): Default implementation of `AbstractSearchState`.
- [`equation_search`](@ref SymbolicRegression.equation_search): Function where `AbstractSearchState` is utilized.
- [`AbstractOptions`](@ref SymbolicRegression.CoreModule.OptionsStruct.AbstractOptions): See how to extend abstract types for customizing options.

"""
abstract type AbstractSearchState{T,L,N<:AbstractExpression{T}} end

"""
    SearchState{T,L,N,WorkerOutputType,ChannelType} <: AbstractSearchState{T,L,N}

The state of the search, including the populations, worker outputs, tasks, and
channels. This is used to manage the search and keep track of runtime variables
in a single struct.
"""
Base.@kwdef struct SearchState{T,L,N<:AbstractExpression{T},WorkerOutputType,ChannelType} <:
                   AbstractSearchState{T,L,N}
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
    seed_members::Vector{Vector{PopMember{T,L,N}}}
end

function save_to_file(
    dominating,
    nout::Integer,
    j::Integer,
    dataset::Dataset{T,L},
    options::AbstractOptions,
    ropt::AbstractRuntimeOptions,
) where {T,L}
    output_directory = joinpath(something(options.output_directory, "outputs"), ropt.run_id)
    mkpath(output_directory)
    filename = nout > 1 ? "hall_of_fame_output$(j).csv" : "hall_of_fame.csv"
    output_file = joinpath(output_directory, filename)

    dominating_n = length(dominating)

    complexities = Vector{Int}(undef, dominating_n)
    losses = Vector{L}(undef, dominating_n)
    strings = Vector{String}(undef, dominating_n)

    Threads.@threads for i in 1:dominating_n
        member = dominating[i]
        complexities[i] = compute_complexity(member, options)
        losses[i] = member.loss
        strings[i] = string_tree(
            member.tree, options; variable_names=dataset.variable_names, pretty=false
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
    for out_file in (output_file, output_file * ".bak")
        open(Base.Fix2(write, s), out_file, "w")
    end
    return nothing
end

"""
    get_cur_maxsize(; options, total_cycles, cycles_remaining)

For searches where the maxsize gradually increases, this function returns the
current maxsize.
"""
function get_cur_maxsize(;
    options::AbstractOptions, total_cycles::Int, cycles_remaining::Int
)
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
    hall_of_fame::HallOfFame, members::Vector{PM}, options::AbstractOptions
) where {PM<:PopMember}
    for member in members
        size = compute_complexity(member, options)
        valid_size = 0 < size <= options.maxsize
        if !valid_size
            continue
        end
        if !check_constraints(member.tree, options, options.maxsize, size)
            continue
        end
        not_filled = !hall_of_fame.exists[size]
        better_than_current = member.cost < hall_of_fame.members[size].cost
        if not_filled || better_than_current
            hall_of_fame.members[size] = copy(member)
            hall_of_fame.exists[size] = true
        end
    end
end

function _parse_guess_expression(
    ::Type{T}, g::AbstractExpression, ::Dataset, ::AbstractOptions
) where {T}
    return copy(g)
end

@unstable function _parse_guess_expression(
    ::Type{T}, g::NamedTuple, dataset::Dataset, options::AbstractOptions
) where {T}
    # Check if any expression in the NamedTuple uses actual variable names instead of placeholder syntax
    for expr_str in values(g), var_name in dataset.variable_names
        if occursin(Regex("\\b\\Q$(var_name)\\E\\b"), expr_str)
            throw(
                ArgumentError(
                    "Found variable name '$(var_name)' in TemplateExpression guess. " *
                    "Use placeholder syntax '#1', '#2', etc., (for argument 1, 2, etc.) instead of actual variable names.",
                ),
            )
        end
    end

    eval_options_kws = if takes_eval_options(options.operators)
        (; eval_options=EvalOptions(; options.turbo, options.bumper))
    else
        NamedTuple()
    end
    return parse_expression(
        g;
        expression_type=options.expression_type,
        operators=options.operators,
        variable_names=nothing,  # Don't pass dataset variable names - let custom parse_expression handle #N placeholders
        node_type=with_type_parameters(options.node_type, T),
        expression_options=options.expression_options,
        eval_options_kws...,
    )
end

@unstable function _parse_guess_expression(
    ::Type{T}, g, dataset::Dataset, options::AbstractOptions
) where {T}
    return parse_expression(
        g;
        operators=options.operators,
        variable_names=dataset.variable_names,
        node_type=with_type_parameters(options.node_type, T),
        expression_type=options.expression_type,
    )
end

"""Parse user-provided guess expressions and convert them into optimized
`PopMember` objects for each output dataset."""
function parse_guesses(
    ::Type{P},
    guesses::Union{AbstractVector,AbstractVector{<:AbstractVector}},
    datasets::Vector{D},
    options::AbstractOptions,
) where {T,L,P<:PopMember{T,L},D<:Dataset{T,L}}
    nout = length(datasets)
    out = [P[] for _ in 1:nout]
    guess_lists = _make_vector_vector(guesses, nout)
    for j in 1:nout
        dataset = datasets[j]
        for g in guess_lists[j]
            ex = _parse_guess_expression(T, g, dataset, options)
            member = PopMember(dataset, ex, options; deterministic=options.deterministic)
            if options.should_optimize_constants
                member, _ = optimize_constants(dataset, member, options)
            end
            member = strip_metadata(member, options, dataset)

            # Check if guess expression exceeds maxsize and warn
            complexity = compute_complexity(member.tree, options)
            if complexity > options.maxsize
                expr_str = string_tree(member.tree, options)
                @warn "Guess expression '$expr_str' has complexity $complexity > maxsize ($(options.maxsize))."
            end

            push!(out[j], member)
        end
    end
    return out
end
function _make_vector_vector(guesses, nout)
    if nout == 1
        if guesses isa AbstractVector{<:AbstractVector}
            @assert length(guesses) == nout
            return guesses
        else
            return [guesses]
        end
    else  # nout > 1
        if !(guesses isa AbstractVector{<:AbstractVector})
            throw(ArgumentError("`guesses` must be a vector of vectors when `nout > 1`"))
        end
        @assert length(guesses) == nout
        return guesses
    end
end

end
