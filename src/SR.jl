module SR

include("operators.jl")
include("hyperparams.jl")

# Types
export Population,
    Options,
    evalTreeArray,
    printTree,
    stringTree,

    #Functions:
    RunSR, 
    SRCycle

using Optim
using Printf: @printf
using Random: shuffle!, randperm
using Distributed

const maxdegree = 2


@inline function BINOP!(x::Array{Float32, 1}, y::Array{Float32, 1}, i::Int, clen::Int, options::Options)
    #TODO: Can this be metaprogrammed?
    op = options.binops[i]
    @inbounds @simd for j=1:clen
        x[j] = op(x[j], y[j])
    end
end

@inline function UNAOP!(x::Array{Float32, 1}, i::Int, clen::Int, options::Options)
    op = options.unaops[i]
    @inbounds @simd for j=1:clen
        x[j] = op(x[j])
    end
end

# Sum of square error between two arrays
function SSE(x::Array{Float32}, y::Array{Float32})::Float32
    diff = (x - y)
    return sum(diff .* diff)
end
function SSE(x::Nothing, y::Array{Float32})::Float32
    return 1f9
end

# Sum of square error between two arrays, with weights
function SSE(x::Array{Float32}, y::Array{Float32}, w::Array{Float32})::Float32
    diff = (x - y)
    return sum(diff .* diff .* w)
end
function SSE(x::Nothing, y::Array{Float32}, w::Array{Float32})::Float32
    return Nothing
end

# Mean of square error between two arrays
function MSE(x::Nothing, y::Array{Float32})::Float32
    return 1f9
end

# Mean of square error between two arrays
function MSE(x::Array{Float32}, y::Array{Float32})::Float32
    return SSE(x, y)/size(x)[1]
end

# Mean of square error between two arrays
function MSE(x::Nothing, y::Array{Float32}, w::Array{Float32})::Float32
    return 1f9
end

# Mean of square error between two arrays
function MSE(x::Array{Float32}, y::Array{Float32}, w::Array{Float32})::Float32
    return SSE(x, y, w)/sum(w)
end


function id(x::Float32)::Float32
    x
end

function debug(verbosity, string...)
    verbosity > 0 ? println(string...) : nothing
end

function getTime()::Integer
    return round(Integer, 1e3*(time()-1.6e9))
end

# Define a serialization format for the symbolic equations:
mutable struct Node
    #Holds operators, variables, constants in a tree
    degree::Integer #0 for constant/variable, 1 for cos/sin, 2 for +/* etc.
    val::Union{Float32, Integer} #Either const value, or enumerates variable
    constant::Bool #false if variable
    op::Integer #enumerates operator (separately for degree=1,2)
    l::Union{Node, Nothing}
    r::Union{Node, Nothing}

    Node(val::Float32) = new(0, val, true, 1, nothing, nothing)
    Node(val::Integer) = new(0, val, false, 1, nothing, nothing)
    Node(op::Integer, l::Node) = new(1, 0.0f0, false, op, l, nothing)
    Node(op::Integer, l::Union{Float32, Integer}) = new(1, 0.0f0, false, op, Node(l), nothing)
    Node(op::Integer, l::Node, r::Node) = new(2, 0.0f0, false, op, l, r)

    #Allow to pass the leaf value without additional node call:
    Node(op::Integer, l::Union{Float32, Integer}, r::Node) = new(2, 0.0f0, false, op, Node(l), r)
    Node(op::Integer, l::Node, r::Union{Float32, Integer}) = new(2, 0.0f0, false, op, l, Node(r))
    Node(op::Integer, l::Union{Float32, Integer}, r::Union{Float32, Integer}) = new(2, 0.0f0, false, op, Node(l), Node(r))
end

# Copy an equation (faster than deepcopy)
function copyNode(tree::Node)::Node
   if tree.degree == 0
       return Node(tree.val)
   elseif tree.degree == 1
       return Node(tree.op, copyNode(tree.l))
    else
        return Node(tree.op, copyNode(tree.l), copyNode(tree.r))
   end
end

# Count the operators, constants, variables in an equation
function countNodes(tree::Node)::Integer
    if tree.degree == 0
        return 1
    elseif tree.degree == 1
        return 1 + countNodes(tree.l)
    else
        return 1 + countNodes(tree.l) + countNodes(tree.r)
    end
end

# Count the max depth of a tree
function countDepth(tree::Node)::Integer
    if tree.degree == 0
        return 1
    elseif tree.degree == 1
        return 1 + countDepth(tree.l)
    else
        return 1 + max(countDepth(tree.l), countDepth(tree.r))
    end
end

# Convert an equation to a string
function stringTree(tree::Node, options::Options)::String
    if tree.degree == 0
        if tree.constant
            return string(tree.val)
        else
            if options.useVarMap
                return varMap[tree.val]
            else
                if options.printZeroIndex
                    return "x$(tree.val - 1)"
                else
                    return "x$(tree.val)"
                end
            end
        end
    elseif tree.degree == 1
        return "$(options.unaops[tree.op])($(stringTree(tree.l, options)))"
    else
        return "$(options.binops[tree.op])($(stringTree(tree.l, options)), $(stringTree(tree.r, options)))"
    end
