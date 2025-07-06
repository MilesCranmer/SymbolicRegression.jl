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
    has_operators,
    get_child,
    set_child!,
    max_degree
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
function swap_operands(tree::AbstractNode{2}, rng::AbstractRNG=default_rng())
    if !any(node -> node.degree == 2, tree)
        return tree
    end
    node = rand(rng, NodeSampler(; tree, filter=t -> t.degree == 2))
    node.l, node.r = node.r, node.l
    return tree
end

"""Randomly convert an operator into another one (binary->binary; unary->unary)"""
function mutate_operator(
    ex::AbstractExpression{T}, options::AbstractOptions, rng::AbstractRNG=default_rng()
) where {T<:DATA_TYPE}
    tree, context = get_contents_for_mutation(ex, rng)
    ex = with_contents_for_mutation(ex, mutate_operator(tree, options, rng), context)
    return ex
end
function mutate_operator(
    tree::AbstractExpressionNode, options::AbstractOptions, rng::AbstractRNG=default_rng()
)
    if !(has_operators(tree))
        return tree
    end
    node = rand(rng, NodeSampler(; tree, filter=t -> t.degree != 0))
    node.op = rand(rng, 1:(options.nops[node.degree]))
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
    tree::AbstractExpressionNode{T,2},
    options::AbstractOptions,
    nfeatures::Int,
    rng::AbstractRNG=default_rng();
    make_new_bin_op::Union{Bool,Nothing}=nothing,
) where {T<:DATA_TYPE}
    node = rand(rng, NodeSampler(; tree, filter=t -> t.degree == 0))

    _make_new_bin_op = @something(
        make_new_bin_op, rand(rng) < options.nops[2] / sum(values(options.nops)),
    )

    if _make_new_bin_op
        newnode = constructorof(typeof(tree))(;
            op=rand(rng, 1:(options.nops[2])),
            l=make_random_leaf(nfeatures, T, typeof(tree), rng, options),
            r=make_random_leaf(nfeatures, T, typeof(tree), rng, options),
        )
    else
        newnode = constructorof(typeof(tree))(;
            op=rand(rng, 1:(options.nops[1])),
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
    choice = rand(rng)
    make_new_bin_op = choice < options.nops[2] / sum(values(options.nops))
    left = copy(node)

    if make_new_bin_op
        right = make_random_leaf(nfeatures, T, typeof(tree), rng, options)
        newnode = constructorof(typeof(tree))(;
            op=rand(rng, 1:(options.nops[2])), l=left, r=right
        )
    else
        newnode = constructorof(typeof(tree))(; op=rand(rng, 1:(options.nops[1])), l=left)
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
    tree, context = get_contents_for_mutation(ex, rng)
    ex = with_contents_for_mutation(
        ex, prepend_random_op(tree, options, nfeatures, rng), context
    )
    return ex
end
function prepend_random_op(
    tree::AbstractExpressionNode{T,2},
    options::AbstractOptions,
    nfeatures::Int,
    rng::AbstractRNG=default_rng(),
) where {T<:DATA_TYPE}
    node = tree
    choice = rand(rng)
    make_new_bin_op = choice < options.nops[2] / sum(values(options.nops))
    left = copy(tree)

    if make_new_bin_op
        right = make_random_leaf(nfeatures, T, typeof(tree), rng, options)
        newnode = constructorof(typeof(tree))(;
            op=rand(rng, 1:(options.nops[2])), l=left, r=right
        )
    else
        newnode = constructorof(typeof(tree))(; op=rand(rng, 1:(options.nops[1])), l=left)
    end
    set_node!(node, newnode)
    return node
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

"""Select a random node, and splice it out of the tree."""
function delete_random_op!(ex::AbstractExpression, rng::AbstractRNG=default_rng())
    tree, ctx = get_contents_for_mutation(ex, rng)
    newtree = delete_random_op!(tree, rng)
    return with_contents_for_mutation(ex, newtree, ctx)
end

function delete_random_op!(tree::AbstractExpressionNode, rng::AbstractRNG=default_rng())
    tree.degree == 0 && return tree

    node = rand(rng, NodeSampler(; tree, filter=t -> t.degree > 0))
    carry_idx = rand(rng, 1:(node.degree))
    carry = get_child(node, carry_idx)

    if node === tree
        return carry
    else
        parent, idx = _find_parent(tree, node)
        set_child!(parent, carry, idx)
        return tree
    end
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

@generated function _make_node(
    arity::Int,
    proto::AbstractExpressionNode{<:Any,D},
    nfeatures::Int,
    ::Type{T},
    options::AbstractOptions,
    rng::AbstractRNG,
) where {T,D}
    quote
        Base.Cartesian.@nif(
            $D,
            i -> arity == i,
            i -> constructorof(typeof(proto))(;
                op=rand(rng, 1:options.nops[i]),
                children=Base.Cartesian.@ntuple(
                    i, j -> make_random_leaf(nfeatures, T, typeof(proto), rng, options),
                ),
            ),
        )
    end
end

function _arity_picker(rng::AbstractRNG, remaining::Int, nops::NTuple{D,Int}) where {D}
    total = 0
    for k in 1:min(D, remaining)
        total += @inbounds nops[k]
    end
    total == 0 && return 0

    thresh = rand(rng, 1:total)
    acc = 0
    for k in 1:min(D, remaining)
        acc += @inbounds nops[k]
        thresh <= acc && return k
    end
    return 0
end

function gen_random_tree_fixed_size(
    node_count::Int,
    options::AbstractOptions,
    nfeatures::Int,
    ::Type{T},
    rng::AbstractRNG=default_rng(),
) where {T<:DATA_TYPE}
    # (1) start with a single leaf
    tree = make_random_leaf(nfeatures, T, options.node_type, rng, options)
    cur_size = 1

    # (2) grow the tree
    while true
        remaining = node_count - cur_size
        remaining == 0 && break

        arity = _arity_picker(rng, remaining, options.nops)
        arity == 0 && break

        # choose a random leaf to expand
        leaf = rand(rng, NodeSampler(; tree, filter=t -> t.degree == 0))

        # make a new operator node of that arity
        newnode = _make_node(arity, leaf, nfeatures, T, options, rng)

        set_node!(leaf, newnode)
        cur_size += arity
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
) where {T,N<:AbstractExpressionNode{T,2}}
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
    tree, context = get_contents_for_mutation(ex, rng)
    return with_contents_for_mutation(ex, form_random_connection!(tree, rng), context)
