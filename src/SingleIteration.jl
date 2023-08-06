module SingleIterationModule

import DynamicExpressions: Node, string_tree, simplify_tree, combine_operators
import ..CoreModule: Options, Dataset, RecordType, DATA_TYPE, LOSS_TYPE
import ..ComplexityModule: compute_complexity
import ..UtilsModule: debug
import ..PopMemberModule: copy_pop_member, generate_reference
import ..PopulationModule: Population, finalize_scores, best_sub_pop
import ..HallOfFameModule: HallOfFame
import ..AdaptiveParsimonyModule: RunningSearchStatistics
import ..RegularizedEvolutionModule: reg_evol_cycle
import ..LossFunctionsModule: score_func_batched, batch_sample
import ..ConstantOptimizationModule: optimize_constants
import ..RecorderModule: @recorder

# Cycle through regularized evolution many times,
# printing the fittest equation every 10% through
function s_r_cycle(
    dataset::Dataset{T,L},
    pop::Population{T,L},
    ncycles::Int,
    curmaxsize::Int,
    running_search_statistics::RunningSearchStatistics;
    verbosity::Int=0,
    options::Options,
    record::RecordType,
)::Tuple{Population{T,L},HallOfFame{T,L},Float64} where {T<:DATA_TYPE,L<:LOSS_TYPE}
    max_temp = 1.0
    min_temp = 0.0
    if !options.annealing
        min_temp = max_temp
    end
    all_temperatures = LinRange(max_temp, min_temp, ncycles)
    best_examples_seen = HallOfFame(options, T, L)
    num_evals = 0.0

    # For evaluating on a fixed batch (for batching)
    idx = options.batching ? batch_sample(dataset, options) : Int[]
    loss_cache = [(oid=Node(T; val=zero(T)), score=zero(L)) for _ in pop.members]
    first_loop = true

    for temperature in all_temperatures
        pop, tmp_num_evals = reg_evol_cycle(
            dataset,
            pop,
            temperature,
            curmaxsize,
            running_search_statistics,
            options,
            record,
        )
        num_evals += tmp_num_evals
        for (i, member) in enumerate(pop.members)
            size = compute_complexity(member, options)
            score = if options.batching
                oid = member.tree
                if loss_cache[i].oid != oid || first_loop
                    # Evaluate on fixed batch so that we can more accurately
                    # compare expressions with a batched loss (though the batch
                    # changes each iteration, and we evaluate on full-batch outside,
                    # so this is not biased).
                    _score, _ = score_func_batched(
                        dataset, member, options; complexity=size, idx=idx
                    )
                    loss_cache[i] = (oid=copy(oid), score=_score)
                    _score
                else
                    # Already evaluated this particular expression, so just use
                    # the cached score
                    loss_cache[i].score
                end
            else
                member.score
            end
            # TODO: Note that this per-population hall of fame only uses the batched
            #       loss, and is therefore innaccurate. Therefore, some expressions
            #       may be loss if a very small batch size is used.
            # - Could have different batch size for different things (smaller for constant opt)
            # - Could just recompute losses here (expensive)
            # - Average over a few batches
            # - Store multiple expressions in hall of fame
            if 0 < size <= options.maxsize && (
                !best_examples_seen.exists[size] ||
                score < best_examples_seen.members[size].score
            )
                best_examples_seen.exists[size] = true
                best_examples_seen.members[size] = copy_pop_member(member)
            end
        end
        first_loop = false
    end

    return (pop, best_examples_seen, num_evals)
end

function optimize_and_simplify_population(
    dataset::Dataset{T,L},
    pop::Population{T,L},
    options::Options,
    curmaxsize::Int,
    record::RecordType,
)::Tuple{Population{T,L},Float64} where {T<:DATA_TYPE,L<:LOSS_TYPE}
    array_num_evals = zeros(Float64, pop.n)
    do_optimization = rand(pop.n) .< options.optimizer_probability
    for j in 1:(pop.n)
        if options.should_simplify
            tree = pop.members[j].tree
            tree = simplify_tree(tree, options.operators)
            tree = combine_operators(tree, options.operators)
            pop.members[j].tree = tree
        end
        if options.should_optimize_constants && do_optimization[j]
            # TODO: Might want to do full batch optimization here?
            pop.members[j], array_num_evals[j] = optimize_constants(
                dataset, pop.members[j], options
            )
        end
    end
    num_evals = sum(array_num_evals)
    pop, tmp_num_evals = finalize_scores(dataset, pop, options)
    num_evals += tmp_num_evals

    # Now, we create new references for every member,
    # and optionally record which operations occurred.
    for j in 1:(pop.n)
        old_ref = pop.members[j].ref
        new_ref = generate_reference()
        pop.members[j].parent = old_ref
        pop.members[j].ref = new_ref

        @recorder begin
            # Same structure as in RegularizedEvolution.jl,
            # except we assume that the record already exists.
            @assert haskey(record, "mutations")
            member = pop.members[j]
            if !haskey(record["mutations"], "$(member.ref)")
                record["mutations"]["$(member.ref)"] = RecordType(
                    "events" => Vector{RecordType}(),
                    "tree" => string_tree(member.tree, options),
                    "score" => member.score,
                    "loss" => member.loss,
                    "parent" => member.parent,
                )
            end
            optimize_and_simplify_event = RecordType(
                "type" => "tuning",
                "time" => time(),
                "child" => new_ref,
                "mutation" => RecordType(
                    "type" =>
                        if (do_optimization[j] && options.should_optimize_constants)
                            "simplification_and_optimization"
                        else
                            "simplification"
                        end,
                ),
            )
            death_event = RecordType("type" => "death", "time" => time())

            push!(record["mutations"]["$(old_ref)"]["events"], optimize_and_simplify_event)
            push!(record["mutations"]["$(old_ref)"]["events"], death_event)
        end
    end
    return (pop, num_evals)
end

end