end

# Print an equation
function printTree(tree::Node, options::Options)
    println(stringTree(tree, options))
end

# Return a random node from the tree
function randomNode(tree::Node)::Node
    if tree.degree == 0
        return tree
    end
    a = countNodes(tree)
    b = 0
    c = 0
    if tree.degree >= 1
        b = countNodes(tree.l)
    end
    if tree.degree == 2
        c = countNodes(tree.r)
    end

    i = rand(1:1+b+c)
    if i <= b
        return randomNode(tree.l)
    elseif i == b + 1
        return tree
    end

    return randomNode(tree.r)
end

# Count the number of unary operators in the equation
function countUnaryOperators(tree::Node)::Integer
    if tree.degree == 0
        return 0
    elseif tree.degree == 1
        return 1 + countUnaryOperators(tree.l)
    else
        return 0 + countUnaryOperators(tree.l) + countUnaryOperators(tree.r)
    end
end

# Count the number of binary operators in the equation
function countBinaryOperators(tree::Node)::Integer
    if tree.degree == 0
        return 0
    elseif tree.degree == 1
        return 0 + countBinaryOperators(tree.l)
    else
        return 1 + countBinaryOperators(tree.l) + countBinaryOperators(tree.r)
    end
end

# Count the number of operators in the equation
function countOperators(tree::Node)::Integer
    return countUnaryOperators(tree) + countBinaryOperators(tree)
end

# Randomly convert an operator into another one (binary->binary;
# unary->unary)
function mutateOperator(tree::Node, options::Options)::Node
    if countOperators(tree) == 0
        return tree
    end
    node = randomNode(tree)
    while node.degree == 0
        node = randomNode(tree)
    end
    if node.degree == 1
        node.op = rand(1:options.nuna)
    else
        node.op = rand(1:options.nbin)
    end
    return tree
end

# Count the number of constants in an equation
function countConstants(tree::Node)::Integer
    if tree.degree == 0
        return convert(Integer, tree.constant)
    elseif tree.degree == 1
        return 0 + countConstants(tree.l)
    else
        return 0 + countConstants(tree.l) + countConstants(tree.r)
    end
end

# Randomly perturb a constant
function mutateConstant(
        tree::Node, T::Float32,
        options::Options)::Node
    # T is between 0 and 1.

    if countConstants(tree) == 0
        return tree
    end
    node = randomNode(tree)
    while node.degree != 0 || node.constant == false
        node = randomNode(tree)
    end

    bottom = 0.1f0
    maxChange = options.perturbationFactor * T + 1.0f0 + bottom
    factor = maxChange^Float32(rand())
    makeConstBigger = rand() > 0.5

    if makeConstBigger
        node.val *= factor
    else
        node.val /= factor
    end

    if rand() > options.probNegate
        node.val *= -1
    end

    return tree
end


# Evaluate an equation over an array of datapoints
function evalTreeArray(tree::Node, cX::Array{Float32, 2}, options::Options)::Union{Array{Float32, 1}, Nothing}
    clen = size(cX)[1]
    if tree.degree == 0
        if tree.constant
            return fill(tree.val, clen)
        else
            return copy(cX[:, tree.val])
        end
    elseif tree.degree == 1
        cumulator = evalTreeArray(tree.l, cX, options)
        if cumulator === nothing
            return nothing
        end
        op_idx = tree.op
        UNAOP!(cumulator, op_idx, clen, options)
        @inbounds for i=1:clen
            if isinf(cumulator[i]) || isnan(cumulator[i])
                return nothing
            end
        end
        return cumulator
    else
        cumulator = evalTreeArray(tree.l, cX, options)
        if cumulator === nothing
            return nothing
        end
        array2 = evalTreeArray(tree.r, cX, options)
        if array2 === nothing
            return nothing
        end
        op_idx = tree.op
        BINOP!(cumulator, array2, op_idx, clen, options)
        @inbounds for i=1:clen
            if isinf(cumulator[i]) || isnan(cumulator[i])
                return nothing
            end
        end
        return cumulator
    end
end

# Score an equation
function scoreFunc(X::Array{Float32, 2}, y::Array{Float32, 1}, baseline::Float32, tree::Node, options::Options)::Float32
    prediction = evalTreeArray(tree, X, options)
    if prediction === nothing
        return 1f9
    end
    if options.weighted
        mse = MSE(prediction, y, weights)
    else
        mse = MSE(prediction, y)
    end
    return mse / baseline + countNodes(tree)*options.parsimony
end

