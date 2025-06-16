module MutationFunctionsModule

using Random: default_rng, AbstractRNG
using StatsBase: sample, Weights
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
    has_operators,
    get_child,
    set_child!
using ..CoreModule: AbstractOptions, DATA_TYPE, init_value, sample_value

import ..CoreModule: mutate_value

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
    tree, context = get_contents_for_mutation(ex, rng)
    ex = with_contents_for_mutation(ex, swap_operands(tree, rng), context)
    return ex
end
function swap_operands(tree::AbstractExpressionNode, rng::AbstractRNG=default_rng())
    if !any(node -> node.degree >= 2, tree)
        return tree
    end
    node = rand(rng, NodeSampler(; tree, filter=t -> t.degree >= 2))
    if node.degree >= 2
        # Swap first two children for operators with arity >= 2
        child1 = get_child(node, 1)
        child2 = get_child(node, 2)
        set_child!(node, child2, 1)
        set_child!(node, child1, 2)
    end
    return tree
end

"""Randomly convert an operator into another one (with same arity)"""
function mutate_operator(
    ex::AbstractExpression{T}, options::AbstractOptions, rng::AbstractRNG=default_rng()
) where {T<:DATA_TYPE}
    tree, context = get_contents_for_mutation(ex, rng)
    ex = with_contents_for_mutation(ex, mutate_operator(tree, options, rng), context)
    return ex
end
function mutate_operator(
    tree::AbstractExpressionNode{T},
    options::AbstractOptions,
    rng::AbstractRNG=default_rng(),
) where {T}
    if !(has_operators(tree))
        return tree
    end
    node = rand(rng, NodeSampler(; tree, filter=t -> t.degree != 0))
    degree = node.degree
    if degree <= length(options.nops) && options.nops[degree] > 0
        node.op = rand(rng, 1:(options.nops[degree]))
    end
    return tree
end

"""Randomly perturb a constant"""
function mutate_constant(
    ex::AbstractExpression{T},
    temperature,
    options::AbstractOptions,
    rng::AbstractRNG=default_rng(),
) where {T<:DATA_TYPE}
    tree, context = get_contents_for_mutation(ex, rng)
    ex = with_contents_for_mutation(
        ex, mutate_constant(tree, temperature, options, rng), context
    )
    return ex
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
    node.val = mutate_value(rng, node.val, temperature, options)
    return tree
end

function mutate_value(rng::AbstractRNG, val::Number, temperature, options)
    return val * mutate_factor(typeof(val), temperature, options, rng)
end

function mutate_factor(::Type{T}, temperature, options, rng) where {T<:Number}
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
    options::AbstractOptions,
    nfeatures::Int,
    rng::AbstractRNG=default_rng();
    make_new_bin_op::Union{Bool,Nothing}=nothing,
) where {T<:DATA_TYPE}
    tree, context = get_contents_for_mutation(ex, rng)
    ex = with_contents_for_mutation(
        ex, append_random_op(tree, options, nfeatures, rng; make_new_bin_op), context
    )
    return ex
end
function append_random_op(
    tree::AbstractExpressionNode{T},
    options::AbstractOptions,
    nfeatures::Int,
    rng::AbstractRNG=default_rng();
    make_new_bin_op::Union{Bool,Nothing}=nothing,
) where {T<:DATA_TYPE}
    node = rand(rng, NodeSampler(; tree, filter=t -> t.degree == 0))

    # Determine available arities
    max_arity = length(options.nops)
    available_arities = [i for i in 1:max_arity if options.nops[i] > 0]
    
    if isempty(available_arities)
        return tree
    end
    
    # Choose arity
    target_arity = if make_new_bin_op === true && 2 in available_arities
        2
    elseif make_new_bin_op === false && 1 in available_arities
        1
    else
        # Choose based on probability weights
        arity_weights = [options.nops[i] for i in available_arities]
        sample(rng, available_arities, Weights(arity_weights))
    end

    children = [make_random_leaf(nfeatures, T, typeof(tree), rng, options) for _ in 1:target_arity]
    newnode = constructorof(typeof(tree))(;
        op=rand(rng, 1:(options.nops[target_arity])),
        children=tuple(children...)
    )

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
    tree, context = get_contents_for_mutation(ex, rng)
    ex = with_contents_for_mutation(
        ex, insert_random_op(tree, options, nfeatures, rng), context
    )
    return ex
end
function insert_random_op(
    tree::AbstractExpressionNode{T},
    options::AbstractOptions,
    nfeatures::Int,
    rng::AbstractRNG=default_rng(),
) where {T<:DATA_TYPE}
    node = rand(rng, NodeSampler(; tree))
    
    # Determine available arities
    max_arity = length(options.nops)
    available_arities = [i for i in 1:max_arity if options.nops[i] > 0]
    
    if isempty(available_arities)
        return tree
    end
    
    # Choose arity based on probability
    arity_weights = [options.nops[i] for i in available_arities]
    target_arity = sample(rng, available_arities, Weights(arity_weights))
    
    # Create children - existing node plus additional random leaves
    children = [copy(node)]
    for _ in 2:target_arity
        push!(children, make_random_leaf(nfeatures, T, typeof(tree), rng, options))
    end
    
    newnode = constructorof(typeof(tree))(;
        op=rand(rng, 1:(options.nops[target_arity])),
        children=tuple(children...)
    )
    
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
    tree, context = get_contents_for_mutation(ex, rng)
    ex = with_contents_for_mutation(
        ex, prepend_random_op(tree, options, nfeatures, rng), context
    )
    return ex
