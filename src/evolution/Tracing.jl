module TracingModule

using DynamicExpressions: string_tree
using ...InterfacesModule: AbstractOptions, MaybeTrace, TraceType
using ...EvaluationModule: compute_complexity
using ...UtilsModule: json_write

const TRACE_SCHEMA_VERSION = 1

@inline new_trace(options::AbstractOptions) = new_trace(options.use_tracing)
@inline new_trace(::Val{enabled}) where {enabled} = enabled ? TraceType() : nothing
@inline new_trace(trace::MaybeTrace) = isnothing(trace) ? nothing : TraceType()

@inline new_step_trace(steps) = isnothing(steps) ? nothing : TraceType()

@inline function new_traced_steps(trace::MaybeTrace, ::Type{P}) where {P}
    return isnothing(trace) ? nothing : Tuple{P,P,TraceType}[]
end

@inline function trace_mutation_step!(steps, parent, member, trace::MaybeTrace)
    isnothing(trace) && return nothing
    push!(steps, (copy(parent), copy(member), trace))
    return nothing
end

@inline reset_traced_steps!(steps) = isnothing(steps) ? nothing : empty!(steps)

@inline function trace_mutation_type!(trace::MaybeTrace, type::String)
    !isnothing(trace) && (trace["type"] = type)
    return nothing
end

@inline function trace_mutation_result!(trace::MaybeTrace, result, reason)
    isnothing(trace) && return nothing
    trace["result"] = result
    trace["reason"] = reason
    return nothing
end

@inline function trace_identity_mutation!(trace::MaybeTrace)
    isnothing(trace) && return nothing
    trace["type"] = "identity"
    trace["result"] = "accept"
    trace["reason"] = "identity"
    return nothing
end

@inline function initialize_trace!(trace::MaybeTrace, options, filename)
    isnothing(trace) && return nothing
    trace["schema_version"] = TRACE_SCHEMA_VERSION
    trace["record_type"] = "search"
    trace["started_at"] = time()
    trace["options"] = string(options)
    write_trace(trace, filename; append=false)
    empty!(trace)
    return nothing
end

@inline function write_trace(trace::MaybeTrace, filename; append::Bool=true)
    !isnothing(trace) && json_write(trace, filename; append)
    return nothing
end

@inline function next_trace_iteration(trace::MaybeTrace)
    return isnothing(trace) ? 0 : (trace["iteration"]::Int) + 1
end

@inline function trace_iteration_start!(
    trace::MaybeTrace, out, pop, iteration, population, options
)
    isnothing(trace) && return nothing
    trace["schema_version"] = TRACE_SCHEMA_VERSION
    trace["record_type"] = "iteration"
    trace["output"] = out
    trace["population"] = pop
    trace["iteration"] = iteration
    trace["started_at"] = time()
    trace["members"] = _trace_population(population, options)
    trace["mutations"] = TraceType()
    return nothing
end

function _trace_population(population, options)
    return [
        TraceType(
            "tree" => string_tree(member.tree, options; pretty=false),
            "loss" => member.loss,
            "cost" => member.cost,
            "complexity" => compute_complexity(member, options),
            "birth" => member.birth,
            "ref" => member.ref,
            "parent" => member.parent,
        ) for member in population.members
    ]
end

function _trace_member!(mutations::TraceType, member, options)
    key = string(member.ref)
    if !haskey(mutations, key)
        mutations[key] = TraceType(
            "events" => Vector{TraceType}(),
            "tree" => string_tree(member.tree, options),
            "cost" => member.cost,
            "loss" => member.loss,
            "parent" => member.parent,
        )
    end
    return nothing
end

@inline function trace_optimization!(
    trace::MaybeTrace, member, old_ref, new_ref, optimized, options
)
    isnothing(trace) && return nothing
    @assert haskey(trace, "mutations")
    mutations = trace["mutations"]::TraceType
    _trace_member!(mutations, member, options)

    mutation_type = if optimized && options.should_optimize_constants
        "simplification_and_optimization"
    else
        "simplification"
    end
    tuning_event = TraceType(
        "type" => "tuning",
        "time" => time(),
        "child" => new_ref,
        "mutation" => TraceType("type" => mutation_type),
    )
    death_event = TraceType("type" => "death", "time" => time())
    old_entry = get!(mutations, string(old_ref)) do
        entry = copy(first(member for member in trace["members"] if member["ref"] == old_ref))
        entry["events"] = Vector{TraceType}()
        entry
    end
    push!(old_entry["events"], tuning_event, death_event)
    return nothing
end

@inline function trace_mutation_attempts!(
    trace::MaybeTrace,
    steps,
    population,
    oldest,
    should_replace,
    selected_attempt_idx,
    options,
)
    isnothing(trace) && return nothing
    mutations = get!(TraceType, trace, "mutations")
    members = should_replace ? [population.members[oldest]] : eltype(population.members)[]
    for (parent, child, _) in steps
        push!(members, parent, child)
    end
    for member in members
        _trace_member!(mutations, member, options)
    end
    for (attempt_idx, (parent, child, step_trace)) in enumerate(steps)
        mutation_event = TraceType(
            "type" => "mutate",
            "time" => time(),
            "child" => child.ref,
            "selected" => attempt_idx == selected_attempt_idx,
            "mutation" => step_trace,
        )
        push!(mutations[string(parent.ref)]["events"], mutation_event)
    end
    if should_replace
        death_event = TraceType("type" => "death", "time" => time())
        push!(mutations[string(population.members[oldest].ref)]["events"], death_event)
    end
    return nothing
end

@inline function trace_crossover!(
    trace::MaybeTrace,
    parent1,
    parent2,
    child1,
    child2,
    population,
    oldest1,
    oldest2,
    crossover_trace::MaybeTrace,
    options,
)
    isnothing(trace) && return nothing
    @assert crossover_trace isa TraceType
    mutations = get!(TraceType, trace, "mutations")
    for member in (
        parent1,
        parent2,
        child1,
        child2,
        population.members[oldest1],
        population.members[oldest2],
    )
        _trace_member!(mutations, member, options)
    end

    crossover_event = TraceType(
        "type" => "crossover",
        "time" => time(),
        "parent1" => parent1.ref,
        "parent2" => parent2.ref,
        "child1" => child1.ref,
        "child2" => child2.ref,
        "details" => crossover_trace,
    )
    death_event1 = TraceType("type" => "death", "time" => time())
    death_event2 = TraceType("type" => "death", "time" => time())
    push!(mutations[string(parent1.ref)]["events"], crossover_event)
    push!(mutations[string(parent2.ref)]["events"], crossover_event)
    push!(mutations[string(population.members[oldest1].ref)]["events"], death_event1)
    push!(mutations[string(population.members[oldest2].ref)]["events"], death_event2)
    return nothing
end

end