# Score an equation with a small batch
function scoreFuncBatch(X::Array{Float32, 2}, y::Array{Float32, 1}, baseline::Float32, tree::Node, options::Options)::Float32
    # options.batchSize
    batch_idx = randperm(size(X)[1])[1:options.batchSize]
    batch_X = X[batch_idx, :]
    prediction = evalTreeArray(tree, batch_X, options)
    if prediction === nothing
        return 1f9
    end
    size_adjustment = 1f0
    batch_y = y[batch_idx]
    if options.weighted
        batch_w = weights[batch_idx]
        mse = MSE(prediction, batch_y, batch_w)
        size_adjustment = 1f0 * size(X)[1] / options.batchSize
    else
        mse = MSE(prediction, batch_y)
    end
    return size_adjustment * mse / baseline + countNodes(tree)*options.parsimony
end

# Add a random unary/binary operation to the end of a tree
function appendRandomOp(tree::Node, options::Options, nfeatures::Int)::Node
    node = randomNode(tree)
    while node.degree != 0
        node = randomNode(tree)
    end

    choice = rand()
    makeNewBinOp = choice < options.nbin/(options.nuna + options.nbin)
    if rand() > 0.5
        left = Float32(randn())
    else
        left = rand(1:nfeatures)
    end
    if rand() > 0.5
        right = Float32(randn())
    else
        right = rand(1:nfeatures)
    end

    if makeNewBinOp
        newnode = Node(
            rand(1:options.nbin),
            left,
            right
        )
    else
        newnode = Node(
            rand(1:options.nuna),
            left
        )
    end
    node.l = newnode.l
    node.r = newnode.r
    node.op = newnode.op
    node.degree = newnode.degree
    node.val = newnode.val
    node.constant = newnode.constant
    return tree
end

# Insert random node
function insertRandomOp(tree::Node, options::Options, nfeatures::Int)::Node
    node = randomNode(tree)
    choice = rand()
    makeNewBinOp = choice < options.nbin/(options.nuna + options.nbin)
    left = copyNode(node)

    if makeNewBinOp
        right = randomConstantNode(nfeatures)
        newnode = Node(
            rand(1:options.nbin),
            left,
            right
        )
    else
        newnode = Node(
            rand(1:options.nuna),
            left
        )
    end
    node.l = newnode.l
    node.r = newnode.r
    node.op = newnode.op
    node.degree = newnode.degree
    node.val = newnode.val
    node.constant = newnode.constant
    return tree
end

# Add random node to the top of a tree
function prependRandomOp(tree::Node, options::Options, nfeatures::Int)::Node
    node = tree
    choice = rand()
    makeNewBinOp = choice < options.nbin/(options.nuna + options.nbin)
    left = copyNode(tree)

    if makeNewBinOp
        right = randomConstantNode(nfeatures)
        newnode = Node(
            rand(1:options.nbin),
            left,
            right
        )
    else
        newnode = Node(
            rand(1:options.nuna),
            left
        )
    end
    node.l = newnode.l
    node.r = newnode.r
    node.op = newnode.op
    node.degree = newnode.degree
    node.val = newnode.val
    node.constant = newnode.constant
    return node
end

function randomConstantNode(nfeatures::Int)::Node
    if rand() > 0.5
        val = Float32(randn())
    else
        val = rand(1:nfeatures)
    end
    newnode = Node(val)
    return newnode
end

# Return a random node from the tree with parent
function randomNodeAndParent(tree::Node, parent::Union{Node, Nothing})::Tuple{Node, Union{Node, Nothing}}
    if tree.degree == 0
        return tree, parent
    end
    a = countNodes(tree)
    b = 0
    c = 0
    if tree.degree >= 1
        b = countNodes(tree.l)
    end
    if tree.degree == 2
        c = countNodes(tree.r)
    end

    i = rand(1:1+b+c)
    if i <= b
        return randomNodeAndParent(tree.l, tree)
    elseif i == b + 1
        return tree, parent
    end

    return randomNodeAndParent(tree.r, tree)
end

# Select a random node, and replace it an the subtree
# with a variable or constant
function deleteRandomOp(tree::Node, options::Options, nfeatures::Int)::Node
    node, parent = randomNodeAndParent(tree, nothing)
    isroot = (parent === nothing)

    if node.degree == 0
        # Replace with new constant
        newnode = randomConstantNode(nfeatures)
        node.l = newnode.l
        node.r = newnode.r
        node.op = newnode.op
        node.degree = newnode.degree
        node.val = newnode.val
        node.constant = newnode.constant
    elseif node.degree == 1
        # Join one of the children with the parent
        if isroot
            return node.l
        elseif parent.l == node
            parent.l = node.l
        else
            parent.r = node.l
        end
    else
        # Join one of the children with the parent
        if rand() < 0.5
            if isroot
                return node.l
            elseif parent.l == node
                parent.l = node.l
            else
                parent.r = node.l
            end
        else
            if isroot
                return node.r
            elseif parent.l == node
                parent.l = node.r
            else
                parent.r = node.r
            end
        end
    end
    return tree
end

