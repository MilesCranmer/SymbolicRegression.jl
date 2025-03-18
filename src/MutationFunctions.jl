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
    set_node!,
    count_nodes,
    has_constants,
    has_operators
using ..CoreModule: AbstractOptions, DATA_TYPE

"""
    get_contents_for_mutation(ex::AbstractExpression, rng::AbstractRNG)

Return the contents of an expression, which can be mutated.
You can overload this function for custom expression types that
need to be mutated in a specific way.

The second return value is an optional context object that will be
passed to the `with_contents_for_mutation` function.
"""
function get_contents_for_mutation(ex::AbstractExpression, rng::AbstractRNG)
    return get_contents(ex), nothing
end

"""
    with_contents_for_mutation(ex::AbstractExpression, context)

Replace the contents of an expression with the given context object.
You can overload this function for custom expression types that
need to be mutated in a specific way.
"""
function with_contents_for_mutation(ex::AbstractExpression, new_contents, ::Nothing)
    return with_contents(ex, new_contents)
end

function apply_tree_mutation(
    ex::AbstractExpression,
    rng::AbstractRNG,
    mutation_func::F,
    args::Vararg{Any,N};
    kwargs...,
) where {F<:Function,N}
    tree, context = get_contents_for_mutation(ex, rng)
    mutated_tree = mutation_func(tree, args..., rng; kwargs...)
    return with_contents_for_mutation(ex, mutated_tree, context)
end

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
    return apply_tree_mutation(ex, rng, swap_operands)
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
    ex::AbstractExpression, options::AbstractOptions, rng::AbstractRNG=default_rng()
)
    return apply_tree_mutation(ex, rng, mutate_operator, options)
end
function mutate_operator(
    tree::AbstractExpressionNode, options::AbstractOptions, rng::AbstractRNG=default_rng()
)
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
    ex::AbstractExpression,
    temperature,
    options::AbstractOptions,
    rng::AbstractRNG=default_rng(),
)
    return apply_tree_mutation(ex, rng, mutate_constant, temperature, options)
end
function mutate_constant(
    tree::AbstractExpressionNode{T},
    temperature,
    options::AbstractOptions,
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
    ex::AbstractExpression,
    options::AbstractOptions,
    nfeatures::Int,
    rng::AbstractRNG=default_rng();
    make_new_bin_op::Union{Bool,Nothing}=nothing,
)
    return apply_tree_mutation(
        ex, rng, append_random_op, options, nfeatures; make_new_bin_op=make_new_bin_op
    )
end
function append_random_op(
    tree::AbstractExpressionNode{T},
    options::AbstractOptions,
    nfeatures::Int,
    rng::AbstractRNG=default_rng();
    make_new_bin_op::Union{Bool,Nothing}=nothing,
) where {T<:DATA_TYPE}
    node = rand(rng, NodeSampler(; tree, filter=t -> t.degree == 0))

    _make_new_bin_op = @something(
        make_new_bin_op, rand(rng) < options.nbin / (options.nuna + options.nbin),
    )

    if _make_new_bin_op
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
    options::AbstractOptions,
    nfeatures::Int,
    rng::AbstractRNG=default_rng(),
) where {T<:DATA_TYPE}
    return apply_tree_mutation(ex, rng, insert_random_op, options, nfeatures)
end
function insert_random_op(
    tree::AbstractExpressionNode{T},
    options::AbstractOptions,
    nfeatures::Int,
    rng::AbstractRNG=default_rng(),
) where {T<:DATA_TYPE}
    node = rand(rng, NodeSampler(; tree))
    choice = rand(rng)
    make_new_bin_op = choice < options.nbin / (options.nuna + options.nbin)
    left = copy(node)

    if make_new_bin_op
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
    options::AbstractOptions,
    nfeatures::Int,
    rng::AbstractRNG=default_rng(),
) where {T<:DATA_TYPE}
    return apply_tree_mutation(ex, rng, prepend_random_op, options, nfeatures)
end
function prepend_random_op(
    tree::AbstractExpressionNode{T},
    options::AbstractOptions,
    nfeatures::Int,
    rng::AbstractRNG=default_rng(),
) where {T<:DATA_TYPE}
    node = tree
    choice = rand(rng)
    make_new_bin_op = choice < options.nbin / (options.nuna + options.nbin)
    left = copy(tree)

    if make_new_bin_op
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
    ::Union{AbstractOptions,Nothing}=nothing,
) where {T<:DATA_TYPE,N<:AbstractExpressionNode}
    if rand(rng, Bool)
        return constructorof(N)(T; val=randn(rng, T))
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
    options::AbstractOptions,
    nfeatures::Int,
    rng::AbstractRNG=default_rng(),
) where {T<:DATA_TYPE}
    return apply_tree_mutation(ex, rng, delete_random_op!, options, nfeatures)
