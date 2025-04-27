module LoggingModule

using Base: AbstractLogger
using Logging: Logging as LG
using DynamicExpressions: string_tree
using BorrowChecker: @&, @take, OrBorrowed

using ..UtilsModule: @ignore
using ..CoreModule: AbstractOptions, Dataset
using ..PopulationModule: Population
using ..HallOfFameModule: HallOfFame
using ..ComplexityModule: compute_complexity
using ..HallOfFameModule: calculate_pareto_frontier
using ..SearchUtilsModule: AbstractSearchState, AbstractRuntimeOptions

import ..SearchUtilsModule: logging_callback!

"""
    AbstractSRLogger <: AbstractLogger

Abstract type for symbolic regression loggers. Subtypes must implement:

- `get_logger(logger)`: Return the underlying logger
- `logging_callback!(logger; kws...)`: Callback function for logging.
    Called with the current state, datasets, runtime options, and options. If you wish to
    reduce the logging frequency, you can increment and monitor a counter within this
    function.
"""
abstract type AbstractSRLogger <: AbstractLogger end

"""
    SRLogger(logger::AbstractLogger; log_interval::Int=100)

A logger for symbolic regression that wraps another logger.

# Arguments
- `logger`: The base logger to wrap
- `log_interval`: Number of steps between logging events. Default is 100 (log every 100 steps).
"""
Base.@kwdef struct SRLogger{L<:AbstractLogger} <: AbstractSRLogger
    logger::L
    log_interval::Int = 100
    _log_step::Base.RefValue{Int} = Base.RefValue(0)
end
SRLogger(logger::AbstractLogger; kws...) = SRLogger(; logger, kws...)

function get_logger(logger::SRLogger)
    return logger.logger
end
function should_log(logger::SRLogger)
    return logger.log_interval > 0 && logger._log_step[] % logger.log_interval == 0
end
function increment_log_step!(logger::SRLogger)
    logger._log_step[] += 1
    return nothing
end

function LG.with_logger(f::Function, logger::AbstractSRLogger)
    return LG.with_logger(f, get_logger(logger))
end

"""
    logging_callback!(logger::AbstractSRLogger; kws...)

Default logging callback for SymbolicRegression.

To override the default logging behavior, create a new type `MyLogger <: AbstractSRLogger`
and define a method for `SymbolicRegression.logging_callback`.
"""
function logging_callback!(
    logger::AbstractSRLogger;
    @nospecialize(state::AbstractSearchState),
    datasets::AbstractVector{<:Dataset{T,L}},
    @nospecialize(ropt::AbstractRuntimeOptions),
    @nospecialize(options::OrBorrowed{AbstractOptions}),
) where {T,L}
    if should_log(logger)
        data = log_payload(logger, state, datasets, options)
        LG.with_logger(logger) do
            @info("search", data = data)
        end
    end
    increment_log_step!(logger)
    return nothing
end

function log_payload(
    logger::AbstractSRLogger,
    @nospecialize(state::AbstractSearchState),
    datasets::AbstractVector{<:Dataset{T,L}},
    @nospecialize(options::OrBorrowed{AbstractOptions}),
) where {T,L}
    d = Ref(Dict{String,Any}())
    for i in eachindex(datasets, state.halls_of_fame)
        out = _log_scalars(;
            pops=state.last_pops[i],
            hall_of_fame=state.halls_of_fame[i],
            dataset=datasets[i],
            options,
        )
        if length(datasets) == 1
            d[] = out
        else
            d[]["output$(i)"] = out
        end
    end
    d[]["num_evals"] = sum(sum, state.num_evals)
    return d[]
end

function _log_scalars(;
    @nospecialize(pops::AbstractVector{<:Population}),
    @nospecialize(hall_of_fame::HallOfFame{T,L}),
    dataset::Dataset{T,L},
    @nospecialize(options::OrBorrowed{AbstractOptions}),
) where {T,L}
    out = Dict{String,Any}()

    #### Population diagnostics
    out["population"] = Dict([
        "complexities" => let
            complexities = Int[]
            for pop in pops, member in pop.members
                push!(complexities, compute_complexity(member, options))
            end
            complexities
        end
    ])

    #### Summaries
    dominating = calculate_pareto_frontier(hall_of_fame)
    trees = [member.tree for member in dominating]
    losses = L[member.loss for member in dominating]
    complexities = Int[compute_complexity(member, options) for member in dominating]

    out["summaries"] = Dict([
        "min_loss" => length(dominating) > 0 ? dominating[end].loss : L(Inf),
        "pareto_volume" => pareto_volume(losses, complexities, options.maxsize),
    ])

    #### Full Pareto front
    out["equations"] = let
        equations = String[
            string_tree(member.tree, options; variable_names=dataset.variable_names) for
            member in dominating
        ]
        Dict([
            "complexity=" * string(complexities[i_eqn]) =>
                Dict("loss" => losses[i_eqn], "equation" => equations[i_eqn]) for
            i_eqn in eachindex(complexities, losses, equations)
        ])
    end
    return out
end

function pareto_volume(losses::AbstractVector{L}, complexities, maxsize::Int) where {L}
    if length(losses) == 0
        return 0.0
    end
    log_losses = @. log10(losses + eps(L))
    log_complexities = @. log10(complexities)

    # Add a point equal to the best loss and largest possible complexity, + 1
    push!(log_losses, minimum(log_losses))
    push!(log_complexities, log10(maxsize + 1))

    # Add a point to connect things:
    push!(log_losses, maximum(log_losses))
    push!(log_complexities, maximum(log_complexities))

    xy = cat(log_complexities, log_losses; dims=2)
    hull = convex_hull(xy)
    return Float64(convex_hull_area(hull))
end

"""Uses gift wrapping algorithm to create a convex hull."""
function convex_hull(xy)
    @assert size(xy, 2) == 2
    cur_point = xy[sortperm(xy[:, 1])[1], :]
    hull = typeof(cur_point)[]
    while true
        push!(hull, cur_point)
        end_point = xy[1, :]
        for candidate_point in eachrow(xy)
            if end_point == cur_point || isleftof(candidate_point, (cur_point, end_point))
                end_point = candidate_point
            end
        end
        cur_point = end_point
        if end_point == hull[1]
            break
        end
    end
    return hull
end

function isleftof(point, line)
    (start_point, end_point) = line
    return (end_point[1] - start_point[1]) * (point[2] - start_point[2]) -
           (end_point[2] - start_point[2]) * (point[1] - start_point[1]) > 0
end

"""Computes the area within a convex hull."""
function convex_hull_area(hull)
    area = 0.0
    for i in eachindex(hull)
        j = i == lastindex(hull) ? firstindex(hull) : nextind(hull, i)
        area += (hull[i][1] * hull[j][2] - hull[j][1] * hull[i][2])
    end
    return abs(area) / 2
end

end
