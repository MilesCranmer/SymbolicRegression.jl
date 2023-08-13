module MutationFunctionsModule

import DynamicExpressions:
    Node, copy_node, set_node!, count_nodes, has_constants, has_operators
import Compat: Returns, @inline
import ..CoreModule: Options, DATA_TYPE

"""
    random_node(tree::Node{T}; filter::F=Returns(true))

Return a random node from the tree. You may optionally
filter the nodes matching some condition before sampling.
"""
function random_node(tree::Node{T}; filter::F=Returns(true))::Node{T} where {T,F<:Function}
    num_matching = count(filter, tree)
    chosen_node_idx = rand(1:num_matching)
    chosen_node = Ref{typeof(tree)}()
    cur_idx = Ref(0)
    any(tree) do t
        if @inline(filter(t))
            cur_idx[] += 1
            if cur_idx[] == chosen_node_idx
                chosen_node[] = t
                return true
            end
        end
        return false
    end
    return chosen_node[]
end

# Randomly convert an operator into another one (binary->binary;
# unary->unary)
function mutate_operator(tree::Node{T}, options::Options)::Node{T} where {T}
    if !(has_operators(tree))
        return tree
    end
    node = random_node(tree; filter=t -> t.degree != 0)
    if node.degree == 1
        node.op = rand(1:(options.nuna))
    else
        node.op = rand(1:(options.nbin))
    end
    return tree
end

# Randomly perturb a constant
function mutate_constant(
    tree::Node{T}, temperature, options::Options
)::Node{T} where {T<:DATA_TYPE}
    # T is between 0 and 1.

    if !(has_constants(tree))
        return tree
    end
    node = random_node(tree; filter=t -> (t.degree == 0 && t.constant))

    bottom = 1//10
    maxChange = options.perturbation_factor * temperature + 1 + bottom
    factor = T(maxChange^rand(T))
    makeConstBigger = rand() > 0.5

    if makeConstBigger
        node.val::T *= factor
    else
        node.val::T /= factor
    end

    if rand() > options.probability_negate_constant
        node.val::T *= -1
    end

    return tree
end

# Add a random unary/binary operation to the end of a tree
function append_random_op(
    tree::Node{T},
    options::Options,
    nfeatures::Int;
    makeNewBinOp::Union{Bool,Nothing}=nothing,
)::Node{T} where {T<:DATA_TYPE}
    node = random_node(tree; filter=t -> t.degree == 0)

    if makeNewBinOp === nothing
        choice = rand()
        makeNewBinOp = choice < options.nbin / (options.nuna + options.nbin)
    end

    if makeNewBinOp
        newnode = Node(
            rand(1:(options.nbin)),
            make_random_leaf(nfeatures, T),
            make_random_leaf(nfeatures, T),
        )
    else
        newnode = Node(rand(1:(options.nuna)), make_random_leaf(nfeatures, T))
    end

    set_node!(node, newnode)

    return tree
end

# Insert random node
function insert_random_op(
    tree::Node{T}, options::Options, nfeatures::Int
)::Node{T} where {T<:DATA_TYPE}
    node = random_node(tree)
    choice = rand()
    makeNewBinOp = choice < options.nbin / (options.nuna + options.nbin)
    left = copy_node(node)

    if makeNewBinOp
        right = make_random_leaf(nfeatures, T)
        newnode = Node(rand(1:(options.nbin)), left, right)
    else
        newnode = Node(rand(1:(options.nuna)), left)
    end
    set_node!(node, newnode)
    return tree
end

# Add random node to the top of a tree
function prepend_random_op(
    tree::Node{T}, options::Options, nfeatures::Int
)::Node{T} where {T<:DATA_TYPE}
    node = tree
    choice = rand()
    makeNewBinOp = choice < options.nbin / (options.nuna + options.nbin)
    left = copy_node(tree)

    if makeNewBinOp
        right = make_random_leaf(nfeatures, T)
        newnode = Node(rand(1:(options.nbin)), left, right)
    else
        newnode = Node(rand(1:(options.nuna)), left)
    end
    set_node!(node, newnode)
    return node
end

function make_random_leaf(nfeatures::Int, ::Type{T})::Node{T} where {T<:DATA_TYPE}
    if rand() > 0.5
        return Node(; val=randn(T))
    else
        return Node(T; feature=rand(1:nfeatures))
    end
end

# Return a random node from the tree with parent, and side ('n' for no parent)
function _random_node_and_parent(
    tree::Node{T}, parent::Node{T}, side::Char, total_nodes
) where {T}
    if tree.degree == 0
        return tree, parent, side
    elseif tree.degree == 1
        i = rand(1:total_nodes)
        if i == 1
            return tree, parent, side
        else
            return _random_node_and_parent(tree.l, tree, 'l', total_nodes - 1)
        end
    else
        num_left = count_nodes(tree.l)
        num_right = total_nodes - num_left - 1

        i = rand(1:total_nodes)
        if i == 1
            return tree, parent, side
        elseif i <= num_left + 1
            return _random_node_and_parent(tree.l, tree, 'l', num_left)
        else
            return _random_node_and_parent(tree.r, tree, 'r', num_right)
        end
    end
end

function random_node_and_parent(tree::Node{T}) where {T}
    return _random_node_and_parent(tree, tree, 'n', count_nodes(tree))
end

# Select a random node, and replace it an the subtree
# with a variable or constant
function delete_random_op(
    tree::Node{T}, options::Options, nfeatures::Int
)::Node{T} where {T<:DATA_TYPE}
    node, parent, side = random_node_and_parent(tree)
    isroot = side == 'n'

    if node.degree == 0
        # Replace with new constant
        newnode = make_random_leaf(nfeatures, T)
        set_node!(node, newnode)
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
function gen_random_tree(
    length::Int, options::Options, nfeatures::Int, ::Type{T}
)::Node{T} where {T<:DATA_TYPE}
    # Note that this base tree is just a placeholder; it will be replaced.
    tree = Node(; val=convert(T, 1))
    for i in 1:length
        # TODO: This can be larger number of nodes than length.
        tree = append_random_op(tree, options, nfeatures)
    end
    return tree
end

function gen_random_tree_fixed_size(
    node_count::Int, options::Options, nfeatures::Int, ::Type{T}
)::Node{T} where {T<:DATA_TYPE}
    tree = make_random_leaf(nfeatures, T)
    cur_size = count_nodes(tree)
    while cur_size < node_count
        if cur_size == node_count - 1  # only unary operator allowed.
            options.nuna == 0 && break # We will go over the requested amount, so we must break.
            tree = append_random_op(tree, options, nfeatures; makeNewBinOp=false)
        else
            tree = append_random_op(tree, options, nfeatures)
        end
        cur_size = count_nodes(tree)
    end
    return tree
end

"""Crossover between two expressions"""
function crossover_trees(tree1::Node{T}, tree2::Node{T})::Tuple{Node{T},Node{T}} where {T}
    tree1 = copy_node(tree1)
    tree2 = copy_node(tree2)

    node1, parent1, side1 = random_node_and_parent(tree1)
    node2, parent2, side2 = random_node_and_parent(tree2)

    node1 = copy_node(node1)

    if side1 == 'l'
        parent1.l = copy_node(node2)
        # tree1 now contains this.
    elseif side1 == 'r'
        parent1.r = copy_node(node2)
        # tree1 now contains this.
    else # 'n'
        # This means that there is no parent2.
        tree1 = copy_node(node2)
    end

    if side2 == 'l'
        parent2.l = node1
    elseif side2 == 'r'
        parent2.r = node1
    else # 'n'
        tree2 = node1
    end
    return tree1, tree2
end

end
