module MutationFunctionsModule

import ..CoreModule: Node, left, right, set_left!, set_right!, copy_node, Options
import ..EquationUtilsModule: count_nodes, count_constants, count_operators, count_depth

# Return a random node from the tree
function random_node(tree::Node{T})::Node{T} where {T}
    if tree.degree == 0
        return tree
    end
    b = 0
    c = 0
    if tree.degree >= 1
        b = count_nodes(left(tree))
    end
    if tree.degree == 2
        c = count_nodes(right(tree))
    end

    i = rand(1:(1 + b + c))
    if i <= b
        return random_node(left(tree))
    elseif i == b + 1
        return tree
    end

    return random_node(right(tree))
end

# Randomly convert an operator into another one (binary->binary;
# unary->unary)
function mutate_operator(tree::Node{T}, options::Options)::Node{T} where {T}
    if count_operators(tree) == 0
        return tree
    end
    node = random_node(tree)
    while node.degree == 0
        node = random_node(tree)
    end
    if node.degree == 1
        node.op = rand(1:(options.nuna))
    else
        node.op = rand(1:(options.nbin))
    end
    return tree
end

# Randomly perturb a constant
function mutate_constant(
    tree::Node{T}, temperature::T, options::Options
)::Node{T} where {T<:Real}
    # T is between 0 and 1.

    if count_constants(tree) == 0
        return tree
    end
    node = random_node(tree)
    while node.degree != 0 || node.constant == false
        node = random_node(tree)
    end

    bottom = 1//10
    maxChange = T(options.perturbationFactor) * temperature + T(1 + bottom)
    factor = maxChange^rand(T)
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

# Add a random unary/binary operation to the end of a tree
function append_random_op(
    tree::Node{T},
    options::Options,
    nfeatures::Int;
    makeNewBinOp::Union{Bool,Nothing}=nothing,
)::Node{T} where {T<:Real}
    node = random_node(tree)
    while node.degree != 0
        node = random_node(tree)
    end

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

    if newnode.degree == 2
        set_right!(node, right(newnode))
    end
    set_left!(node, left(newnode))
    node.op = newnode.op
    node.degree = newnode.degree
    node.val = newnode.val
    node.feature = newnode.feature
    node.constant = newnode.constant

    return tree
end

# Insert random node
function insert_random_op(
    tree::Node{T}, options::Options, nfeatures::Int
)::Node{T} where {T<:Real}
    node = random_node(tree)
    choice = rand()
    makeNewBinOp = choice < options.nbin / (options.nuna + options.nbin)
    new_left = copy_node(node)

    if makeNewBinOp
        new_right = make_random_leaf(nfeatures, T)
        newnode = Node(rand(1:(options.nbin)), new_left, new_right)
    else
        newnode = Node(rand(1:(options.nuna)), new_left)
    end
    if newnode.degree == 2
        set_right!(node, right(newnode))
    end
    set_left!(node, left(newnode))
    node.op = newnode.op
    node.degree = newnode.degree
    node.val = newnode.val
    node.feature = newnode.feature
    node.constant = newnode.constant
    return tree
end

# Add random node to the top of a tree
function prepend_random_op(
    tree::Node{T}, options::Options, nfeatures::Int
)::Node{T} where {T<:Real}
    node = tree
    choice = rand()
    makeNewBinOp = choice < options.nbin / (options.nuna + options.nbin)
    new_left = copy_node(tree)

    if makeNewBinOp
        new_right = make_random_leaf(nfeatures, T)
        newnode = Node(rand(1:(options.nbin)), new_left, new_right)
    else
        newnode = Node(rand(1:(options.nuna)), new_left)
    end
    if newnode.degree == 2
        set_right!(node, right(newnode))
    end
    set_left!(node, left(newnode))
    node.op = newnode.op
    node.degree = newnode.degree
    node.val = newnode.val
    node.feature = newnode.feature
    node.constant = newnode.constant
    return node
end

function make_random_leaf(nfeatures::Int, ::Type{T})::Node{T} where {T<:Real}
    if rand() > 0.5
        return Node(; val=randn(T))
    else
        return Node(T; feature=rand(1:nfeatures))
    end
end

# Return a random node from the tree with parent, and side ('n' for no parent)
function random_node_and_parent(
    tree::Node{T}, parent::Union{Node{T},Nothing}; side::Char
)::Tuple{Node{T},Union{Node{T},Nothing},Char} where {T}
    if tree.degree == 0
        return tree, parent, side
    end
    b = 0
    c = 0
    if tree.degree >= 1
        b = count_nodes(left(tree))
    end
    if tree.degree == 2
        c = count_nodes(right(tree))
    end

    i = rand(1:(1 + b + c))
    if i <= b
        return random_node_and_parent(left(tree), tree; side='l')
    elseif i == b + 1
        return tree, parent, side
    end

    return random_node_and_parent(right(tree), tree; side='r')
end

function random_node_and_parent(
    tree::Node{T}
)::Tuple{Node{T},Union{Node{T},Nothing},Char} where {T}
    return random_node_and_parent(tree, nothing; side='n')
end

# Select a random node, and replace it an the subtree
# with a variable or constant
function delete_random_op(
    tree::Node{T}, options::Options, nfeatures::Int
)::Node{T} where {T<:Real}
    node, parent, side = random_node_and_parent(tree)
    isroot = (parent === nothing)

    if node.degree == 0
        # Replace with new constant
        newnode = make_random_leaf(nfeatures, T)
        node.degree = newnode.degree
        node.val = newnode.val
        node.constant = newnode.constant
        if !newnode.constant
            node.feature = newnode.feature
        end
    elseif node.degree == 1
        # Join one of the children with the parent
        if isroot
            return left(node)
        elseif left(parent) == node
            set_left!(parent, left(node))
        else
            set_right!(parent, left(node))
        end
    else
        # Join one of the children with the parent
        if rand() < 0.5
            if isroot
                return left(node)
            elseif left(parent) == node
                set_left!(parent, left(node))
            else
                set_right!(parent, left(node))
            end
        else
            if isroot
                return right(node)
            elseif left(parent) == node
                set_left!(parent, right(node))
            else
                set_right!(parent, right(node))
            end
        end
    end
    return tree
end

# Create a random equation by appending random operators
function gen_random_tree(
    length::Int, options::Options, nfeatures::Int, ::Type{T}
)::Node{T} where {T<:Real}
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
)::Node{T} where {T<:Real}
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
        set_left!(parent1, copy_node(node2))
        # tree1 now contains this.
    elseif side1 == 'r'
        set_right!(parent1, copy_node(node2))
        # tree1 now contains this.
    else # 'n'
        # This means that there is no parent2.
        tree1 = copy_node(node2)
    end

    if side2 == 'l'
        set_left!(parent2, node1)
    elseif side2 == 'r'
        set_right!(parent2, node1)
    else # 'n'
        tree2 = node1
    end
    return tree1, tree2
end

end
