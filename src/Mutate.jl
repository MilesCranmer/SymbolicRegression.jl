module MutateModule

using DynamicExpressions:
    AbstractExpression,
    ParametricExpression,
    Node,
    with_contents,
    get_tree,
    preserve_sharing,
    copy_node,
    count_nodes,
    count_constants,
    simplify_tree!,
    combine_operators
using ..CoreModule:
    Options, MutationWeights, Dataset, RecordType, sample_mutation, DATA_TYPE, LOSS_TYPE
using ..ComplexityModule: compute_complexity
using ..LossFunctionsModule: score_func, score_func_batched
using ..CheckConstraintsModule: check_constraints
using ..AdaptiveParsimonyModule: RunningSearchStatistics
using ..PopMemberModule: PopMember
using ..MutationFunctionsModule:
    gen_random_tree_fixed_size,
    mutate_constant,
    mutate_operator,
    swap_operands,
    append_random_op,
    prepend_random_op,
    insert_random_op,
    delete_random_op!,
    crossover_trees,
    form_random_connection!,
    break_random_connection!
using ..ConstantOptimizationModule: optimize_constants
using ..RecorderModule: @recorder

function condition_mutation_weights!(
    weights::MutationWeights, member::PopMember, options::Options, curmaxsize::Int
)
    tree = get_tree(member.tree)
    if !preserve_sharing(typeof(member.tree))
        weights.form_connection = 0.0
        weights.break_connection = 0.0
    end
    if tree.degree == 0
        # If equation is too small, don't delete operators
        # or simplify
        weights.mutate_operator = 0.0
        weights.swap_operands = 0.0
        weights.delete_node = 0.0
        weights.simplify = 0.0
        if !tree.constant
            weights.optimize = 0.0
            weights.mutate_constant = 0.0
        end
        return nothing
    end

    if !any(node -> node.degree == 2, tree)
        # swap is implemented only for binary ops
        weights.swap_operands = 0.0
    end

    if !(member.tree isa ParametricExpression)  # TODO: HACK
        #More constants => more likely to do constant mutation
        let n_constants = count_constants(member.tree)
            weights.mutate_constant *= min(8, n_constants) / 8.0
        end
    end
    complexity = compute_complexity(member, options)

    if complexity >= curmaxsize
        # If equation is too big, don't add new operators
        weights.add_node = 0.0
        weights.insert_node = 0.0
    end

    if !options.should_simplify
        weights.simplify = 0.0
    end

    return nothing
end

