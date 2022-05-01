using FromFile
@from "Core.jl" import Node, copyNode, Options, Dataset, RecordType
@from "EquationUtils.jl" import countNodes, countConstants, countDepth
@from "LossFunctions.jl" import scoreFunc, scoreFuncBatch
@from "CheckConstraints.jl" import check_constraints
@from "PopMember.jl" import PopMember
@from "MutationFunctions.jl" import genRandomTreeFixedSize, mutateConstant, mutateOperator, appendRandomOp, prependRandomOp, insertRandomOp, deleteRandomOp, crossoverTrees
@from "SimplifyEquation.jl" import simplifyTree, combineOperators, simplifyWithSymbolicUtils
@from "Recorder.jl" import @recorder

# Go through one simulated options.annealing mutation cycle
#  exp(-delta/T) defines probability of accepting a change
function nextGeneration(dataset::Dataset{T},
                        baseline::T, member::PopMember, temperature::T,
                        curmaxsize::Int, frequencyComplexity::AbstractVector{T},
                        options::Options; tmp_recorder::RecordType)::Tuple{PopMember,Bool} where {T<:Real}

    prev = member.tree
    parent_ref = member.ref
    tree = prev
    mutation_accepted = false

    #TODO - reconsider this
    if options.batching
        beforeScore, beforeLoss = scoreFuncBatch(dataset, baseline, prev, options)
    else
        beforeScore = member.score
        beforeLoss = member.loss
    end

    nfeatures = dataset.nfeatures

    mutationChoice = rand()
    #More constants => more likely to do constant mutation
    weightAdjustmentMutateConstant = min(8, countConstants(prev))/8.0
    cur_weights = copy(options.mutationWeights) .* 1.0
    cur_weights[1] *= weightAdjustmentMutateConstant
    n = countNodes(prev)
    depth = countDepth(prev)

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
        tree = copyNode(prev)
        successful_mutation = true
        if mutationChoice < cweights[1]
            tree = mutateConstant(tree, temperature, options)
            @recorder tmp_recorder["type"] = "constant"

            is_success_always_possible = true
            # Mutating a constant shouldn't invalidate an already-valid function

        elseif mutationChoice < cweights[2]
            tree = mutateOperator(tree, options)

            @recorder tmp_recorder["type"] = "operator"

            is_success_always_possible = true
            # Can always mutate to the same operator

        elseif mutationChoice < cweights[3]
            if rand() < 0.5
                tree = appendRandomOp(tree, options, nfeatures)
                @recorder tmp_recorder["type"] = "append_op"
            else
                tree = prependRandomOp(tree, options, nfeatures)
                @recorder tmp_recorder["type"] = "prepend_op"
            end
            is_success_always_possible = false
            # Can potentially have a situation without success
        elseif mutationChoice < cweights[4]
            tree = insertRandomOp(tree, options, nfeatures)
            @recorder tmp_recorder["type"] = "insert_op"
            is_success_always_possible = false
        elseif mutationChoice < cweights[5]
            tree = deleteRandomOp(tree, options, nfeatures)
            @recorder tmp_recorder["type"] = "delete_op"
            is_success_always_possible = true
        elseif mutationChoice < cweights[6]
            tree = simplifyTree(tree, options) # Sometimes we simplify tree
            tree = combineOperators(tree, options) # See if repeated constants at outer levels
            @recorder tmp_recorder["type"] = "partial_simplify"
            mutation_accepted = true
            return PopMember(tree, beforeScore, beforeLoss, parent=parent_ref), mutation_accepted

            is_success_always_possible = true
            # Simplification shouldn't hurt complexity; unless some non-symmetric constraint
            # to commutative operator...

        elseif mutationChoice < cweights[7]
            # Sometimes we generate a new tree completely tree
            # We select a random size, though the generated tree
            # may have fewer nodes than we request.
            tree_size_to_generate = rand(1:curmaxsize)
            tree = genRandomTreeFixedSize(tree_size_to_generate, options, nfeatures)
            @recorder tmp_recorder["type"] = "regenerate"

            is_success_always_possible = true
        else # no mutation applied
            @recorder begin
                tmp_recorder["type"] = "identity"
                tmp_recorder["result"] = "accept"
                tmp_recorder["reason"] = "identity"
            end
            mutation_accepted = true
            return PopMember(tree, beforeScore, beforeLoss, parent=parent_ref), mutation_accepted
        end

        successful_mutation = successful_mutation && check_constraints(tree, options, curmaxsize)

        attempts += 1
    end
    #############################################

    if !successful_mutation
        @recorder begin
            tmp_recorder["result"] = "reject"
            tmp_recorder["reason"] = "failed_constraint_check"
        end
        mutation_accepted = false
        return PopMember(copyNode(prev), beforeScore, beforeLoss, parent=parent_ref), mutation_accepted
    end

    if options.batching
        afterScore, afterLoss = scoreFuncBatch(dataset, baseline, tree, options)
    else
        afterScore, afterLoss = scoreFunc(dataset, baseline, tree, options)
    end

    if isnan(afterScore)
        @recorder begin
            tmp_recorder["result"] = "reject"
            tmp_recorder["reason"] = "nan_loss"
        end
        mutation_accepted = false
        return PopMember(copyNode(prev), beforeScore, beforeLoss, parent=parent_ref), mutation_accepted
    end

    probChange = 1.0
    if options.annealing
        delta = afterScore - beforeScore
        probChange *= exp(-delta/(temperature*options.alpha))
    end
    if options.useFrequency
        oldSize = countNodes(prev)
        newSize = countNodes(tree)
        probChange *= frequencyComplexity[oldSize] / frequencyComplexity[newSize]
    end

    if probChange < rand()
        @recorder begin
            tmp_recorder["result"] = "reject"
            tmp_recorder["reason"] = "annealing_or_frequency"
        end
        mutation_accepted = false
        return PopMember(copyNode(prev), beforeScore, beforeLoss, parent=parent_ref), mutation_accepted
    else
        @recorder begin
            tmp_recorder["result"] = "accept"
            tmp_recorder["reason"] = "pass"
        end
        mutation_accepted = true
        return PopMember(tree, afterScore, afterLoss, parent=parent_ref), mutation_accepted
    end
