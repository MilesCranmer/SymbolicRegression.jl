using FromFile
@from "Core.jl" import Node, copyNode, Options, Dataset
@from "EquationUtils.jl" import countNodes, countConstants, countDepth
@from "LossFunctions.jl" import scoreFunc, scoreFuncBatch
@from "CheckConstraints.jl" import check_constraints
@from "PopMember.jl" import PopMember
@from "MutationFunctions.jl" import genRandomTree, mutateConstant, mutateOperator, appendRandomOp, prependRandomOp, insertRandomOp, deleteRandomOp
@from "SimplifyEquation.jl" import simplifyTree, combineOperators, simplifyWithSymbolicUtils

# Go through one simulated options.annealing mutation cycle
#  exp(-delta/T) defines probability of accepting a change
function nextGeneration(dataset::Dataset{T},
                        baseline::T, member::PopMember, temperature::T,
                        curmaxsize::Int, frequencyComplexity::AbstractVector{T},
                        options::Options)::PopMember where {T<:Real}

    prev = member.tree
    tree = prev
    #TODO - reconsider this
    if options.batching
        beforeLoss = scoreFuncBatch(dataset, baseline, prev, options)
    else
        beforeLoss = member.score
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

            is_success_always_possible = true
            # Mutating a constant shouldn't invalidate an already-valid function

        elseif mutationChoice < cweights[2]
            tree = mutateOperator(tree, options)

            is_success_always_possible = true
            # Can always mutate to the same operator

        elseif mutationChoice < cweights[3]
            if rand() < 0.5
                tree = appendRandomOp(tree, options, nfeatures)
            else
                tree = prependRandomOp(tree, options, nfeatures)
            end
            is_success_always_possible = false
            # Can potentially have a situation without success
        elseif mutationChoice < cweights[4]
            tree = insertRandomOp(tree, options, nfeatures)
            is_success_always_possible = false
        elseif mutationChoice < cweights[5]
            tree = deleteRandomOp(tree, options, nfeatures)
            is_success_always_possible = true
        elseif mutationChoice < cweights[6]
            tree = simplifyTree(tree, options) # Sometimes we simplify tree
            tree = combineOperators(tree, options) # See if repeated constants at outer levels
            # SymbolicUtils is quite slow, so only rarely
            #  do we use it for simplification.
            if rand() < 0.01
                tree = simplifyWithSymbolicUtils(tree, options)
            end
            return PopMember(tree, beforeLoss)

            is_success_always_possible = true
            # Simplification shouldn't hurt complexity; unless some non-symmetric constraint
            # to commutative operator...

        elseif mutationChoice < cweights[7]
            tree = genRandomTree(5, options, nfeatures) # Sometimes we generate a new tree completely tree

            is_success_always_possible = true
        else # no mutation applied
            return PopMember(tree, beforeLoss)
        end

        successful_mutation = successful_mutation && check_constraints(tree, options)

        attempts += 1
    end
    #############################################

    if !successful_mutation
        return PopMember(copyNode(prev), beforeLoss)
    end

    if options.batching
        afterLoss = scoreFuncBatch(dataset, baseline, tree, options)
    else
        afterLoss = scoreFunc(dataset, baseline, tree, options)
    end

    if options.annealing
        delta = afterLoss - beforeLoss
        probChange = exp(-delta/(temperature*options.alpha))
        if options.useFrequency
            oldSize = countNodes(prev)
            newSize = countNodes(tree)
            probChange *= frequencyComplexity[oldSize] / frequencyComplexity[newSize]
        end

        return_unaltered = (isnan(afterLoss) || probChange < rand())
        if return_unaltered
            return PopMember(copyNode(prev), beforeLoss)
        end
    end
    return PopMember(tree, afterLoss)
end
