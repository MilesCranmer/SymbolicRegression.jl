module CrossoverModule

using DispatchDoctor: @unstable
using DynamicExpressions: AbstractExpression
using ...InterfacesModule:
    AbstractOptions,
    AbstractCrossover,
    SubtreeCrossover,
    BUILTIN_CROSSOVER_TYPES,
    Dataset,
    max_features,
    dataset_fraction,
    MaybeTrace
using ...EvaluationModule: compute_complexity, eval_cost, check_constraints
using ..PopMemberModule: AbstractPopMember, create_child
using ..MutationFunctionsModule: crossover_trees
using ..MutateModule: _sample_mutation
using ..TracingModule: trace_mutation_result!, trace_mutation_type!

"""
    CrossoverResult{N<:AbstractExpression}

Represents the result of a crossover operation. This struct is used to return
values from [`crossover`](@ref) functions.

# Fields

- `child1::N`: The first child expression tree.
- `child2::N`: The second child expression tree.
- `num_evals::Float64`: The number of evaluations performed during the
  crossover, which is automatically set to `0.0`.
"""
struct CrossoverResult{N<:AbstractExpression}
    child1::N
    child2::N
    num_evals::Float64

    function CrossoverResult{_N}(;
        child1::_N, child2::_N, num_evals::Float64=0.0
    ) where {_N<:AbstractExpression}
        return new{_N}(child1, child2, num_evals)
    end
end

"""
    crossover(
        member1::P,
        member2::P,
        c::AbstractCrossover,
        options::AbstractOptions;
        kws...,
    ) where {P<:AbstractPopMember}

Combine the two parents into a pair of child trees. Called by
`crossover_generation` with the crossover kind sampled by weight from
`options.crossovers`.

Add a new crossover by defining a struct subtyping
[`AbstractCrossover`](@ref) and a matching `crossover` method.

# Keywords

- `dataset::Dataset`: The dataset used for scoring.
- `curmaxsize`: The current maximum size constraint, which may differ from `options.maxsize`.
- `nfeatures`: The number of features in the dataset.
- `attempt::Int`: 1-based attempt number within the engine's constraint-retry
  loop. Expensive crossovers can behave differently on retries, e.g. return
  copies of the parents' trees instead of re-running.
- `trace::MaybeTrace`: Crossover tracing state, or `nothing` when tracing is disabled.
- `plugin_states::Tuple`: The active worker plugin states, in tuple order matching
  `options.plugins`.

# Returns

A `CrossoverResult{N}` holding the two child trees and the number of
evaluations performed, if any. The engine owns constraint checking (retrying
this method up to its attempt limit), evaluation, and population replacement.
"""
function crossover(member1, member2, c::AbstractCrossover, options; kws...)
    return error("Unknown crossover type: $(typeof(c))")
end

function crossover(
    member1::P,
    member2::P,
    ::SubtreeCrossover,
    options::AbstractOptions;
    trace::MaybeTrace,
    kws...,
) where {T,L,N<:AbstractExpression,P<:AbstractPopMember{T,L,N}}
    child_tree1, child_tree2 = crossover_trees(member1.tree, member2.tree)
    trace_mutation_type!(trace, "subtree_crossover")
    return CrossoverResult{N}(; child1=child_tree1, child2=child_tree2)
end

let crossover_types = BUILTIN_CROSSOVER_TYPES
    @eval @inline function _dispatch_crossover_generation(c::AbstractCrossover, args...)
        Base.Cartesian.@nif(
            $(length(crossover_types) + 1),
            i -> c isa $(crossover_types)[i],  # COV_EXCL_LINE
            i -> _crossover_generation(c::$(crossover_types)[i], args...),  # COV_EXCL_LINE
            i -> _crossover_generation(c, args...),  # COV_EXCL_LINE
        )
    end
end

"""Generate a generation via crossover of two members."""
@unstable function crossover_generation(
    member1::P,
    member2::P,
    dataset::D,
    curmaxsize::Int,
    options::AbstractOptions;
    trace::MaybeTrace=nothing,
    eval_context=nothing,
    plugin_states::Tuple=ntuple(Returns(nothing), length(options.plugins)),
)::Tuple{P,P,Bool,Float64} where {T,L,D<:Dataset{T,L},N,P<:AbstractPopMember{T,L,N}}
    crossovers = options.crossovers
    # Skip sampling for a single entry so the default configuration consumes
    # no extra RNG draws.
    crossover_choice = if length(crossovers) == 1
        first(crossovers).first
    else
        crossovers[_sample_mutation(crossovers)].first
    end
    # Preserve concrete crossover dispatch through the hot path.
    return _dispatch_crossover_generation(
        crossover_choice,
        member1,
        member2,
        dataset,
        curmaxsize,
        options,
        trace,
        eval_context,
        plugin_states,
    )
end

function _crossover_generation(
    crossover_choice::C,
    member1::P,
    member2::P,
    dataset::D,
    curmaxsize::Int,
    options::AbstractOptions,
    trace::MaybeTrace,
    eval_context,
    plugin_states::Tuple,
)::Tuple{
    P,P,Bool,Float64
} where {T,L,D<:Dataset{T,L},N,P<:AbstractPopMember{T,L,N},C<:AbstractCrossover}
    crossover_accepted = false
    nfeatures = max_features(dataset, options)

    # We breed these until constraints are no longer violated:
    num_tries = 1
    max_tries = 10
    num_evals = 0.0
    local child_tree1::N, child_tree2::N
    afterSize1 = -1
    afterSize2 = -1
    while true
        result = crossover(
            member1,
            member2,
            crossover_choice,
            options;
            trace,
            dataset,
            curmaxsize,
            nfeatures,
            attempt=num_tries,
            plugin_states,
        )::CrossoverResult{N}
        num_evals += result.num_evals
        child_tree1, child_tree2 = result.child1, result.child2
        afterSize1 = compute_complexity(child_tree1, options)
        afterSize2 = compute_complexity(child_tree2, options)
        # Both trees satisfy constraints
        if check_constraints(child_tree1, options, curmaxsize, afterSize1) &&
            check_constraints(child_tree2, options, curmaxsize, afterSize2)
            break
        end
        if num_tries >= max_tries
            trace_mutation_result!(trace, "reject", "failed_constraint_check")
            crossover_accepted = false
            return member1, member2, crossover_accepted, num_evals  # Fail.
        end
        num_tries += 1
    end
    after_cost1, after_loss1 = eval_cost(
        dataset, child_tree1, options; complexity=afterSize1, eval_context
    )
    after_cost2, after_loss2 = eval_cost(
        dataset, child_tree2, options; complexity=afterSize2, eval_context
    )
    num_evals += 2 * dataset_fraction(dataset)

    baby1 = create_child(
        (member1, member2),
        child_tree1::AbstractExpression,
        after_cost1,
        after_loss1,
        options;
        complexity=afterSize1,
        parent_ref=member1.ref,
    )::P
    baby2 = create_child(
        (member1, member2),
        child_tree2::AbstractExpression,
        after_cost2,
        after_loss2,
        options;
        complexity=afterSize2,
        parent_ref=member2.ref,
    )::P

    trace_mutation_result!(trace, "accept", "pass")

    crossover_accepted = true
    return baby1, baby2, crossover_accepted, num_evals
end

end  # module CrossoverModule
