module SingleIterationModule

using DynamicExpressions: AbstractExpression, EvalContext, simplify_tree!, combine_operators
using ..UtilsModule: strictmap
using ..CoreModule:
    AbstractOptions,
    Dataset,
    MaybeTrace,
    create_expression,
    batch,
    get_batch_size,
    batching_required,
    on_cycle_start!,
    on_cycle_end!
using ..PopMemberModule: generate_reference
using ..PopulationModule: Population, finalize_costs
using ..HallOfFameModule: HallOfFame, _update_hall_of_fame_unchecked!
using ..RegularizedEvolutionModule: reg_evol_cycle
using ..LossFunctionsModule: create_eval_context, grow_eval_context!, eval_cost
using ..ConstantOptimizationModule: optimize_constants
using ..TracingModule: trace_optimization!

# Cycle through regularized evolution many times,
# printing the fittest equation every 10% through
function s_r_cycle(
    dataset::D,
    pop::P,
    ncycles::Int,
    curmaxsize::Int;
    verbosity::Int=0,
    options::AbstractOptions,
    trace::MaybeTrace,
    plugin_states::Tuple,
    eval_context=nothing,
)::Tuple{
    P,HallOfFame{T,L,N},Float64
} where {T,L,D<:Dataset{T,L},N<:AbstractExpression{T},P<:Population{T,L,N}}
    best_examples_seen = HallOfFame(options, dataset)
    num_evals = 0.0

    batched_dataset = if batching_required(options, dataset)
        batch(dataset, get_batch_size(options, dataset.n))
    else
        dataset
    end
    eval_context = _cycle_eval_context(eval_context, batched_dataset, options, curmaxsize)

    for cycle_idx in 1:ncycles
        _on_cycle_start!(plugin_states, cycle_idx, ncycles, options)
        pop, tmp_num_evals = reg_evol_cycle(
            batched_dataset,
            pop,
            curmaxsize,
            options,
            trace;
            plugin_states,
            best_seen=best_examples_seen,
            eval_context,
        )
        num_evals += tmp_num_evals
        _update_hall_of_fame_unchecked!(best_examples_seen, pop.members, options)
        _on_cycle_end!(plugin_states, pop, batched_dataset, best_examples_seen, options)
    end

    return (pop, best_examples_seen, num_evals)
end
function _cycle_eval_context(::Nothing, dataset, options, num_arrays)
    return create_eval_context(dataset, options, num_arrays)
end
function _cycle_eval_context(context::EvalContext, dataset, options, num_arrays)
    return grow_eval_context!(context, dataset, num_arrays)
end

# The plugin hooks live in their own functions: a closure inside the loop above
# would box `pop` (it is reassigned there) and re-materialize `options` each cycle.
function _on_cycle_start!(plugin_states, cycle_idx, ncycles, options)
    strictmap(options.plugins, plugin_states) do plugin, pstate
        return on_cycle_start!(pstate, plugin, cycle_idx, ncycles, options)
    end
    return nothing
end
function _on_cycle_end!(plugin_states, pop, dataset, best_examples_seen, options)
    strictmap(options.plugins, plugin_states) do plugin, pstate
        return on_cycle_end!(pstate, plugin, pop, dataset, best_examples_seen, options)
    end
    return nothing
end

function optimize_and_simplify_population(
    dataset::D, pop::P, options::AbstractOptions, curmaxsize::Int, trace::MaybeTrace
)::Tuple{P,Float64} where {T,L,D<:Dataset{T,L},P<:Population{T,L}}
    array_num_evals = zeros(Float64, pop.n)
    do_optimization = rand(pop.n) .< options.optimizer_probability

    batched_dataset = if batching_required(options, dataset)
        batch(dataset, get_batch_size(options, dataset.n))
    else
        dataset
    end

    for j in 1:(pop.n)
        if options.should_simplify
            tree = pop.members[j].tree
            tree = simplify_tree!(tree, options.operators)
            tree = combine_operators(tree, options.operators)
            pop.members[j].tree = tree
        end
        if options.should_optimize_constants && do_optimization[j]
            # TODO: Might want to do full batch optimization here?
            pop.members[j], array_num_evals[j] = optimize_constants(
                batched_dataset, pop.members[j], options
            )
        end
    end
    num_evals = sum(array_num_evals)
    pop, tmp_num_evals = finalize_costs(dataset, pop, options)
    num_evals += tmp_num_evals

    # Now, we create new references for every member.
    for j in 1:(pop.n)
        old_ref = pop.members[j].ref
        new_ref = generate_reference()
        pop.members[j].parent = old_ref
        pop.members[j].ref = new_ref

        trace_optimization!(
            trace, pop.members[j], old_ref, new_ref, do_optimization[j], options
        )
    end
    return (pop, num_evals)
end

end