end


"""Generate a generation via crossover of two members."""
function crossoverGeneration(member1::PopMember, member2::PopMember, dataset::Dataset{T},
                             baseline::T, curmaxsize::Int, options::Options)::Tuple{PopMember, PopMember, Bool} where {T<:Real}
    tree1 = member1.tree
    tree2 = member2.tree
    crossover_accepted = false

    # We breed these until constraints are no longer violated:
    child_tree1, child_tree2 = crossoverTrees(tree1, tree2)
    num_tries = 1
    max_tries = 10
    while true 
        # Both trees satisfy constraints
        if check_constraints(child_tree1, options, curmaxsize) && check_constraints(child_tree2, options, curmaxsize)
            break
        end
        if num_tries > max_tries
            crossover_accepted = false
            return member1, member2, crossover_accepted  # Fail.
        end
        child_tree1, child_tree2 = crossoverTrees(tree1, tree2)
        num_tries += 1
    end
    if options.batching
        afterScore1, afterLoss1 = scoreFuncBatch(dataset, baseline, child_tree1, options)
        afterScore2, afterLoss2 = scoreFuncBatch(dataset, baseline, child_tree2, options)
    else
        afterScore1, afterLoss1 = scoreFunc(dataset, baseline, child_tree1, options)
        afterScore2, afterLoss2 = scoreFunc(dataset, baseline, child_tree2, options)
    end

    baby1 = PopMember(child_tree1, afterScore1, afterLoss1, parent=member1.ref)
    baby2 = PopMember(child_tree2, afterScore2, afterLoss2, parent=member2.ref)

    crossover_accepted = true
    return baby1, baby2, crossover_accepted
end