# Go through one simulated options.annealing mutation cycle
#  exp(-delta/T) defines probability of accepting a change
function next_generation(
    dataset::D,
    member::P,
    temperature,
    curmaxsize::Int,
    running_search_statistics::RunningSearchStatistics,
    options::Options;
    tmp_recorder::RecordType,
)::Tuple{
    P,Bool,Float64
} where {T,L,D<:Dataset{T,L},N<:AbstractExpression{T},P<:PopMember{T,L,N}}
    parent_ref = member.ref
    mutation_accepted = false
    num_evals = 0.0

    #TODO - reconsider this
    beforeScore, beforeLoss = if options.batching
        num_evals += (options.batch_size / dataset.n)
        score_func_batched(dataset, member, options)
    else
        member.score, member.loss
    end

    nfeatures = dataset.nfeatures

    weights = copy(options.mutation_weights)

    condition_mutation_weights!(weights, member, options, curmaxsize)

    mutation_choice = sample_mutation(weights)

    successful_mutation = false
    #TODO: Currently we dont take this \/ into account
    is_success_always_possible = true
    attempts = 0
    max_attempts = 10

    #############################################
    # Mutations
    #############################################
    local tree
    while (!successful_mutation) && attempts < max_attempts
        tree = copy_node(member.tree)
        successful_mutation = true
        if mutation_choice == :mutate_constant
            tree = mutate_constant(tree, temperature, options)
            @recorder tmp_recorder["type"] = "constant"
            is_success_always_possible = true
            # Mutating a constant shouldn't invalidate an already-valid function
        elseif mutation_choice == :mutate_operator
            tree = mutate_operator(tree, options)
            @recorder tmp_recorder["type"] = "operator"
            is_success_always_possible = true
            # Can always mutate to the same operator

        elseif mutation_choice == :swap_operands
            tree = swap_operands(tree)
            @recorder tmp_recorder["type"] = "swap_operands"
            is_success_always_possible = true

        elseif mutation_choice == :add_node
            if rand() < 0.5
                tree = append_random_op(tree, options, nfeatures)
                @recorder tmp_recorder["type"] = "append_op"
            else
                tree = prepend_random_op(tree, options, nfeatures)
                @recorder tmp_recorder["type"] = "prepend_op"
            end
            is_success_always_possible = false
            # Can potentially have a situation without success
        elseif mutation_choice == :insert_node
            tree = insert_random_op(tree, options, nfeatures)
            @recorder tmp_recorder["type"] = "insert_op"
            is_success_always_possible = false
        elseif mutation_choice == :delete_node
            tree = delete_random_op!(tree, options, nfeatures)
            @recorder tmp_recorder["type"] = "delete_op"
            is_success_always_possible = true
        elseif mutation_choice == :simplify
            @assert options.should_simplify
            simplify_tree!(tree, options.operators)
            tree = combine_operators(tree, options.operators)
            @recorder tmp_recorder["type"] = "partial_simplify"
            mutation_accepted = true
            is_success_always_possible = true
            return (
                PopMember(
                    tree,
                    beforeScore,
                    beforeLoss,
                    options;
                    parent=parent_ref,
                    deterministic=options.deterministic,
                ),
                mutation_accepted,
                num_evals,
            )
            # Simplification shouldn't hurt complexity; unless some non-symmetric constraint
            # to commutative operator...
        elseif mutation_choice == :randomize
            # We select a random size, though the generated tree
            # may have fewer nodes than we request.
            tree_size_to_generate = rand(1:curmaxsize)
            tree = with_contents(
                tree,
                gen_random_tree_fixed_size(tree_size_to_generate, options, nfeatures, T),
            )
            @recorder tmp_recorder["type"] = "regenerate"

            is_success_always_possible = true
        elseif mutation_choice == :optimize
            cur_member = PopMember(
                tree,
                beforeScore,
                beforeLoss,
                options,
                compute_complexity(member, options);
                parent=parent_ref,
                deterministic=options.deterministic,
            )
            cur_member, new_num_evals = optimize_constants(dataset, cur_member, options)
            num_evals += new_num_evals
            @recorder tmp_recorder["type"] = "optimize"
            mutation_accepted = true
            is_success_always_possible = true
            return (cur_member, mutation_accepted, num_evals)
        elseif mutation_choice == :do_nothing
            @recorder begin
                tmp_recorder["type"] = "identity"
                tmp_recorder["result"] = "accept"
                tmp_recorder["reason"] = "identity"
            end
            mutation_accepted = true
            is_success_always_possible = true
            return (
                PopMember(
                    tree,
                    beforeScore,
                    beforeLoss,
                    options,
                    compute_complexity(member, options);
                    parent=parent_ref,
                    deterministic=options.deterministic,
                ),
                mutation_accepted,
                num_evals,
            )
        elseif mutation_choice == :form_connection
            tree = form_random_connection!(tree)
            @recorder tmp_recorder["type"] = "form_connection"
            is_success_always_possible = true
        elseif mutation_choice == :break_connection
            tree = break_random_connection!(tree)
            @recorder tmp_recorder["type"] = "break_connection"
            is_success_always_possible = true
        else
            error("Unknown mutation choice: $mutation_choice")
        end

        successful_mutation =
            successful_mutation && check_constraints(tree, options, curmaxsize)

        attempts += 1
    end
    #############################################
    tree::AbstractExpression

    if !successful_mutation
        @recorder begin
            tmp_recorder["result"] = "reject"
            tmp_recorder["reason"] = "failed_constraint_check"
        end
        mutation_accepted = false
        return (
            PopMember(
                copy_node(member.tree),
                beforeScore,
                beforeLoss,
                options,
                compute_complexity(member, options);
                parent=parent_ref,
                deterministic=options.deterministic,
            ),
            mutation_accepted,
            num_evals,
        )
    end

    if options.batching
        afterScore, afterLoss = score_func_batched(dataset, tree, options)
        num_evals += (options.batch_size / dataset.n)
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
                copy_node(member.tree),
                beforeScore,
                beforeLoss,
                options,
                compute_complexity(member, options);
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
    newSize = -1
    if options.use_frequency
        oldSize = compute_complexity(member, options)
        newSize = compute_complexity(tree, options)
        old_frequency = if (0 < oldSize <= options.maxsize)
            running_search_statistics.normalized_frequencies[oldSize]
        else
            1e-6
        end
        new_frequency = if (0 < newSize <= options.maxsize)
            running_search_statistics.normalized_frequencies[newSize]
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
                copy_node(member.tree),
                beforeScore,
                beforeLoss,
                options,
                compute_complexity(member, options);
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
                afterLoss,
                options,
                newSize;
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
    member1::P, member2::P, dataset::D, curmaxsize::Int, options::Options
)::Tuple{P,P,Bool,Float64} where {T,L,D<:Dataset{T,L},N,P<:PopMember{T,L,N}}
    tree1 = member1.tree
    tree2 = member2.tree
    crossover_accepted = false

    # We breed these until constraints are no longer violated:
    child_tree1, child_tree2 = crossover_trees(tree1, tree2)
    num_tries = 1
    max_tries = 10
    num_evals = 0.0
    afterSize1 = -1
    afterSize2 = -1
    while true
        afterSize1 = compute_complexity(child_tree1, options)
        afterSize2 = compute_complexity(child_tree2, options)
        # Both trees satisfy constraints
        if check_constraints(child_tree1, options, curmaxsize, afterSize1) &&
            check_constraints(child_tree2, options, curmaxsize, afterSize2)
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
        afterScore1, afterLoss1 = score_func_batched(
            dataset, child_tree1, options; complexity=afterSize1
        )
        afterScore2, afterLoss2 = score_func_batched(
            dataset, child_tree2, options; complexity=afterSize2
        )
        num_evals += 2 * (options.batch_size / dataset.n)
    else
        afterScore1, afterLoss1 = score_func(
            dataset, child_tree1, options; complexity=afterSize1
        )
        afterScore2, afterLoss2 = score_func(
            dataset, child_tree2, options; complexity=afterSize2
        )
        num_evals += options.batch_size / dataset.n
    end

    baby1 = PopMember(
        child_tree1,
        afterScore1,
        afterLoss1,
        options,
        afterSize1;
        parent=member1.ref,
        deterministic=options.deterministic,
    )::P
    baby2 = PopMember(
        child_tree2,
        afterScore2,
        afterLoss2,
        options,
        afterSize2;
        parent=member2.ref,
        deterministic=options.deterministic,
    )::P

    crossover_accepted = true
    return baby1, baby2, crossover_accepted, num_evals
end

end
