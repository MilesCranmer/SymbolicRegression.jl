module MutateModule

import ..CoreModule: Node, copy_node, Options, Dataset, RecordType
import ..EquationUtilsModule: compute_complexity, count_constants, count_depth
import ..LossFunctionsModule: score_func, score_func_batch
import ..CheckConstraintsModule: check_constraints
import ..AdaptiveParsimonyModule: RunningSearchStatistics
import ..PopMemberModule: PopMember
import ..MutationFunctionsModule:
    gen_random_tree_fixed_size,
    mutate_constant,
    mutate_operator,
    append_random_op,
    prepend_random_op,
    insert_random_op,
    delete_random_op,
    crossover_trees
import ..SimplifyEquationModule: simplify_tree, combine_operators
import ..RecorderModule: @recorder

# Go through one simulated options.annealing mutation cycle
#  exp(-delta/T) defines probability of accepting a change
function next_generation(
    dataset::Dataset{T},
    member::PopMember{T},
    temperature::T,
    curmaxsize::Int,
    running_search_statistics::RunningSearchStatistics,
    options::Options;
    tmp_recorder::RecordType,
)::Tuple{PopMember{T},Bool,Float64} where {T<:Real}
    prev = member.tree
    parent_ref = member.ref
    tree = prev
    mutation_accepted = false
    num_evals = 0.0

    #TODO - reconsider this
    if options.batching
        beforeScore, beforeLoss = score_func_batch(dataset, prev, options)
        num_evals += (options.batchSize / dataset.n)
    else
        beforeScore = member.score
        beforeLoss = member.loss
    end

    nfeatures = dataset.nfeatures

    mutationChoice = rand()
    #More constants => more likely to do constant mutation
    weightAdjustmentMutateConstant = min(8, count_constants(prev)) / 8.0
    cur_weights = copy(options.mutationWeights) .* 1.0
    cur_weights[1] *= weightAdjustmentMutateConstant
    n = compute_complexity(prev, options)
    depth = count_depth(prev)

    # If equation too big, don't add new operators
    if n >= curmaxsize || depth >= options.maxdepth
        cur_weights[3] = 0.0
        cur_weights[4] = 0.0
    end
    cur_weights /= sum(cur_weights)
    cweights = cumsum(cur_weights)

    successful_mutation = false
    #TODO: Currently we dont take this \/ into account
    is_success_always_possible = true
    attempts = 0
    max_attempts = 10

    #############################################
    # Mutations
    #############################################
    while (!successful_mutation) && attempts < max_attempts
        tree = copy_node(prev)
        successful_mutation = true
        if mutationChoice < cweights[1]
            tree = mutate_constant(tree, temperature, options)
            @recorder tmp_recorder["type"] = "constant"

            is_success_always_possible = true
            # Mutating a constant shouldn't invalidate an already-valid function

        elseif mutationChoice < cweights[2]
            tree = mutate_operator(tree, options)

            @recorder tmp_recorder["type"] = "operator"

            is_success_always_possible = true
            # Can always mutate to the same operator

        elseif mutationChoice < cweights[3]
            if rand() < 0.5
                tree = append_random_op(tree, options, nfeatures)
                @recorder tmp_recorder["type"] = "append_op"
            else
                tree = prepend_random_op(tree, options, nfeatures)
                @recorder tmp_recorder["type"] = "prepend_op"
            end
            is_success_always_possible = false
            # Can potentially have a situation without success
        elseif mutationChoice < cweights[4]
            tree = insert_random_op(tree, options, nfeatures)
            @recorder tmp_recorder["type"] = "insert_op"
            is_success_always_possible = false
        elseif mutationChoice < cweights[5]
            tree = delete_random_op(tree, options, nfeatures)
            @recorder tmp_recorder["type"] = "delete_op"
            is_success_always_possible = true
        elseif mutationChoice < cweights[6]
            tree = simplify_tree(tree, options) # Sometimes we simplify tree
            tree = combine_operators(tree, options) # See if repeated constants at outer levels
            @recorder tmp_recorder["type"] = "partial_simplify"
            mutation_accepted = true
            return (
                PopMember(
                    tree,
                    beforeScore,
                    beforeLoss;
                    parent=parent_ref,
                    deterministic=options.deterministic,
                ),
                mutation_accepted,
                num_evals,
            )

            is_success_always_possible = true
            # Simplification shouldn't hurt complexity; unless some non-symmetric constraint
            # to commutative operator...

        elseif mutationChoice < cweights[7]
            # Sometimes we generate a new tree completely tree
            # We select a random size, though the generated tree
            # may have fewer nodes than we request.
            tree_size_to_generate = rand(1:curmaxsize)
            tree = gen_random_tree_fixed_size(tree_size_to_generate, options, nfeatures, T)
            @recorder tmp_recorder["type"] = "regenerate"

            is_success_always_possible = true
        else # no mutation applied
            @recorder begin
                tmp_recorder["type"] = "identity"
                tmp_recorder["result"] = "accept"
                tmp_recorder["reason"] = "identity"
            end
            mutation_accepted = true
            return (
                PopMember(
                    tree,
                    beforeScore,
                    beforeLoss;
                    parent=parent_ref,
                    deterministic=options.deterministic,
                ),
                mutation_accepted,
                num_evals,
            )
        end

        successful_mutation =
            successful_mutation && check_constraints(tree, options, curmaxsize)

        attempts += 1
    end
    #############################################

    if !successful_mutation
        @recorder begin
            tmp_recorder["result"] = "reject"
            tmp_recorder["reason"] = "failed_constraint_check"
        end
        mutation_accepted = false
        return (
            PopMember(
                copy_node(prev),
                beforeScore,
                beforeLoss;
                parent=parent_ref,
                deterministic=options.deterministic,
            ),
            mutation_accepted,
            num_evals,
        )
    end

    if options.batching
        afterScore, afterLoss = score_func_batch(dataset, tree, options)
        num_evals += (options.batchSize / dataset.n)
    else
        afterScore, afterLoss = score_func(dataset, tree, options)
        num_evals += 1
    end

    if isnan(afterScore)
        @recorder begin
            tmp_recorder["result"] = "reject"
            tmp_recorder["reason"] = "nan_loss"
        end
        mutation_accepted = false
        return (
            PopMember(
                copy_node(prev),
                beforeScore,
                beforeLoss;
                parent=parent_ref,
                deterministic=options.deterministic,
            ),
            mutation_accepted,
            num_evals,
        )
    end

    probChange = 1.0
    if options.annealing
        delta = afterScore - beforeScore
        probChange *= exp(-delta / (temperature * options.alpha))
    end
    if options.useFrequency
        oldSize = compute_complexity(prev, options)
        newSize = compute_complexity(tree, options)
        old_frequency = if (oldSize <= options.maxsize)
            running_search_statistics.frequencies[oldSize]
        else
            1e-6
        end
        new_frequency = if (newSize <= options.maxsize)
            running_search_statistics.frequencies[newSize]
        else
            1e-6
        end
        probChange *= old_frequency / new_frequency
    end

    if probChange < rand()
        @recorder begin
            tmp_recorder["result"] = "reject"
            tmp_recorder["reason"] = "annealing_or_frequency"
        end
        mutation_accepted = false
        return (
            PopMember(
                copy_node(prev),
                beforeScore,
                beforeLoss;
                parent=parent_ref,
                deterministic=options.deterministic,
            ),
            mutation_accepted,
            num_evals,
        )
    else
        @recorder begin
            tmp_recorder["result"] = "accept"
            tmp_recorder["reason"] = "pass"
        end
        mutation_accepted = true
        return (
            PopMember(
                tree,
                afterScore,
                afterLoss;
                parent=parent_ref,
                deterministic=options.deterministic,
            ),
            mutation_accepted,
            num_evals,
        )
    end
