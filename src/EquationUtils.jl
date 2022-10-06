module EquationUtilsModule

import ..CoreModule: Node, copy_node, Options

# Count the operators, constants, variables in an equation
function count_nodes(tree::Node{T}; ignore_duplicates::Bool=false)::Int where {T}
    return _count_nodes(tree, ignore_duplicates ? IdDict{Node{T},Bool}() : nothing)
end

function _count_nodes(tree::Node{T}, nodes_seen::ID)::Int where {T,ID}
    !(ID <: Nothing) && haskey(nodes_seen, tree) && return 0
    count = if tree.degree == 0
        1
    elseif tree.degree == 1
        1 + _count_nodes(tree.l, nodes_seen)
    else
        1 + _count_nodes(tree.l, nodes_seen) + _count_nodes(tree.r, nodes_seen)
    end
    !(ID <: Nothing) && (nodes_seen[tree] = true)
    return count
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
function count_constants(tree::Node{T})::Int where {T}
    return _count_constants(tree, IdDict{Node{T},Bool}())
end

function _count_constants(tree::Node{T}, nodes_seen::ID)::Int where {T,ID}
    haskey(nodes_seen, tree) && return 0
    count = if tree.degree == 0
        if tree.constant
            1
        else
            0
        end
    elseif tree.degree == 1
        _count_constants(tree.l, nodes_seen)
    else
        _count_constants(tree.l, nodes_seen) + _count_constants(tree.r, nodes_seen)
    end
    nodes_seen[tree] = true
    return count
end

function has_binary_operators(tree::Node{T})::Bool where {T}
    if tree.degree == 0
        return false
    elseif tree.degree == 1
        return has_binary_operators(tree.l)
    else
        return true
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
function compute_complexity(
    tree::Node{T}, options::Options; ignore_duplicates=nothing
)::Int where {T}
    if ignore_duplicates === nothing
        ignore_duplicates = options.node_sharing
    end
    if options.complexity_mapping.use
        return round(
            Int,
            _compute_complexity(
                tree, options, ignore_duplicates ? IdDict{Node{T},Bool}() : nothing
            ),
        )
    else
        return count_nodes(tree)
    end
end

function _compute_complexity(
    tree::Node{T}, options::Options{A,B,dA,dB,C,complexity_type}, nodes_seen::ID
)::complexity_type where {A,B,dA,dB,C,complexity_type<:Real,T,ID}
    !(ID <: Nothing) && haskey(nodes_seen, tree) && return zero(complexity_type)
    count = if tree.degree == 0
        if tree.constant
            options.complexity_mapping.constant_complexity
        else
            options.complexity_mapping.variable_complexity
        end
    elseif tree.degree == 1
        options.complexity_mapping.unaop_complexities[tree.op] +
        _compute_complexity(tree.l, options, nodes_seen)
    else # tree.degree == 2
        options.complexity_mapping.binop_complexities[tree.op] +
        _compute_complexity(tree.l, options, nodes_seen) +
        _compute_complexity(tree.r, options, nodes_seen)
    end
    !(ID <: Nothing) && (nodes_seen[tree] = true)
    return count
end

# Get all the constants from a tree
function get_constants(
    tree::Node{T}, nodes_seen::IdDict{Node{T},Bool}=IdDict{Node{T},Bool}()
)::Vector{T} where {T}
    haskey(nodes_seen, tree) && return T[]
    out = if tree.degree == 0
        if tree.constant
            [tree.val]
        else
            T[]
        end
    elseif tree.degree == 1
        get_constants(tree.l, nodes_seen)
    else
        both = [get_constants(tree.l, nodes_seen), get_constants(tree.r, nodes_seen)]
        [constant for subtree in both for constant in subtree]
    end
    nodes_seen[tree] = true
    return out
end

# Set all the constants inside a tree
function set_constants(
    tree::Node{T},
    constants::AbstractVector{T},
    nodes_seen::IdDict{Node{T},Bool}=IdDict{Node{T},Bool}(),
) where {T}
    haskey(nodes_seen, tree) && return nothing
    if tree.degree == 0
        if tree.constant
            tree.val = constants[1]
        end
    elseif tree.degree == 1
        set_constants(tree.l, constants, nodes_seen)
    else
        numberLeft = count_constants(tree.l)
        set_constants(tree.l, constants, nodes_seen)
        set_constants(tree.r, constants[(numberLeft + 1):end], nodes_seen)
    end
    nodes_seen[tree] = true
    return nothing
end

## Assign index to nodes of a tree
# This will mirror a Node struct, rather
# than adding a new attribute to Node.
mutable struct NodeIndex
    constant_index::Int # Index of this constant (if a constant exists here)
    l::NodeIndex
    r::NodeIndex

    NodeIndex(i) = new(i)
    NodeIndex(i, l) = new(i, l)
    NodeIndex(i, l, r) = new(i, l, r)
end

function index_constants(tree::Node{T})::NodeIndex where {T}
    return index_constants(tree, 0, IdDict{Node{T},NodeIndex}())
end

# Count how many constants to the left of this node, and put them in a tree
function index_constants(
    tree::Node{T}, left_index::Int, id_map::IdDict{Node{T},NodeIndex}
)::NodeIndex where {T}
    get!(id_map, tree) do
        if tree.degree == 0
            if tree.constant
                NodeIndex(left_index + 1)
            else
                NodeIndex(-1)
            end
        elseif tree.degree == 1
            NodeIndex(-1, index_constants(tree.l, left_index, id_map))
        else
            NodeIndex(
                -1,
                index_constants(tree.l, left_index, id_map),
                index_constants(
                    tree.r, left_index + count_constants(tree.l), id_map
                ),
            )
        end
    end
end

end