# Simplify tree
function combineOperators(tree::Node, options::Options)::Node
    # NOTE: (const (+*-) const) already accounted for. Call simplifyTree before.
    # ((const + var) + const) => (const + var)
    # ((const * var) * const) => (const * var)
    # ((const - var) - const) => (const - var)
    # (want to add anything commutative!)
    # TODO - need to combine plus/sub if they are both there.
    if tree.degree == 0
        return tree
    elseif tree.degree == 1
        tree.l = combineOperators(tree.l, options)
    elseif tree.degree == 2
        tree.l = combineOperators(tree.l, options)
        tree.r = combineOperators(tree.r, options)
    end

    top_level_constant = tree.degree == 2 && (tree.l.constant || tree.r.constant)
    if tree.degree == 2 && (options.binops[tree.op] === mult || options.binops[tree.op] === plus) && top_level_constant
        op = tree.op
        # Put the constant in r. Need to assume var in left for simplification assumption.
        if tree.l.constant
            tmp = tree.r
            tree.r = tree.l
            tree.l = tmp
        end
        topconstant = tree.r.val
        # Simplify down first
        below = tree.l
        if below.degree == 2 && below.op == op
            if below.l.constant
                tree = below
                tree.l.val = options.binops[op](tree.l.val, topconstant)
            elseif below.r.constant
                tree = below
                tree.r.val = options.binops[op](tree.r.val, topconstant)
            end
        end
    end

    if tree.degree == 2 && options.binops[tree.op] === sub && top_level_constant
        # Currently just simplifies subtraction. (can't assume both plus and sub are operators)
        # Not commutative, so use different op.
        if tree.l.constant
            if tree.r.degree == 2 && options.binops[tree.r.op] === sub
                if tree.r.l.constant
                    #(const - (const - var)) => (var - const)
                    l = tree.l
                    r = tree.r
                    simplified_const = -(l.val - r.l.val) #neg(sub(l.val, r.l.val))
                    tree.l = tree.r.r
                    tree.r = l
                    tree.r.val = simplified_const
                elseif tree.r.r.constant
                    #(const - (var - const)) => (const - var)
                    l = tree.l
                    r = tree.r
                    simplified_const = l.val + r.r.val #plus(l.val, r.r.val)
                    tree.r = tree.r.l
                    tree.l.val = simplified_const
                end
            end
        else #tree.r.constant is true
            if tree.l.degree == 2 && options.binops[tree.l.op] === sub
                if tree.l.l.constant
                    #((const - var) - const) => (const - var)
                    l = tree.l
                    r = tree.r
                    simplified_const = l.l.val - r.val#sub(l.l.val, r.val)
                    tree.r = tree.l.r
                    tree.l = r
                    tree.l.val = simplified_const
                elseif tree.l.r.constant
                    #((var - const) - const) => (var - const)
                    l = tree.l
                    r = tree.r
                    simplified_const = r.val + l.r.val #plus(r.val, l.r.val)
                    tree.l = tree.l.l
                    tree.r.val = simplified_const
                end
            end
        end
    end
    return tree
end

# Simplify tree
function simplifyTree(tree::Node, options::Options)::Node
    if tree.degree == 1
        tree.l = simplifyTree(tree.l, options)
        if tree.l.degree == 0 && tree.l.constant
            return Node(options.unaops[tree.op](tree.l.val))
        end
    elseif tree.degree == 2
        tree.l = simplifyTree(tree.l, options)
        tree.r = simplifyTree(tree.r, options)
        constantsBelow = (
             tree.l.degree == 0 && tree.l.constant &&
             tree.r.degree == 0 && tree.r.constant
        )
        if constantsBelow
            return Node(options.binops[tree.op](tree.l.val, tree.r.val))
        end
    end
    return tree
end

# Define a member of population by equation, score, and age
mutable struct PopMember
    tree::Node
    score::Float32
    birth::Integer

    PopMember(t::Node, score::Float32) = new(t, score, getTime())

end


function PopMember(X::Array{Float32, 2}, y::Array{Float32, 1}, baseline::Float32, t::Node, options::Options)
    PopMember(t, scoreFunc(X, y, baseline, t, options))
end

# Check if any binary operator are overly complex
function flagBinOperatorComplexity(tree::Node, op::Int, options::Options)::Bool
    if tree.degree == 0
        return false
    elseif tree.degree == 1
        return flagBinOperatorComplexity(tree.l, op, options)
    else
        if tree.op == op
            overly_complex = (
                    ((options.bin_constraints[op][1] > -1) &&
                     (countNodes(tree.l) > options.bin_constraints[op][1]))
                      ||
                    ((options.bin_constraints[op][2] > -1) &&
                     (countNodes(tree.r) > options.bin_constraints[op][2]))
                )
            if overly_complex
                return true
            end
        end
        return (flagBinOperatorComplexity(tree.l, op, options) || flagBinOperatorComplexity(tree.r, op, options))
    end
end