end
function delete_random_op!(
    tree::AbstractExpressionNode{T},
    options::AbstractOptions,
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

function randomize_tree(
    ex::AbstractExpression,
    curmaxsize::Int,
    options::AbstractOptions,
    nfeatures::Int,
    rng::AbstractRNG=default_rng(),
)
    return apply_tree_mutation(ex, rng, randomize_tree, curmaxsize, options, nfeatures)
end
function randomize_tree(
    ::AbstractExpressionNode{T},
    curmaxsize::Int,
    options::AbstractOptions,
    nfeatures::Int,
    rng::AbstractRNG=default_rng(),
) where {T<:DATA_TYPE}
    tree_size_to_generate = rand(rng, 1:curmaxsize)
    return gen_random_tree_fixed_size(tree_size_to_generate, options, nfeatures, T, rng)
end

"""Create a random equation by appending random operators"""
function gen_random_tree(
    length::Int,
    options::AbstractOptions,
    nfeatures::Int,
    ::Type{T},
    rng::AbstractRNG=default_rng(),
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
    options::AbstractOptions,
    nfeatures::Int,
    ::Type{T},
    rng::AbstractRNG=default_rng(),
) where {T<:DATA_TYPE}
    tree = make_random_leaf(nfeatures, T, options.node_type, rng, options)
    cur_size = count_nodes(tree)
    while cur_size < node_count
        if cur_size == node_count - 1  # only unary operator allowed.
            options.nuna == 0 && break # We will go over the requested amount, so we must break.
            tree = append_random_op(tree, options, nfeatures, rng; make_new_bin_op=false)
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
    if ex1 === ex2
        error("Attempted to crossover the same expression!")
    end
    tree1, context1 = get_contents_for_mutation(ex1, rng)
    tree2, context2 = get_contents_for_mutation(ex2, rng)
    out1, out2 = crossover_trees(tree1, tree2, rng)
    ex1 = with_contents_for_mutation(ex1, out1, context1)
    ex2 = with_contents_for_mutation(ex2, out2, context2)
    return ex1, ex2
end

"""Crossover between two expressions"""
function crossover_trees(
    tree1::N, tree2::N, rng::AbstractRNG=default_rng()
) where {T,N<:AbstractExpressionNode{T}}
    if tree1 === tree2
        error("Attempted to crossover the same tree!")
    end
    tree1 = copy(tree1)
    tree2 = copy(tree2)

    node1, parent1, side1 = random_node_and_parent(tree1, rng)
    node2, parent2, side2 = random_node_and_parent(tree2, rng)

    node1 = copy(node1)

    if side1 == 'l'
        parent1.l = copy(node2)
        # tree1 now contains this.
    elseif side1 == 'r'
        parent1.r = copy(node2)
        # tree1 now contains this.
    else # 'n'
        # This means that there is no parent2.
        tree1 = copy(node2)
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
    return apply_tree_mutation(ex, rng, form_random_connection!)
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
    return apply_tree_mutation(ex, rng, break_random_connection!)
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
    return (node.degree > 0 && node.l.degree > 0) || (node.degree == 2 && node.r.degree > 0)
end

function randomly_rotate_tree!(ex::AbstractExpression, rng::AbstractRNG=default_rng())
    return apply_tree_mutation(ex, rng, randomly_rotate_tree!)
end
function randomly_rotate_tree!(tree::AbstractNode, rng::AbstractRNG=default_rng())
    num_rotation_nodes = count(is_valid_rotation_node, tree)

    # Return the tree if no valid nodes are found
    if num_rotation_nodes == 0
        return tree
    end

    root_is_valid_rotation_node = is_valid_rotation_node(tree)

    # Now, we decide if we want to rotate at the root, or at a random node
    rotate_at_root = root_is_valid_rotation_node && rand(rng) < 1.0 / num_rotation_nodes

    subtree_parent = if rotate_at_root
        tree
    else
        rand(
            rng,
            NodeSampler(;
                tree,
                filter=t -> (
                    (t.degree > 0 && is_valid_rotation_node(t.l)) ||
                    (t.degree == 2 && is_valid_rotation_node(t.r))
                ),
            ),
        )
    end

    subtree_side = if rotate_at_root
        :n
    elseif subtree_parent.degree == 1
        :l
    else
        if is_valid_rotation_node(subtree_parent.l) &&
            (!is_valid_rotation_node(subtree_parent.r) || rand(rng, Bool))
            :l
        else
            :r
        end
    end

    subtree_root = if rotate_at_root
        tree
    elseif subtree_side == :l
        subtree_parent.l
    else
        subtree_parent.r
    end

    # Perform the rotation
    # (reference: https://web.archive.org/web/20230326202118/https://upload.wikimedia.org/wikipedia/commons/1/15/Tree_Rotations.gif)
    right_rotation_valid = subtree_root.l.degree > 0
    left_rotation_valid = subtree_root.degree == 2 && subtree_root.r.degree > 0

    right_rotation = right_rotation_valid && (!left_rotation_valid || rand(rng, Bool))
    if right_rotation
        node_5 = subtree_root
        node_3 = leftmost(node_5)
        node_4 = rightmost(node_3)

        set_leftmost!(node_5, node_4)
        set_rightmost!(node_3, node_5)
        if rotate_at_root
            return node_3  # new root
        elseif subtree_side == :l
            subtree_parent.l = node_3
        else
            subtree_parent.r = node_3
        end
    else  # left rotation
        node_3 = subtree_root
        node_5 = rightmost(node_3)
        node_4 = leftmost(node_5)

        set_rightmost!(node_3, node_4)
        set_leftmost!(node_5, node_3)
        if rotate_at_root
            return node_5  # new root
        elseif subtree_side == :l
            subtree_parent.l = node_5
        else
            subtree_parent.r = node_5
        end
    end

    return tree
end

#! format: off
# These functions provide an easier way to work with unary nodes, by
# simply letting `.r` fall back to `.l` if the node is a unary operator.
leftmost(node::AbstractNode) = node.l
rightmost(node::AbstractNode) = node.degree == 1 ? node.l : node.r
set_leftmost!(node::AbstractNode, l::AbstractNode) = (node.l = l)
set_rightmost!(node::AbstractNode, r::AbstractNode) = node.degree == 1 ? (node.l = r) : (node.r = r)
#! format: on

end