end
function prepend_random_op(
    tree::AbstractExpressionNode{T},
    options::AbstractOptions,
    nfeatures::Int,
    rng::AbstractRNG=default_rng(),
) where {T<:DATA_TYPE}
    # Determine available arities
    max_arity = length(options.nops)
    available_arities = [i for i in 1:max_arity if options.nops[i] > 0]
    
    if isempty(available_arities)
        return tree
    end
    
    # Choose arity based on probability
    arity_weights = [options.nops[i] for i in available_arities]
    target_arity = sample(rng, available_arities, Weights(arity_weights))
    
    # Create children - existing tree plus additional random leaves
    children = [copy(tree)]
    for _ in 2:target_arity
        push!(children, make_random_leaf(nfeatures, T, typeof(tree), rng, options))
    end
    
    newnode = constructorof(typeof(tree))(;
        op=rand(rng, 1:(options.nops[target_arity])),
        children=tuple(children...)
    )
    
    return newnode
end

function make_random_leaf(
    nfeatures::Int,
    ::Type{T},
    ::Type{N},
    rng::AbstractRNG=default_rng(),
    options::Union{AbstractOptions,Nothing}=nothing,
) where {T<:DATA_TYPE,N<:AbstractExpressionNode}
    if rand(rng, Bool)
        return constructorof(N)(T; val=sample_value(rng, T, options))
    else
        return constructorof(N)(T; feature=rand(rng, 1:nfeatures))
    end
end

"""Return a random node from the tree with parent, and side (child index or nothing for no parent)"""
function random_node_and_parent(tree::AbstractNode, rng::AbstractRNG=default_rng())
    if tree.degree == 0
        return tree, tree, nothing
    end
    parent = rand(rng, NodeSampler(; tree, filter=t -> t.degree != 0))
    child_index = rand(rng, 1:parent.degree)
    child = get_child(parent, child_index)
    return (child, parent, child_index)
end

"""Select a random node, and splice it out of the tree."""
function delete_random_op!(
    ex::AbstractExpression{T},
    options::AbstractOptions,
    nfeatures::Int,
    rng::AbstractRNG=default_rng(),
) where {T<:DATA_TYPE}
    tree, context = get_contents_for_mutation(ex, rng)
    ex = with_contents_for_mutation(
        ex, delete_random_op!(tree, options, nfeatures, rng), context
    )
    return ex
end
function delete_random_op!(
    tree::AbstractExpressionNode{T},
    options::AbstractOptions,
    nfeatures::Int,
    rng::AbstractRNG=default_rng(),
) where {T<:DATA_TYPE}
    node, parent, side = random_node_and_parent(tree, rng)
    isroot = side == nothing

    if node.degree == 0
        # Replace with new constant
        newnode = make_random_leaf(nfeatures, T, typeof(tree), rng, options)
        set_node!(node, newnode)
    elseif node.degree == 1
        # Replace node with its single child
        child = get_child(node, 1)
        if isroot
            return child
        else
            set_child!(parent, child, side)
        end
    else
        # Choose a random child to replace this node
        chosen_child_idx = rand(rng, 1:node.degree)
        replacement_child = get_child(node, chosen_child_idx)
        
        if isroot
            return replacement_child
        else
            set_child!(parent, replacement_child, side)
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
    tree, context = get_contents_for_mutation(ex, rng)
    ex = with_contents_for_mutation(
        ex, randomize_tree(tree, curmaxsize, options, nfeatures, rng), context
    )
    return ex
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
    tree = constructorof(options.node_type)(T; val=init_value(T))
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
            options.nops[1] == 0 && break # We will go over the requested amount, so we must break.
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

    if side1 != nothing
        set_child!(parent1, copy(node2), side1)
        # tree1 now contains the modified structure
    else # nothing
        # This means that there is no parent1.
        tree1 = copy(node2)
    end

    if side2 != nothing
        set_child!(parent2, node1, side2)
    else # nothing
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
    tree, context = get_contents_for_mutation(ex, rng)
    return with_contents_for_mutation(ex, form_random_connection!(tree, rng), context)
end
function form_random_connection!(tree::AbstractNode, rng::AbstractRNG=default_rng())
    if length(tree) < 5
        return tree
    end

    parent, new_child, forms_loop = get_two_nodes_without_loop(tree, rng)
    if forms_loop
        return tree
    end

    # Choose a random child position to replace
    child_idx = rand(rng, 1:parent.degree)
    old_child = get_child(parent, child_idx)
    set_child!(parent, new_child, child_idx)
    return tree
end

function break_random_connection!(ex::AbstractExpression, rng::AbstractRNG=default_rng())
    tree, context = get_contents_for_mutation(ex, rng)
    return with_contents_for_mutation(ex, break_random_connection!(tree, rng), context)
end
function break_random_connection!(tree::AbstractNode, rng::AbstractRNG=default_rng())
    tree.degree == 0 && return tree
    parent = rand(rng, NodeSampler(; tree, filter=t -> t.degree != 0))
    
    # Choose a random child to make a copy of (breaking shared references)
    child_idx = rand(rng, 1:parent.degree)
    child = get_child(parent, child_idx)
    set_child!(parent, copy(child), child_idx)
    
    return tree
end

function randomly_rotate_tree!(ex::AbstractExpression, rng::AbstractRNG=default_rng())
    tree, context = get_contents_for_mutation(ex, rng)
    rotated_tree = randomly_rotate_tree!(tree, rng)
    return with_contents_for_mutation(ex, rotated_tree, context)
end

function randomly_rotate_tree!(tree::AbstractNode, rng::AbstractRNG=default_rng())
    # For non-binary trees, rotation is not well-defined, so just return the tree
    # This could be enhanced in the future for specific arity cases
    return tree
end

end