# Check if any unary operators are overly complex
function flagUnaOperatorComplexity(tree::Node, op::Int, options::Options)::Bool
    if tree.degree == 0
        return false
    elseif tree.degree == 1
        if tree.op == op
            overly_complex = (
                      (options.una_constraints[op] > -1) &&
                      (countNodes(tree.l) > options.una_constraints[op])
                )
            if overly_complex
                return true
            end
        end
        return flagUnaOperatorComplexity(tree.l, op, options)
    else
        return (flagUnaOperatorComplexity(tree.l, op, options) || flagUnaOperatorComplexity(tree.r, op, options))
    end
end

# Go through one simulated options.annealing mutation cycle
#  exp(-delta/T) defines probability of accepting a change
function iterate(X::Array{Float32, 2}, y::Array{Float32, 1}, baseline::Float32, member::PopMember, T::Float32, curmaxsize::Integer, frequencyComplexity::Array{Float32, 1}, options::Options)::PopMember
    prev = member.tree
    tree = prev
    #TODO - reconsider this
    if options.batching
        beforeLoss = scoreFuncBatch(X, y, baseline, prev, options)
    else
        beforeLoss = member.score
    end

    nfeatures = size(X)[2]

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
            tree = mutateConstant(tree, T, options)

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

        # Check for illegal equations
        for i=1:options.nbin
            if successful_mutation && flagBinOperatorComplexity(tree, i, options)
                successful_mutation = false
            end
        end
        for i=1:options.nuna
            if successful_mutation && flagUnaOperatorComplexity(tree, i, options)
                successful_mutation = false
            end
        end

        attempts += 1
    end
    #############################################

    if !successful_mutation
        return PopMember(copyNode(prev), beforeLoss)
    end

    if options.batching
        afterLoss = scoreFuncBatch(X, y, baseline, tree, options)
    else
        afterLoss = scoreFunc(X, y, baseline, tree, options)
    end

    if options.annealing
        delta = afterLoss - beforeLoss
        probChange = exp(-delta/(T*options.alpha))
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

# Create a random equation by appending random operators
function genRandomTree(length::Integer, options::Options, nfeatures::Int)::Node
    tree = Node(1.0f0)
    for i=1:length
        tree = appendRandomOp(tree, options, nfeatures)
    end
    return tree
end


# A list of members of the population, with easy constructors,
#  which allow for random generation of new populations
mutable struct Population
    members::Array{PopMember, 1}
    n::Integer

    Population(pop::Array{PopMember, 1}) = new(pop, size(pop)[1])
    Population(pop::Array{PopMember, 1}, npop::Integer) = new(pop, npop)

end

function Population(X::Array{Float32, 2}, y::Array{Float32, 1}, baseline::Float32, npop::Integer, options::Options, nfeatures::Int)
    Population([PopMember(X, y, baseline, genRandomTree(3, options, nfeatures), options) for i=1:npop], npop)
end

function Population(X::Array{Float32, 2}, y::Array{Float32, 1}, baseline::Float32, npop::Integer, nlength::Integer, options::Options, nfeatures::Int)
    Population([PopMember(X, y, baseline, genRandomTree(nlength, options, nfeatures), options) for i=1:npop], npop)
end

# Sample 10 random members of the population, and make a new one
function samplePop(pop::Population, options::Options)::Population
    idx = rand(1:pop.n, options.ns)
    return Population(pop.members[idx])
end

# Sample the population, and get the best member from that sample
function bestOfSample(pop::Population, options::Options)::PopMember
    sample = samplePop(pop, options)
    best_idx = argmin([sample.members[member].score for member=1:sample.n])
    return sample.members[best_idx]
end

function finalizeScores(X::Array{Float32, 2}, y::Array{Float32, 1}, baseline::Float32, pop::Population, options::Options)::Population
    need_recalculate = options.batching
    if need_recalculate
        @inbounds @simd for member=1:pop.n
            pop.members[member].score = scoreFunc(X, y, baseline, pop.members[member].tree, options)
        end
    end
    return pop
end

# Return best 10 examples
function bestSubPop(pop::Population; topn::Integer=10)::Population
    best_idx = sortperm([pop.members[member].score for member=1:pop.n])
    return Population(pop.members[best_idx[1:topn]])
end

# Pass through the population several times, replacing the oldest
# with the fittest of a small subsample
function regEvolCycle(X::Array{Float32, 2}, y::Array{Float32, 1}, baseline::Float32, pop::Population, T::Float32, curmaxsize::Integer,
                      frequencyComplexity::Array{Float32, 1}, options::Options)::Population
    # Batch over each subsample. Can give 15% improvement in speed; probably moreso for large pops.
    # but is ultimately a different algorithm than regularized evolution, and might not be
    # as good.
    if options.fast_cycle
        shuffle!(pop.members)
        n_evol_cycles = round(Integer, pop.n/options.ns)
        babies = Array{PopMember}(undef, n_evol_cycles)

        # Iterate each ns-member sub-sample
        @inbounds Threads.@threads for i=1:n_evol_cycles
            best_score = Inf32
            best_idx = 1+(i-1)*options.ns
            # Calculate best member of the subsample:
            for sub_i=1+(i-1)*options.ns:i*options.ns
                if pop.members[sub_i].score < best_score
                    best_score = pop.members[sub_i].score
                    best_idx = sub_i
                end
            end
            allstar = pop.members[best_idx]
            babies[i] = iterate(X, y, baseline, allstar, T, curmaxsize, frequencyComplexity, options)
        end

        # Replace the n_evol_cycles-oldest members of each population
        @inbounds for i=1:n_evol_cycles
            oldest = argmin([pop.members[member].birth for member=1:pop.n])
            pop.members[oldest] = babies[i]
        end
    else
        for i=1:round(Integer, pop.n/options.ns)
            allstar = bestOfSample(pop, options)
            baby = iterate(X, y, baseline, allstar, T, curmaxsize, frequencyComplexity, options)
            #printTree(baby.tree)
            oldest = argmin([pop.members[member].birth for member=1:pop.n])
            pop.members[oldest] = baby
        end
    end

    return pop