end
function form_random_connection!(tree::AbstractNode{2}, rng::AbstractRNG=default_rng())
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
    tree, context = get_contents_for_mutation(ex, rng)
    return with_contents_for_mutation(ex, break_random_connection!(tree, rng), context)
end
function break_random_connection!(tree::AbstractNode{2}, rng::AbstractRNG=default_rng())
    tree.degree == 0 && return tree
    parent = rand(rng, NodeSampler(; tree, filter=t -> t.degree != 0))
    if parent.degree == 1 || rand(rng, Bool)
        parent.l = copy(parent.l)
    else
        parent.r = copy(parent.r)
    end
    return tree
end

function _find_parent(tree::N, node::N) where {N<:AbstractNode}
    r = Ref{Tuple{typeof(tree),Int}}()
    finished = any(tree) do t
        if t.degree > 0
            for i in 1:(t.degree)
                if get_child(t, i) === node
                    r[] = (t, i)
                    return true
                end
            end
        end
        return false
    end
    @assert finished
    return r[]
end

function _valid_rotation_root(tree::AbstractNode)
    return tree.degree > 0 && any(i -> get_child(tree, i).degree > 0, 1:(tree.degree))
end

function randomly_rotate_tree!(ex::AbstractExpression, rng::AbstractRNG=default_rng())
    tree, context = get_contents_for_mutation(ex, rng)
    rotated_tree = randomly_rotate_tree!(tree, rng)
    return with_contents_for_mutation(ex, rotated_tree, context)
end
function randomly_rotate_tree!(tree::AbstractExpressionNode, rng::AbstractRNG=default_rng())
    num_valid_rotation_roots = count(_valid_rotation_root, tree)
    if num_valid_rotation_roots == 0
        return tree
    end
    rotate_at_root = rand(rng) < 1 / num_valid_rotation_roots
    (parent, root_idx, root) = if rotate_at_root
        (tree, 0, tree)
    else
        _root = rand(
            rng, NodeSampler(; tree, filter=t -> t !== tree && _valid_rotation_root(t))
        )
        _parent, _root_idx = _find_parent(tree, _root)

        (_parent, _root_idx, _root)
    end

    pivot_idx = rand(rng, [i for i in 1:(root.degree) if get_child(root, i).degree > 0])
    pivot = get_child(root, pivot_idx)
    grand_child_idx = rand(rng, 1:(pivot.degree))
    grand_child = get_child(pivot, grand_child_idx)
    set_child!(root, grand_child, pivot_idx)
    set_child!(pivot, root, grand_child_idx)

    if rotate_at_root
        return pivot
    else
        set_child!(parent, pivot, root_idx)
        return tree
    end
end

end
