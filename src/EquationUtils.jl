module EquationUtilsModule

import ..CoreModule: Node, copy_node, Options

# Count the operators, constants, variables in an equation
function count_nodes(tree::Node)::Int
    if tree.degree == 0
        return 1
    elseif tree.degree == 1
        return 1 + count_nodes(tree.l)
    else
        return 1 + count_nodes(tree.l) + count_nodes(tree.r)
    end
end

# Count the max depth of a tree
function count_depth(tree::Node)::Int
    if tree.degree == 0
        return 1
    elseif tree.degree == 1
        return 1 + count_depth(tree.l)
    else
        return 1 + max(count_depth(tree.l), count_depth(tree.r))
    end
end

function has_operators(tree::Node)::Bool
    return tree.degree > 0
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
        return 0 + count_constants(tree.l)
    else
        return 0 + count_constants(tree.l) + count_constants(tree.r)
    end
end

function has_constants(tree::Node)::Bool
    if tree.degree == 0
        return tree.constant
    elseif tree.degree == 1
        return has_constants(tree.l)
    else
        return has_constants(tree.l) || has_constants(tree.r)
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
        return is_constant(tree.l)
    else
        return is_constant(tree.l) && is_constant(tree.r)
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
            _compute_complexity(tree.l, options)
        )
    else # tree.degree == 2
        return (
            options.complexity_mapping.binop_complexities[tree.op] +
            _compute_complexity(tree.l, options) +
            _compute_complexity(tree.r, options)
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
        return get_constants(tree.l)
    else
        both = [get_constants(tree.l), get_constants(tree.r)]
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
        set_constants(tree.l, constants)
    else
        numberLeft = count_constants(tree.l)
        set_constants(tree.l, constants)
        set_constants(tree.r, constants[(numberLeft + 1):end])
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
        index_tree.constant_index = count_constants(tree.l)
        index_tree.l = NodeIndex()
        index_constants(tree.l, index_tree.l, left_index)
    else
        index_tree.l = NodeIndex()
        index_tree.r = NodeIndex()
        index_constants(tree.l, index_tree.l, left_index)
        index_tree.constant_index = count_constants(tree.l)
        left_index_here = left_index + index_tree.constant_index
        index_constants(tree.r, index_tree.r, left_index_here)
    end
end

end
