module MutationFunctionsModule

using DynamicExpressions:
    AbstractExpressionNode,
    AbstractNode,
    NodeSampler,
    constructorof,
    copy_node,
    set_node!,
    count_nodes,
    has_constants,
    has_operators
using Compat: Returns, @inline
using ..CoreModule: Options, DATA_TYPE

"""
    random_node(tree::AbstractNode; filter::F=Returns(true))

Return a random node from the tree. You may optionally
filter the nodes matching some condition before sampling.
"""
function random_node(tree::AbstractNode; filter::F=Returns(true)) where {F<:Function}
    Base.depwarn(
        "Instead of `random_node(tree, filter)`, use `rand(NodeSampler(; tree, filter))`",
        :random_node,
    )
    return rand(NodeSampler(; tree, filter))
end

"""Swap operands in binary operator for ops like pow and divide"""
function swap_operands(tree::AbstractNode)
    if !any(node -> node.degree == 2, tree)
        return tree
    end
    node = rand(NodeSampler(; tree, filter=t -> t.degree == 2))
    node.l, node.r = node.r, node.l
    return tree
end

"""Randomly convert an operator into another one (binary->binary; unary->unary)"""
function mutate_operator(tree::AbstractExpressionNode{T}, options::Options) where {T}
    if !(has_operators(tree))
        return tree
    end
    node = rand(NodeSampler(; tree, filter=t -> t.degree != 0))
    if node.degree == 1
        node.op = rand(1:(options.nuna))
    else
        node.op = rand(1:(options.nbin))
    end
    return tree
end

"""Randomly perturb a constant"""
function mutate_constant(
    tree::AbstractExpressionNode{T}, temperature, options::Options
) where {T<:DATA_TYPE}
    # T is between 0 and 1.

    if !(has_constants(tree))
        return tree
    end
    node = rand(NodeSampler(; tree, filter=t -> (t.degree == 0 && t.constant)))

    bottom = 1//10
    maxChange = options.perturbation_factor * temperature + 1 + bottom
    factor = T(maxChange^rand(T))
    makeConstBigger = rand(Bool)

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

"""Add a random unary/binary operation to the end of a tree"""
function append_random_op(
    tree::AbstractExpressionNode{T},
    options::Options,
    nfeatures::Int;
    makeNewBinOp::Union{Bool,Nothing}=nothing,
) where {T<:DATA_TYPE}
    node = rand(NodeSampler(; tree, filter=t -> t.degree == 0))

    if makeNewBinOp === nothing
        choice = rand()
        makeNewBinOp = choice < options.nbin / (options.nuna + options.nbin)
    end

    if makeNewBinOp
        newnode = constructorof(typeof(tree))(
            rand(1:(options.nbin)),
            make_random_leaf(nfeatures, T, typeof(tree)),
            make_random_leaf(nfeatures, T, typeof(tree)),
        )
    else
        newnode = constructorof(typeof(tree))(
            rand(1:(options.nuna)), make_random_leaf(nfeatures, T, typeof(tree))
        )
    end

    set_node!(node, newnode)

    return tree
end

"""Insert random node"""
function insert_random_op(
    tree::AbstractExpressionNode{T}, options::Options, nfeatures::Int
) where {T<:DATA_TYPE}
    node = rand(NodeSampler(; tree))
    choice = rand()
    makeNewBinOp = choice < options.nbin / (options.nuna + options.nbin)
    left = copy_node(node)

    if makeNewBinOp
        right = make_random_leaf(nfeatures, T, typeof(tree))
        newnode = constructorof(typeof(tree))(rand(1:(options.nbin)), left, right)
    else
        newnode = constructorof(typeof(tree))(rand(1:(options.nuna)), left)
    end
    set_node!(node, newnode)
    return tree
end

"""Add random node to the top of a tree"""
function prepend_random_op(
    tree::AbstractExpressionNode{T}, options::Options, nfeatures::Int
) where {T<:DATA_TYPE}
    node = tree
    choice = rand()
    makeNewBinOp = choice < options.nbin / (options.nuna + options.nbin)
    left = copy_node(tree)

    if makeNewBinOp
        right = make_random_leaf(nfeatures, T, typeof(tree))
        newnode = constructorof(typeof(tree))(rand(1:(options.nbin)), left, right)
    else
        newnode = constructorof(typeof(tree))(rand(1:(options.nuna)), left)
    end
    set_node!(node, newnode)
    return node
end

function make_random_leaf(
    nfeatures::Int, ::Type{T}, ::Type{N}
) where {T<:DATA_TYPE,N<:AbstractExpressionNode}
    if rand(Bool)
        return constructorof(N)(; val=randn(T))
    else
        return constructorof(N)(T; feature=rand(1:nfeatures))
    end
end

"""Return a random node from the tree with parent, and side ('n' for no parent)"""
function random_node_and_parent(tree::AbstractNode)
    if tree.degree == 0
        return tree, tree, 'n'
    end
    parent = rand(NodeSampler(; tree, filter=t -> t.degree != 0))
    if parent.degree == 1 || rand(Bool)
        return (parent.l, parent, 'l')
    else
        return (parent.r, parent, 'r')
    end
end

"""Select a random node, and splice it out of the tree."""
function delete_random_op!(
    tree::AbstractExpressionNode{T}, options::Options, nfeatures::Int
) where {T<:DATA_TYPE}
    node, parent, side = random_node_and_parent(tree)
    isroot = side == 'n'

    if node.degree == 0
        # Replace with new constant
        newnode = make_random_leaf(nfeatures, T, typeof(tree))
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
        if rand(Bool)
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

"""Create a random equation by appending random operators"""
function gen_random_tree(
    length::Int, options::Options, nfeatures::Int, ::Type{T}, ::Type{N}
) where {T<:DATA_TYPE,N<:AbstractExpressionNode}
    # Note that this base tree is just a placeholder; it will be replaced.
    tree = constructorof(N)(T; val=convert(T, 1))
    for i in 1:length
        # TODO: This can be larger number of nodes than length.
        tree = append_random_op(tree, options, nfeatures)
    end
    return tree
end

function gen_random_tree_fixed_size(
    node_count::Int, options::Options, nfeatures::Int, ::Type{T}, ::Type{N}
) where {T<:DATA_TYPE,N<:AbstractExpressionNode}
    tree = make_random_leaf(nfeatures, T, N)
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
function crossover_trees(
    tree1::AbstractExpressionNode{T}, tree2::AbstractExpressionNode{T}
) where {T}
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

function form_random_connection!(tree::AbstractNode)
    if length(tree) < 5
        return tree
    end

    local parent, new_child, would_form_loop

    attempt_number = 0
    max_attempts = 10

    while true
        parent = rand(NodeSampler(; tree, filter=t -> t.degree != 0))
        new_child = rand(NodeSampler(; tree, filter=t -> t !== tree))
        attempt_number += 1
        would_form_loop = any(t -> t === parent, new_child)
        if would_form_loop && attempt_number <= max_attempts
            continue
        else
            break
        end
    end
    if would_form_loop
        return tree
    end
    # Set one of the children to be this new child:
    side = (parent.degree == 1 || rand(Bool)) ? :l : :r
    setproperty!(parent, side, new_child)
    return tree
end
function break_random_connection!(tree::AbstractNode)
    tree.degree == 0 && return tree
    parent = rand(NodeSampler(; tree, filter=t -> t.degree != 0))
    side = (parent.degree == 1 || rand(Bool)) ? :l : :r
    unshared_child = copy(getproperty(parent, side))
    setproperty!(parent, side, unshared_child)
    return tree
end

end
