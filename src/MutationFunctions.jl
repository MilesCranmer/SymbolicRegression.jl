module MutationFunctionsModule

using Random: default_rng, AbstractRNG
using DynamicExpressions:
    AbstractExpressionNode,
    AbstractExpression,
    AbstractNode,
    NodeSampler,
    get_contents,
    with_contents,
    constructorof,
    copy_node,
    set_node!,
    count_nodes,
    has_constants,
    has_operators
using Compat: Returns, @inline, Fix
using ..CoreModule: Options, DATA_TYPE

"""
    random_node(tree::AbstractNode; filter::F=Returns(true))

Return a random node from the tree. You may optionally
filter the nodes matching some condition before sampling.
"""
function random_node(
    tree::AbstractNode, rng::AbstractRNG=default_rng(); filter::F=Returns(true)
) where {F<:Function}
    Base.depwarn(
        "Instead of `random_node(tree, filter)`, use `rand(NodeSampler(; tree, filter))`",
        :random_node,
    )
    return rand(rng, NodeSampler(; tree, filter))
end

"""Swap operands in binary operator for ops like pow and divide"""
function swap_operands(ex::AbstractExpression, rng::AbstractRNG=default_rng())
    tree = get_contents(ex)
    ex = with_contents(ex, swap_operands(tree, rng))
    return ex
end
function swap_operands(tree::AbstractNode, rng::AbstractRNG=default_rng())
    if !any(node -> node.degree == 2, tree)
        return tree
    end
    node = rand(rng, NodeSampler(; tree, filter=t -> t.degree == 2))
    node.l, node.r = node.r, node.l
    return tree
end

"""Randomly convert an operator into another one (binary->binary; unary->unary)"""
function mutate_operator(
    ex::AbstractExpression{T}, options::Options, rng::AbstractRNG=default_rng()
) where {T<:DATA_TYPE}
    tree = get_contents(ex)
    ex = with_contents(ex, mutate_operator(tree, options, rng))
    return ex
end
function mutate_operator(
    tree::AbstractExpressionNode{T}, options::Options, rng::AbstractRNG=default_rng()
) where {T}
    if !(has_operators(tree))
        return tree
    end
    node = rand(rng, NodeSampler(; tree, filter=t -> t.degree != 0))
    if node.degree == 1
        node.op = rand(rng, 1:(options.nuna))
    else
        node.op = rand(rng, 1:(options.nbin))
    end
    return tree
end

"""Randomly perturb a constant"""
function mutate_constant(
    ex::AbstractExpression{T}, temperature, options::Options, rng::AbstractRNG=default_rng()
) where {T<:DATA_TYPE}
    tree = get_contents(ex)
    ex = with_contents(ex, mutate_constant(tree, temperature, options, rng))
    return ex
end
function mutate_constant(
    tree::AbstractExpressionNode{T},
    temperature,
    options::Options,
    rng::AbstractRNG=default_rng(),
) where {T<:DATA_TYPE}
    # T is between 0 and 1.

    if !(has_constants(tree))
        return tree
    end
    node = rand(rng, NodeSampler(; tree, filter=t -> (t.degree == 0 && t.constant)))

    node.val *= mutate_factor(T, temperature, options, rng)

    return tree
end

function mutate_factor(::Type{T}, temperature, options, rng) where {T<:DATA_TYPE}
    bottom = 1//10
    maxChange = options.perturbation_factor * temperature + 1 + bottom
    factor = T(maxChange^rand(rng, T))
    makeConstBigger = rand(rng, Bool)

    factor = makeConstBigger ? factor : 1 / factor

    if rand(rng) > options.probability_negate_constant
        factor *= -1
    end
    return factor
end

# TODO: Shouldn't we add a mutate_feature here?

"""Add a random unary/binary operation to the end of a tree"""
function append_random_op(
    ex::AbstractExpression{T},
    options::Options,
    nfeatures::Int,
    rng::AbstractRNG=default_rng();
    makeNewBinOp::Union{Bool,Nothing}=nothing,
) where {T<:DATA_TYPE}
    tree = get_contents(ex)
    ex = with_contents(ex, append_random_op(tree, options, nfeatures, rng; makeNewBinOp))
    return ex