end

"""Generate a generation via crossover of two members."""
function crossover_generation(
    member1::PopMember,
    member2::PopMember,
    dataset::Dataset{T},
    curmaxsize::Int,
    options::Options,
)::Tuple{PopMember,PopMember,Bool,Float64} where {T<:Real}
    tree1 = member1.tree
    tree2 = member2.tree
    crossover_accepted = false

    # We breed these until constraints are no longer violated:
    child_tree1, child_tree2 = crossover_trees(tree1, tree2)
    num_tries = 1
    max_tries = 10
    num_evals = 0.0
    while true
        # Both trees satisfy constraints
        if check_constraints(child_tree1, options, curmaxsize) &&
            check_constraints(child_tree2, options, curmaxsize)
            break
        end
        if num_tries > max_tries
            crossover_accepted = false
            return member1, member2, crossover_accepted, num_evals  # Fail.
        end
        child_tree1, child_tree2 = crossover_trees(tree1, tree2)
        num_tries += 1
    end
    if options.batching
        afterScore1, afterLoss1 = score_func_batch(dataset, child_tree1, options)
        afterScore2, afterLoss2 = score_func_batch(dataset, child_tree2, options)
        num_evals += 2 * (options.batchSize / dataset.n)
    else
        afterScore1, afterLoss1 = score_func(dataset, child_tree1, options)
        afterScore2, afterLoss2 = score_func(dataset, child_tree2, options)
        num_evals += options.batchSize / dataset.n
    end

    baby1 = PopMember(
        child_tree1,
        afterScore1,
        afterLoss1;
        parent=member1.ref,
        deterministic=options.deterministic,
    )
    baby2 = PopMember(
        child_tree2,
        afterScore2,
        afterLoss2;
        parent=member2.ref,
        deterministic=options.deterministic,
    )

    crossover_accepted = true
    return baby1, baby2, crossover_accepted, num_evals
end

end
