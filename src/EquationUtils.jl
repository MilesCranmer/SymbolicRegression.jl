module EquationUtilsModule

import ..CoreModule: Node, left, right, copy_node, Options

# Count the operators, constants, variables in an equation
function count_nodes(tree::Node)::Int
    if tree.degree == 0
        return 1
    elseif tree.degree == 1
        return 1 + count_nodes(left(tree))
    else
        return 1 + count_nodes(left(tree)) + count_nodes(right(tree))
    end
end

# Count the max depth of a tree
function count_depth(tree::Node)::Int
    if tree.degree == 0
        return 1
    elseif tree.degree == 1
        return 1 + count_depth(left(tree))
    else
        return 1 + max(count_depth(left(tree)), count_depth(right(tree)))
    end
end

# Count the number of unary operators in the equation
function count_unary_operators(tree::Node)::Int
    if tree.degree == 0
        return 0
    elseif tree.degree == 1
        return 1 + count_unary_operators(left(tree))
    else
        return 0 + count_unary_operators(left(tree)) + count_unary_operators(right(tree))
    end
end

# Count the number of binary operators in the equation
function count_binary_operators(tree::Node)::Int
    if tree.degree == 0
        return 0
    elseif tree.degree == 1
        return 0 + count_binary_operators(left(tree))
    else
        return 1 + count_binary_operators(left(tree)) + count_binary_operators(right(tree))
    end
end

# Count the number of operators in the equation
function count_operators(tree::Node)::Int
    return count_unary_operators(tree) + count_binary_operators(tree)
end

# Count the number of constants in an equation
function count_constants(tree::Node)::Int
    if tree.degree == 0
        if tree.constant
            return 1
        else
            return 0
        end
    elseif tree.degree == 1
        return 0 + count_constants(left(tree))
    else
        return 0 + count_constants(left(tree)) + count_constants(right(tree))
    end
end

"""
    is_constant(tree::Node)::Bool

Check if an expression is a constant numerical value, or
whether it depends on input features.
"""
function is_constant(tree::Node)::Bool
    if tree.degree == 0
        return tree.constant
    elseif tree.degree == 1
        return is_constant(left(tree))
    else
        return is_constant(left(tree)) && is_constant(right(tree))
    end
end

"""
Compute the complexity of a tree.

By default, this is the number of nodes in a tree.
However, it could use the custom settings in options.complexity_mapping
if these are defined.
"""
function compute_complexity(tree::Node, options::Options)::Int
    if options.complexity_mapping.use
        return round(Int, _compute_complexity(tree, options))
    else
        return count_nodes(tree)
    end
end

function _compute_complexity(
    tree::Node, options::Options{A,B,dA,dB,C,complexity_type}
)::complexity_type where {A,B,dA,dB,C,complexity_type<:Real}
    if tree.degree == 0
        if tree.constant
            return options.complexity_mapping.constant_complexity
        else
            return options.complexity_mapping.variable_complexity
        end
    elseif tree.degree == 1
        return (
            options.complexity_mapping.unaop_complexities[tree.op] +
            _compute_complexity(left(tree), options)
        )
    else # tree.degree == 2
        return (
            options.complexity_mapping.binop_complexities[tree.op] +
            _compute_complexity(left(tree), options) +
            _compute_complexity(right(tree), options)
        )
    end
end

# Get all the constants from a tree
function get_constants(tree::Node{T})::AbstractVector{T} where {T<:Real}
    if tree.degree == 0
        if tree.constant
            return [tree.val]
        else
            return T[]
        end
    elseif tree.degree == 1
        return get_constants(left(tree))
    else
        both = [get_constants(left(tree)), get_constants(right(tree))]
        return [constant for subtree in both for constant in subtree]
    end
end

# Set all the constants inside a tree
function set_constants(tree::Node{T}, constants::AbstractVector{T}) where {T<:Real}
    if tree.degree == 0
        if tree.constant
            tree.val = constants[1]
        end
    elseif tree.degree == 1
        set_constants(left(tree), constants)
    else
        numberLeft = count_constants(left(tree))
        set_constants(left(tree), constants)
        set_constants(right(tree), constants[(numberLeft + 1):end])
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

@inline function left(index_tree::NodeIndex)::NodeIndex
    return index_tree.l
end

@inline function right(index_tree::NodeIndex)::NodeIndex
    return index_tree.r
end

@inline function set_left!(index_tree::NodeIndex, new_left::NodeIndex)::NodeIndex
    index_tree.l = new_left
end

@inline function set_right!(index_tree::NodeIndex, new_right::NodeIndex)::NodeIndex
    index_tree.r = new_right
end

function index_constants(tree::Node)::NodeIndex
    return index_constants(tree, 0)
end

function index_constants(tree::Node, left_index::Int)::NodeIndex
    index_tree = NodeIndex()
    index_constants(tree, index_tree, left_index)
    return index_tree
end

# Count how many constants to the left of this node, and put them in a tree
function index_constants(tree::Node, index_tree::NodeIndex, left_index::Int)
    if tree.degree == 0
        if tree.constant
            index_tree.constant_index = left_index + 1
        end
    elseif tree.degree == 1
        index_tree.constant_index = count_constants(left(tree))
        set_left!(index_tree, NodeIndex())
        index_constants(left(tree), left(index_tree), left_index)
    else
        set_left!(index_tree, NodeIndex())
        set_right!(index_tree, NodeIndex())
        index_constants(left(tree), left(index_tree), left_index)
        index_tree.constant_index = count_constants(left(tree))
        left_index_here = left_index + index_tree.constant_index
        index_constants(right(tree), right(index_tree), left_index_here)
    end
end

end