end

# Cycle through regularized evolution many times,
# printing the fittest equation every 10% through
function SRCycle(X::Array{Float32, 2}, y::Array{Float32, 1}, baseline::Float32, 
        pop::Population,
        ncycles::Integer,
        curmaxsize::Integer,
        frequencyComplexity::Array{Float32, 1};
        verbosity::Integer=0,
        options::Options
       )::Population

    allT = LinRange(1.0f0, 0.0f0, ncycles)
    for iT in 1:size(allT)[1]
        if options.annealing
            pop = regEvolCycle(X, y, baseline, pop, allT[iT], curmaxsize, frequencyComplexity, options)
        else
            pop = regEvolCycle(X, y, baseline, pop, 1.0f0, curmaxsize, frequencyComplexity, options)
        end

        if verbosity > 0 && (iT % verbosity == 0)
            bestPops = bestSubPop(pop)
            bestCurScoreIdx = argmin([bestPops.members[member].score for member=1:bestPops.n])
            bestCurScore = bestPops.members[bestCurScoreIdx].score
            debug(verbosity, bestCurScore, " is the score for ", stringTree(bestPops.members[bestCurScoreIdx].tree, options))
        end
    end

    return pop
end

# Get all the constants from a tree
function getConstants(tree::Node)::Array{Float32, 1}
    if tree.degree == 0
        if tree.constant
            return [tree.val]
        else
            return Float32[]
        end
    elseif tree.degree == 1
        return getConstants(tree.l)
    else
        both = [getConstants(tree.l), getConstants(tree.r)]
        return [constant for subtree in both for constant in subtree]
    end
end

# Set all the constants inside a tree
function setConstants(tree::Node, constants::Array{Float32, 1})
    if tree.degree == 0
        if tree.constant
            tree.val = constants[1]
        end
    elseif tree.degree == 1
        setConstants(tree.l, constants)
    else
        numberLeft = countConstants(tree.l)
        setConstants(tree.l, constants)
        setConstants(tree.r, constants[numberLeft+1:end])
    end
end


# Proxy function for optimization
function optFunc(x::Array{Float32, 1}, X::Array{Float32, 2}, y::Array{Float32, 1}, baseline::Float32, tree::Node, options::Options)::Float32
    setConstants(tree, x)
    return scoreFunc(X, y, baseline, tree, options)
end

# Use Nelder-Mead to optimize the constants in an equation
function optimizeConstants(X::Array{Float32, 2}, y::Array{Float32, 1}, baseline::Float32, member::PopMember, options::Options)::PopMember
    nconst = countConstants(member.tree)
    if nconst == 0
        return member
    end
    x0 = getConstants(member.tree)
    f(x::Array{Float32,1})::Float32 = optFunc(x, X, y, baseline, member.tree, options)
    if size(x0)[1] == 1
        algorithm = Newton
    else
        algorithm = NelderMead
    end

    try
        result = optimize(f, x0, algorithm(), Optim.Options(iterations=100))
        # Try other initial conditions:
        for i=1:options.nrestarts
            tmpresult = optimize(f, x0 .* (1f0 .+ 5f-1*randn(Float32, size(x0)[1])), algorithm(), Optim.Options(iterations=100))
            if tmpresult.minimum < result.minimum
                result = tmpresult
            end
        end

        if Optim.converged(result)
            setConstants(member.tree, result.minimizer)
            member.score = convert(Float32, result.minimum)
            member.birth = getTime()
        else
            setConstants(member.tree, x0)
        end
    catch error
        # Fine if optimization encountered domain error, just return x0
        if isa(error, AssertionError)
            setConstants(member.tree, x0)
        else
            throw(error)
        end
    end
    return member
end


# List of the best members seen all time
mutable struct HallOfFame
    members::Array{PopMember, 1}
    exists::Array{Bool, 1} #Whether it has been set

    # Arranged by complexity - store one at each.
end

function HallOfFame(options::Options)
    actualMaxsize = options.maxsize + maxdegree
    HallOfFame([PopMember(Node(1f0), 1f9) for i=1:actualMaxsize], [false for i=1:actualMaxsize])
