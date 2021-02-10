using FromFile
@from "Core.jl" import CONST_TYPE, Node, copyNode, Options
@from "EquationUtils.jl" import countNodes, countConstants, countOperators, countDepth

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

# Randomly perturb a constant
function mutateConstant(
        tree::Node, temperature::T,
        options::Options)::Node where {T<:Real}
    # T is between 0 and 1.

    if countConstants(tree) == 0
        return tree
    end
    node = randomNode(tree)
    while node.degree != 0 || node.constant == false
        node = randomNode(tree)
    end

    bottom = convert(T, 1//10)
    maxChange = options.perturbationFactor * temperature + convert(T, 1) + bottom
    factor = maxChange^Float32(rand())
    makeConstBigger = rand() > 0.5

    if makeConstBigger
        node.val *= convert(CONST_TYPE, factor)
    else
        node.val /= convert(CONST_TYPE, factor)
    end

    if rand() > options.probNegate
        node.val *= -1
    end

    return tree
end

# Add a random unary/binary operation to the end of a tree
function appendRandomOp(tree::Node, options::Options, nfeatures::Int)::Node
    node = randomNode(tree)
    while node.degree != 0
        node = randomNode(tree)
    end


    choice = rand()
    makeNewBinOp = choice < options.nbin/(options.nuna + options.nbin)

    if makeNewBinOp
        newnode = Node(
            rand(1:options.nbin),
            makeRandomLeaf(nfeatures),
            makeRandomLeaf(nfeatures)
        )
    else
        newnode = Node(
            rand(1:options.nuna),
            makeRandomLeaf(nfeatures)
        )
    end

    if newnode.degree == 2
        node.r = newnode.r
    end
    node.l = newnode.l
    node.op = newnode.op
    node.degree = newnode.degree
    node.val = newnode.val
    node.feature = newnode.feature
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
        right = makeRandomLeaf(nfeatures)
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
    if newnode.degree == 2
        node.r = newnode.r
    end
    node.l = newnode.l
    node.op = newnode.op
    node.degree = newnode.degree
    node.val = newnode.val
    node.feature = newnode.feature
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
        right = makeRandomLeaf(nfeatures)
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
    if newnode.degree == 2
        node.r = newnode.r
    end
    node.l = newnode.l
    node.op = newnode.op
    node.degree = newnode.degree
    node.val = newnode.val
    node.feature = newnode.feature
    node.constant = newnode.constant
    return node
end

function makeRandomLeaf(nfeatures::Int)::Node
    if rand() > 0.5
        return Node(randn(CONST_TYPE))
    else
        return Node(rand(1:nfeatures))
    end
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
        newnode = makeRandomLeaf(nfeatures)
        node.degree = newnode.degree
        node.val = newnode.val
        node.constant = newnode.constant
        if !newnode.constant
            node.feature = newnode.feature
        end
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

# Create a random equation by appending random operators
function genRandomTree(length::Int, options::Options, nfeatures::Int)::Node
    tree = Node(convert(CONST_TYPE, 1))
    for i=1:length
        tree = appendRandomOp(tree, options, nfeatures)
    end
    return tree
end