end
function append_random_op(
    tree::AbstractExpressionNode{T},
    options::Options,
    nfeatures::Int,
    rng::AbstractRNG=default_rng();
    makeNewBinOp::Union{Bool,Nothing}=nothing,
) where {T<:DATA_TYPE}
    node = rand(rng, NodeSampler(; tree, filter=t -> t.degree == 0))

    if makeNewBinOp === nothing
        choice = rand(rng)
        makeNewBinOp = choice < options.nbin / (options.nuna + options.nbin)
    end

    if makeNewBinOp
        newnode = constructorof(typeof(tree))(;
            op=rand(rng, 1:(options.nbin)),
            l=make_random_leaf(nfeatures, T, typeof(tree), rng, options),
            r=make_random_leaf(nfeatures, T, typeof(tree), rng, options),
        )
    else
        newnode = constructorof(typeof(tree))(;
            op=rand(rng, 1:(options.nuna)),
            l=make_random_leaf(nfeatures, T, typeof(tree), rng, options),
        )
    end

    set_node!(node, newnode)

    return tree
end

"""Insert random node"""
function insert_random_op(
    ex::AbstractExpression{T},
    options::Options,
    nfeatures::Int,
    rng::AbstractRNG=default_rng(),
) where {T<:DATA_TYPE}
    tree = get_contents(ex)
    ex = with_contents(ex, insert_random_op(tree, options, nfeatures, rng))
    return ex
end
function insert_random_op(
    tree::AbstractExpressionNode{T},
    options::Options,
    nfeatures::Int,
    rng::AbstractRNG=default_rng(),
) where {T<:DATA_TYPE}
    node = rand(rng, NodeSampler(; tree))
    choice = rand(rng)
    makeNewBinOp = choice < options.nbin / (options.nuna + options.nbin)
    left = copy_node(node)

    if makeNewBinOp
        right = make_random_leaf(nfeatures, T, typeof(tree), rng, options)
        newnode = constructorof(typeof(tree))(;
            op=rand(rng, 1:(options.nbin)), l=left, r=right
        )
    else
        newnode = constructorof(typeof(tree))(; op=rand(rng, 1:(options.nuna)), l=left)
    end
    set_node!(node, newnode)
    return tree
end

"""Add random node to the top of a tree"""
function prepend_random_op(
    ex::AbstractExpression{T},
    options::Options,
    nfeatures::Int,
    rng::AbstractRNG=default_rng(),
) where {T<:DATA_TYPE}
    tree = get_contents(ex)
    ex = with_contents(ex, prepend_random_op(tree, options, nfeatures, rng))
    return ex
end
function prepend_random_op(
    tree::AbstractExpressionNode{T},
    options::Options,
    nfeatures::Int,
    rng::AbstractRNG=default_rng(),
) where {T<:DATA_TYPE}
    node = tree
    choice = rand(rng)
    makeNewBinOp = choice < options.nbin / (options.nuna + options.nbin)
    left = copy_node(tree)

    if makeNewBinOp
        right = make_random_leaf(nfeatures, T, typeof(tree), rng, options)
        newnode = constructorof(typeof(tree))(;
            op=rand(rng, 1:(options.nbin)), l=left, r=right
        )
    else
        newnode = constructorof(typeof(tree))(; op=rand(rng, 1:(options.nuna)), l=left)
    end
    set_node!(node, newnode)
    return node
end

function make_random_leaf(
    nfeatures::Int,
    ::Type{T},
    ::Type{N},
    rng::AbstractRNG=default_rng(),
    ::Union{Options,Nothing}=nothing,
) where {T<:DATA_TYPE,N<:AbstractExpressionNode}
    if rand(rng, Bool)
        return constructorof(N)(; val=randn(rng, T))
    else
        return constructorof(N)(T; feature=rand(rng, 1:nfeatures))
    end
end

"""Return a random node from the tree with parent, and side ('n' for no parent)"""
function random_node_and_parent(tree::AbstractNode, rng::AbstractRNG=default_rng())
    if tree.degree == 0
        return tree, tree, 'n'
    end
    parent = rand(rng, NodeSampler(; tree, filter=t -> t.degree != 0))
    if parent.degree == 1 || rand(rng, Bool)
        return (parent.l, parent, 'l')
    else
        return (parent.r, parent, 'r')
    end
