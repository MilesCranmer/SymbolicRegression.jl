using FromFile
@from "Core.jl" import CONST_TYPE, Node, copyNode, Options

# Count the operators, constants, variables in an equation
function countNodes(tree::Node)::Int
    if tree.degree == 0
        return 1
    elseif tree.degree == 1
        return 1 + countNodes(tree.l)
    else
        return 1 + countNodes(tree.l) + countNodes(tree.r)
    end
end

# Count the max depth of a tree
function countDepth(tree::Node)::Int
    if tree.degree == 0
        return 1
    elseif tree.degree == 1
        return 1 + countDepth(tree.l)
    else
        return 1 + max(countDepth(tree.l), countDepth(tree.r))
    end
end


# Count the number of unary operators in the equation
function countUnaryOperators(tree::Node)::Int
    if tree.degree == 0
        return 0
    elseif tree.degree == 1
        return 1 + countUnaryOperators(tree.l)
    else
        return 0 + countUnaryOperators(tree.l) + countUnaryOperators(tree.r)
    end
end

# Count the number of binary operators in the equation
function countBinaryOperators(tree::Node)::Int
    if tree.degree == 0
        return 0
    elseif tree.degree == 1
        return 0 + countBinaryOperators(tree.l)
    else
        return 1 + countBinaryOperators(tree.l) + countBinaryOperators(tree.r)
    end
end

# Count the number of operators in the equation
function countOperators(tree::Node)::Int
    return countUnaryOperators(tree) + countBinaryOperators(tree)
end


# Count the number of constants in an equation
function countConstants(tree::Node)::Int
    if tree.degree == 0
        if tree.constant
            return 1
        else
            return 0
        end
    elseif tree.degree == 1
        return 0 + countConstants(tree.l)
    else
        return 0 + countConstants(tree.l) + countConstants(tree.r)
    end
end


# Get all the constants from a tree
function getConstants(tree::Node)::AbstractVector{CONST_TYPE}
    if tree.degree == 0
        if tree.constant
            return [tree.val]
        else
            return CONST_TYPE[]
        end
    elseif tree.degree == 1
        return getConstants(tree.l)
    else
        both = [getConstants(tree.l), getConstants(tree.r)]
        return [constant for subtree in both for constant in subtree]
    end
end

# Set all the constants inside a tree
function setConstants(tree::Node, constants::AbstractVector{T}) where {T<:Real}
    if tree.degree == 0
        if tree.constant
            tree.val = convert(CONST_TYPE, constants[1])
        end
    elseif tree.degree == 1
        setConstants(tree.l, constants)
    else
        numberLeft = countConstants(tree.l)
        setConstants(tree.l, constants)
        setConstants(tree.r, constants[numberLeft+1:end])
    end
end


## Assign index to nodes of a tree
# This will mirror a Node struct, rather
# than adding a new attribute to Node.
mutable struct NodeIndex
    constant_index::Int  # Index of this constant (if a constant exists here)
    l::NodeIndex
    r::NodeIndex

    NodeIndex() = new()
end

function indexConstants(tree::Node, left_index::Int)::NodeIndex
    index_tree = NodeIndex()
    indexConstants(tree, index_tree, left_index)
    return index_tree
end

# Count how many constants to the left of this node, and put them in a tree
function indexConstants(tree::Node, index_tree::NodeIndex, left_index::Int)
    if tree.degree == 0
        if tree.constant
            index_tree.constant_index = left_index + 1
        end
    elseif tree.degree == 1
        index_tree.constant_index = countConstants(tree.l)
        index_tree.l = NodeIndex()
        indexConstants(tree.l, index_tree.l, left_index)
    else
        index_tree.l = NodeIndex()
        index_tree.r = NodeIndex()
        indexConstants(tree.l, index_tree.l, left_index)
        index_tree.constant_index = countConstants(tree.l)
        left_index_here = left_index + index_tree.constant_index
        indexConstants(tree.r, index_tree.r, left_index_here)
    end
end