end

# Check for errors before they happen
function testConfiguration(options::Options)
    test_input = LinRange(-100f0, 100f0, 99)

    try
        for left in test_input
            for right in test_input
                for binop in options.binops
                    test_output = binop.(left, right)
                end
            end
            for unaop in options.unaops
                test_output = unaop.(left)
            end
        end
    catch error
        @printf("\n\nYour configuration is invalid - one of your operators is not well-defined over the real line.\n\n\n")
        throw(error)
    end
end

function RunSR(X::Array{Float32, 2}, y::Array{Float32, 1},
               niterations::Integer, options::Options)

    testConfiguration(options)

    if options.weighted
        avgy = sum(y .* weights)/sum(weights)
        baselineMSE = MSE(y, convert(Array{Float32, 1}, ones(size(X)[1]) .* avgy), weights)
    else
        avgy = sum(y)/size(X)[1]
        baselineMSE = MSE(y, convert(Array{Float32, 1}, ones(size(X)[1]) .* avgy))
    end

    nfeatures = size(X)[2]

    # 1. Start a population on every process
    allPops = Future[]
    # Set up a channel to send finished populations back to head node
    channels = [RemoteChannel(1) for j=1:options.npopulations]
    bestSubPops = [Population(X, y, baselineMSE, 1, options, nfeatures) for j=1:options.npopulations]
    hallOfFame = HallOfFame(options)
    actualMaxsize = options.maxsize + maxdegree
    frequencyComplexity = ones(Float32, actualMaxsize)
    curmaxsize = 3
    if options.warmupMaxsize == 0
        curmaxsize = options.maxsize
    end

    for i=1:options.npopulations
        future = @spawnat :any Population(X, y, baselineMSE, options.npop, 3, options, nfeatures)
        push!(allPops, future)
    end

    # # 2. Start the cycle on every process:
    @sync for i=1:options.npopulations
        @async allPops[i] = @spawnat :any SRCycle(X, y, baselineMSE, fetch(allPops[i]), options.ncyclesperiteration, curmaxsize, copy(frequencyComplexity)/sum(frequencyComplexity), verbosity=options.verbosity, options=options)
    end
    println("Started!")
    cycles_complete = options.npopulations * niterations
    if options.warmupMaxsize != 0
        curmaxsize += 1
        if curmaxsize > options.maxsize
            curmaxsize = options.maxsize
        end
    end

    last_print_time = time()
    num_equations = 0.0
    print_every_n_seconds = 5
    equation_speed = Float32[]

    for i=1:options.npopulations
        # Start listening for each population to finish:
        @async put!(channels[i], fetch(allPops[i]))
    end

    while cycles_complete > 0
        @inbounds for i=1:options.npopulations
            # Non-blocking check if a population is ready:
            if isready(channels[i])
                # Take the fetch operation from the channel since its ready
                cur_pop = take!(channels[i])
                bestSubPops[i] = bestSubPop(cur_pop, topn=options.topn)

                #Try normal copy...
                bestPops = Population([member for pop in bestSubPops for member in pop.members])

                for member in cur_pop.members
                    size = countNodes(member.tree)
                    frequencyComplexity[size] += 1
                    if member.score < hallOfFame.members[size].score
                        hallOfFame.members[size] = deepcopy(member)
                        hallOfFame.exists[size] = true
                    end
                end

                # Dominating pareto curve - must be better than all simpler equations
                dominating = PopMember[]
                open(options.hofFile, "w") do io
                    println(io,"Complexity|MSE|Equation")
                    actualMaxsize = options.maxsize + maxdegree
                    for size=1:actualMaxsize
                        if hallOfFame.exists[size]
                            member = hallOfFame.members[size]
                            if options.weighted
                                curMSE = MSE(evalTreeArray(member.tree, X, options), y, weights)
                                member.score = curMSE
                            else
                                curMSE = MSE(evalTreeArray(member.tree, X, options), y)
                                member.score = curMSE
                            end
                            numberSmallerAndBetter = 0
                            for i=1:(size-1)
                                if options.weighted
                                    hofMSE = MSE(evalTreeArray(hallOfFame.members[i].tree, X, options), y, weights)
                                else
                                    hofMSE = MSE(evalTreeArray(hallOfFame.members[i].tree, X, options), y)
                                end
                                if (hallOfFame.exists[size] && curMSE > hofMSE)
                                    numberSmallerAndBetter += 1
                                end
                            end
                            betterThanAllSmaller = (numberSmallerAndBetter == 0)
                            if betterThanAllSmaller
                                println(io, "$size|$(curMSE)|$(stringTree(member.tree, options))")
                                push!(dominating, member)
                            end
                        end
                    end
                end
                cp(options.hofFile, options.hofFile*".bkup", force=true)

                # Try normal copy otherwise.
                if options.migration
                    for k in rand(1:options.npop, round(Integer, options.npop*options.fractionReplaced))
                        to_copy = rand(1:size(bestPops.members)[1])
                        cur_pop.members[k] = PopMember(
                            copyNode(bestPops.members[to_copy].tree),
                            bestPops.members[to_copy].score)
                    end
                end

                if options.hofMigration && size(dominating)[1] > 0
                    for k in rand(1:options.npop, round(Integer, options.npop*options.fractionReplacedHof))
                        # Copy in case one gets used twice
                        to_copy = rand(1:size(dominating)[1])
                        cur_pop.members[k] = PopMember(
                           copyNode(dominating[to_copy].tree), dominating[to_copy].score
                        )
                    end
                end

                # TODO: Turn off this async when debugging - any errors in this code
                #         are silent.
                # begin
                @async begin
                    allPops[i] = @spawnat :any let
                        tmp_pop = SRCycle(X, y, baselineMSE, cur_pop, options.ncyclesperiteration, curmaxsize, copy(frequencyComplexity)/sum(frequencyComplexity), verbosity=options.verbosity, options=options)
                        @inbounds @simd for j=1:tmp_pop.n
                            if rand() < 0.1
                                tmp_pop.members[j].tree = simplifyTree(tmp_pop.members[j].tree, options)
                                tmp_pop.members[j].tree = combineOperators(tmp_pop.members[j].tree, options)
                                if options.shouldOptimizeConstants
                                    tmp_pop.members[j] = optimizeConstants(X, y, baselineMSE, tmp_pop.members[j], options)
                                end
                            end
                        end
                        tmp_pop = finalizeScores(X, y, baselineMSE, tmp_pop, options)
                        tmp_pop
                    end
                    put!(channels[i], fetch(allPops[i]))
                end

                cycles_complete -= 1
                cycles_elapsed = options.npopulations * niterations - cycles_complete
                if options.warmupMaxsize != 0 && cycles_elapsed % options.warmupMaxsize == 0
                    curmaxsize += 1
                    if curmaxsize > options.maxsize
                        curmaxsize = options.maxsize
                    end
                end
                num_equations += options.ncyclesperiteration * options.npop / 10.0
            end
        end
        sleep(1e-3)
        elapsed = time() - last_print_time
        #Update if time has passed, and some new equations generated.
        if elapsed > print_every_n_seconds && num_equations > 0.0
            # Dominating pareto curve - must be better than all simpler equations
            current_speed = num_equations/elapsed
            average_over_m_measurements = 10 #for print_every...=5, this gives 50 second running average
            push!(equation_speed, current_speed)
            if length(equation_speed) > average_over_m_measurements
                deleteat!(equation_speed, 1)
            end
            average_speed = sum(equation_speed)/length(equation_speed)
            curMSE = baselineMSE
            lastMSE = curMSE
            lastComplexity = 0
            if options.verbosity > 0
                @printf("\n")
                @printf("Cycles per second: %.3e\n", round(average_speed, sigdigits=3))
                cycles_elapsed = options.npopulations * niterations - cycles_complete
                @printf("Progress: %d / %d total iterations (%.3f%%)\n", cycles_elapsed, options.npopulations * niterations, 100.0*cycles_elapsed/(options.npopulations*niterations))
                @printf("Hall of Fame:\n")
                @printf("-----------------------------------------\n")
                @printf("%-10s  %-8s   %-8s  %-8s\n", "Complexity", "MSE", "Score", "Equation")
                @printf("%-10d  %-8.3e  %-8.3e  %-.f\n", 0, curMSE, 0f0, avgy)
            end

            actualMaxsize = options.maxsize + maxdegree
            for size=1:actualMaxsize
                if hallOfFame.exists[size]
                    member = hallOfFame.members[size]
                    if options.weighted
                        curMSE = MSE(evalTreeArray(member.tree, X, options), y, weights)
                    else
                        curMSE = MSE(evalTreeArray(member.tree, X, options), y)
                    end
                    numberSmallerAndBetter = 0
                    for i=1:(size-1)
                        if options.weighted
                            hofMSE = MSE(evalTreeArray(hallOfFame.members[i].tree, X, options), y, weights)
                        else
                            hofMSE = MSE(evalTreeArray(hallOfFame.members[i].tree, X, options), y)
                        end
                        if (hallOfFame.exists[size] && curMSE > hofMSE)
                            numberSmallerAndBetter += 1
                        end
                    end
                    betterThanAllSmaller = (numberSmallerAndBetter == 0)
                    if betterThanAllSmaller
                        delta_c = size - lastComplexity
                        delta_l_mse = log(curMSE/lastMSE)
                        score = convert(Float32, -delta_l_mse/delta_c)
                        if options.verbosity > 0
                            @printf("%-10d  %-8.3e  %-8.3e  %-s\n" , size, curMSE, score, stringTree(member.tree, options))
                        end
                        lastMSE = curMSE
                        lastComplexity = size
                    end
                end
            end
            debug(options.verbosity, "")
            last_print_time = time()
            num_equations = 0.0
        end
    end
end

end #module SR