end

"""Select a random node, and splice it out of the tree."""
function delete_random_op!(
    ex::AbstractExpression{T},
    options::Options,
    nfeatures::Int,
    rng::AbstractRNG=default_rng(),
) where {T<:DATA_TYPE}
    tree = get_contents(ex)
    ex = with_contents(ex, delete_random_op!(tree, options, nfeatures, rng))
    return ex
end
function delete_random_op!(
    tree::AbstractExpressionNode{T},
    options::Options,
    nfeatures::Int,
    rng::AbstractRNG=default_rng(),
) where {T<:DATA_TYPE}
    node, parent, side = random_node_and_parent(tree, rng)
    isroot = side == 'n'

    if node.degree == 0
        # Replace with new constant
        newnode = make_random_leaf(nfeatures, T, typeof(tree), rng, options)
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
        if rand(rng, Bool)
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
    length::Int, options::Options, nfeatures::Int, ::Type{T}, rng::AbstractRNG=default_rng()
) where {T<:DATA_TYPE}
    # Note that this base tree is just a placeholder; it will be replaced.
    tree = constructorof(options.node_type)(T; val=convert(T, 1))
    for i in 1:length
        # TODO: This can be larger number of nodes than length.
        tree = append_random_op(tree, options, nfeatures, rng)
    end
    return tree
end

function gen_random_tree_fixed_size(
    node_count::Int,
    options::Options,
    nfeatures::Int,
    ::Type{T},
    rng::AbstractRNG=default_rng(),
) where {T<:DATA_TYPE}
    tree = make_random_leaf(nfeatures, T, options.node_type, rng, options)
    cur_size = count_nodes(tree)
    while cur_size < node_count
        if cur_size == node_count - 1  # only unary operator allowed.
            options.nuna == 0 && break # We will go over the requested amount, so we must break.
            tree = append_random_op(tree, options, nfeatures, rng; makeNewBinOp=false)
        else
            tree = append_random_op(tree, options, nfeatures, rng)
        end
        cur_size = count_nodes(tree)
    end
    return tree
end

function crossover_trees(
    ex1::E, ex2::E, rng::AbstractRNG=default_rng()
) where {T,E<:AbstractExpression{T}}
    tree1 = get_contents(ex1)
    tree2 = get_contents(ex2)
    out1, out2 = crossover_trees(tree1, tree2, rng)
    ex1 = with_contents(ex1, out1)
    ex2 = with_contents(ex2, out2)
    return ex1, ex2
end

"""Crossover between two expressions"""
function crossover_trees(
    tree1::N, tree2::N, rng::AbstractRNG=default_rng()
) where {T,N<:AbstractExpressionNode{T}}
    tree1 = copy_node(tree1)
    tree2 = copy_node(tree2)

    node1, parent1, side1 = random_node_and_parent(tree1, rng)
    node2, parent2, side2 = random_node_and_parent(tree2, rng)

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

function get_two_nodes_without_loop(tree::AbstractNode, rng::AbstractRNG; max_attempts=10)
    for _ in 1:max_attempts
        parent = rand(rng, NodeSampler(; tree, filter=t -> t.degree != 0))
        new_child = rand(rng, NodeSampler(; tree, filter=t -> t !== tree))

        would_form_loop = any(t -> t === parent, new_child)
        if !would_form_loop
            return (parent, new_child, false)
        end
    end
    return (tree, tree, true)
end

function form_random_connection!(ex::AbstractExpression, rng::AbstractRNG=default_rng())
    tree = get_contents(ex)
    return with_contents(ex, form_random_connection!(tree, rng))
end
function form_random_connection!(tree::AbstractNode, rng::AbstractRNG=default_rng())
    if length(tree) < 5
        return tree
    end

    parent, new_child, would_form_loop = get_two_nodes_without_loop(tree, rng)

    if would_form_loop
        return tree
    end

    # Set one of the children to be this new child:
    if parent.degree == 1 || rand(rng, Bool)
        parent.l = new_child
    else
        parent.r = new_child
    end
    return tree
