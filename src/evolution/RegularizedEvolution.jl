module RegularizedEvolutionModule

using ...InterfacesModule:
    AbstractOptions,
    Dataset,
    MaybeTrace,
    DATA_TYPE,
    LOSS_TYPE,
    MutationStepResult,
    wrap_mutation_step
using ..PopulationModule: Population, best_of_sample
using ..HallOfFameModule: HallOfFame, update_hall_of_fame!, _update_hall_of_fame_unchecked!
using ...EvaluationModule: compute_complexity
using ..MutateModule: next_generation
using ..CrossoverModule: crossover_generation
using ..TracingModule:
    new_trace,
    new_step_trace,
    new_traced_steps,
    reset_traced_steps!,
    trace_crossover!,
    trace_mutation_attempts!,
    trace_mutation_step!
using ...UtilsModule: strictmap

"""
One precomposed mutation-middleware layer.
"""
struct MutationStepLayer{W,F}
    wrapper::W
    next_step::F
end
@inline function (layer::MutationStepLayer)(parent)
    return layer.wrapper(parent, layer.next_step)
end

build_mutation_step(::Tuple{}, base_step) = base_step
function build_mutation_step(wrappers::Tuple, base_step::F) where {F}
    inner = build_mutation_step(Base.tail(wrappers), base_step)
    return _add_mutation_step_layer(first(wrappers), inner)
end
_add_mutation_step_layer(::Nothing, inner) = inner
function _add_mutation_step_layer(wrapper, inner)  # COV_EXCL_LINE
    return MutationStepLayer(wrapper, inner)
end

"""
Engine-owned state for one mutation step. Mutable contents accumulate every
middleware attempt so evaluation counts, Hall-of-Fame updates, and tracing
stay under engine control.
"""
struct MutationStep{D,P,O,S,E,H,A,M,R}
    dataset::D
    population::P
    curmaxsize::Int
    options::O
    plugin_states::S
    eval_context::E
    best_seen::H
    attempted_results::A
    attempted_members::M
    traced_steps::R
end

function (step::MutationStep)(parent)
    step_trace = new_step_trace(step.traced_steps)
    member, accepted, num_evals = next_generation(
        step.dataset,
        parent,
        step.curmaxsize,
        step.options;
        tmp_trace=step_trace,
        plugin_states=step.plugin_states,
        eval_context=step.eval_context,
        population_for_backsolve=step.population,
    )
    attempt_id = isnothing(step.attempted_results) ? 1 : length(step.attempted_results) + 1
    result = MutationStepResult(member, accepted, attempt_id, num_evals)
    !isnothing(step.attempted_results) && push!(step.attempted_results, result)
    !isnothing(step.attempted_members) && push!(step.attempted_members, copy(member))
    trace_mutation_step!(step.traced_steps, parent, member, step_trace)
    accepted &&
        !isnothing(step.attempted_members) &&
        update_hall_of_fame!(step.best_seen, member, step.options)
    return result
end

function reset!(step::MutationStep)
    !isnothing(step.attempted_results) && empty!(step.attempted_results)
    !isnothing(step.attempted_members) && empty!(step.attempted_members)
    reset_traced_steps!(step.traced_steps)
    return nothing
end

# Pass through the population several times, replacing the oldest
# with the fittest of a small subsample
function reg_evol_cycle(
    dataset::Dataset{T,L},
    pop::P,
    curmaxsize::Int,
    options::AbstractOptions,
    trace::MaybeTrace;
    plugin_states::Tuple,
    best_seen::HallOfFame,
    eval_context=nothing,
)::Tuple{P,Float64} where {T<:DATA_TYPE,L<:LOSS_TYPE,P<:Population{T,L}}
    num_evals = 0.0
    n_evol_cycles = ceil(Int, pop.n / options.tournament_selection_n)
    mutation_wrappers = strictmap(wrap_mutation_step, plugin_states, options.plugins)
    traced_steps = new_traced_steps(trace, eltype(pop.members))
    has_mutation_wrappers = any(!isnothing, mutation_wrappers)
    attempted_results =
        has_mutation_wrappers ? MutationStepResult{eltype(pop.members)}[] : nothing
    attempted_members = has_mutation_wrappers ? eltype(pop.members)[] : nothing
    base_step = MutationStep(
        dataset,
        pop,
        curmaxsize,
        options,
        plugin_states,
        eval_context,
        best_seen,
        attempted_results,
        attempted_members,
        traced_steps,
    )
    wrapped_step = build_mutation_step(mutation_wrappers, base_step)

    for i in 1:n_evol_cycles
        if rand() > options.crossover_probability
            allstar = best_of_sample(pop, options; plugin_states)
            reset!(base_step)
            result = wrapped_step(allstar)
            selected_attempt_idx = result.attempt_id
            selected_result = if isnothing(base_step.attempted_results)
                num_evals += result.num_evals
                result
            else
                checkbounds(Bool, base_step.attempted_results, selected_attempt_idx) ||
                    throw(
                        ArgumentError(
                            "Mutation middleware must return a result from `next_step`."
                        ),
                    )
                num_evals += sum(attempt -> attempt.num_evals, base_step.attempted_results)
                base_step.attempted_results[selected_attempt_idx]
            end
            baby = if isnothing(base_step.attempted_members)
                selected_result.member
            else
                base_step.attempted_members[selected_attempt_idx]
            end
            mutation_accepted = selected_result.accepted

            should_replace = mutation_accepted || !options.skip_mutation_failures
            oldest = should_replace ? argmin(i -> pop.members[i].birth, 1:(pop.n)) : 0

            trace_mutation_attempts!(
                trace,
                traced_steps,
                pop,
                oldest,
                should_replace,
                selected_attempt_idx,
                options,
            )

            should_replace || continue
            pop.members[oldest] = baby

        else # Crossover
            allstar1 = best_of_sample(pop, options; plugin_states)
            allstar2 = best_of_sample(pop, options; plugin_states)
            # `crossover_trees` errors on identical inputs (`tree1 === tree2`). The
            # parents are only read, so a copy of one is enough when both
            # tournaments picked the same member.
            allstar1 === allstar2 && (allstar2 = copy(allstar2))

            crossover_trace = new_trace(trace)
            baby1, baby2, crossover_accepted, tmp_num_evals = crossover_generation(
                allstar1,
                allstar2,
                dataset,
                curmaxsize,
                options;
                trace=crossover_trace,
                plugin_states,
                eval_context,
            )
            num_evals += tmp_num_evals
            if crossover_accepted
                _update_hall_of_fame_unchecked!(
                    best_seen, baby1, compute_complexity(baby1, options)
                )
                _update_hall_of_fame_unchecked!(
                    best_seen, baby2, compute_complexity(baby2, options)
                )
            end

            if !crossover_accepted
                options.skip_mutation_failures && continue
                # The tournament winners are the population's own members;
                # inserting them again needs distinct objects.
                baby1, baby2 = copy(baby1), copy(baby2)
            end

            # Find the oldest members to replace:
            oldest1 = argmin(i -> pop.members[i].birth, 1:(pop.n))
            oldest2 = argmin(
                i -> i == oldest1 ? typemax(Int) : pop.members[i].birth, 1:(pop.n)
            )

            trace_crossover!(
                trace,
                allstar1,
                allstar2,
                baby1,
                baby2,
                pop,
                oldest1,
                oldest2,
                crossover_trace,
                options,
            )

            # Replace old members with new ones:
            pop.members[oldest1] = baby1
            pop.members[oldest2] = baby2
        end
    end

    return (pop, num_evals)
end

end