end

function break_random_connection!(ex::AbstractExpression, rng::AbstractRNG=default_rng())
    tree = get_contents(ex)
    return with_contents(ex, break_random_connection!(tree, rng))
end
function break_random_connection!(tree::AbstractNode, rng::AbstractRNG=default_rng())
    tree.degree == 0 && return tree
    parent = rand(rng, NodeSampler(; tree, filter=t -> t.degree != 0))
    if parent.degree == 1 || rand(rng, Bool)
        parent.l = copy(parent.l)
    else
        parent.r = copy(parent.r)
    end
    return tree
end

function is_valid_rotation_node(node::AbstractNode)
    return node.degree == 2 && ((node.l.degree == 2) || (node.r.degree == 2))
end

function randomly_rotate_tree!(ex::AbstractExpression, rng::AbstractRNG=default_rng())
    tree = get_contents(ex)
    rotated_tree = randomly_rotate_tree!(tree, rng)
    return with_contents(ex, rotated_tree)
end

function randomly_rotate_tree!(tree::AbstractNode, rng::AbstractRNG=default_rng())
    # Return the tree if no valid nodes are found
    if !any(is_valid_rotation_node, tree)
        return tree
    end

    # Find a parent node with degree 2 and a child with degree 2
    parent = rand(rng, NodeSampler(; tree, filter=is_valid_rotation_node))

    # Randomly choose rotation direction
    right_rotation_valid = parent.l.degree == 2
    left_rotation_valid = parent.r.degree == 2

    right_rotation = right_rotation_valid && (!left_rotation_valid || rand(rng, Bool))

    # Perform the rotation
    # (reference: https://web.archive.org/web/20230326202118/https://upload.wikimedia.org/wikipedia/commons/1/15/Tree_Rotations.gif)
    if right_rotation
        node_5 = parent
        node_3 = parent.l
        node_4 = node_3.r

        node_5.l = node_4
        node_3.r = node_5

        if node_5 === tree
            # No parent to node_5, so we can just
            # rearrange connections and be done
            return node_3  # new root
        else
            # Need to attach to any parent of `node_5`, since `node_5`
            # was not the root node
            # TODO: This doesn't feel very robust. For us to work around this
            # in a clean way, we would need a sampler that returns the parent,
            # OR have a separate sampling step for root nodes and sampling the parent
            # node. Currently I feel that the way implemented currently is probably faster,
            # but need testing.
            attach_to_parents!(tree, node_5, node_3)
            return tree
        end
    else  # left rotation
        node_3 = parent
        node_5 = parent.r
        node_4 = node_5.l

        node_3.r = node_4
        node_5.l = node_3

        if node_3 === tree
            # No parent to node_3, so we can just
            # rearrange connections and be done
            return node_5  # new root
        else
            # Need to attach to any parent of `node_3`, since `node_3`
            # was not the root node
            attach_to_parents!(tree, node_3, node_5)
            return tree
        end
    end
end

"""
Find a node with `oldchild` as a child, put `newchild` there instead,
skipping any node matching `newchild` (to avoid loops)

Note that this function assumes there will only be a single match in the tree,
after which it will exit.
"""
function attach_to_parents!(tree::N, oldchild::N, newchild::N) where {N<:AbstractNode}
    attached = any(Fix{2}(Fix{3}(attach_to_parents_closure, newchild), oldchild), tree)
    #! format: off
    attached || throw(ArgumentError("Failed to attach node to any parent in $tree. Please file a bug report if this is unexpected."))
    #! format: on
    return nothing
end
function attach_to_parents_closure(t::N, oldchild::N, newchild::N) where {N<:AbstractNode}
    if t === newchild
        # Avoid loops
        false
    elseif t.degree == 0
        false
    elseif t.degree == 1
        if t.l === oldchild
            t.l = newchild
            true
        else
            false
        end
    else  # t.degree == 2
        if t.l === oldchild
            t.l = newchild
            true
        elseif t.r === oldchild
            t.r = newchild
            true
        else
            false
        end
    end
end

end
