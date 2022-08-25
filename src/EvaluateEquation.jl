module EvaluateEquationModule

import ..CoreModule: Node, Options, CONST_TYPE
import ..EquationUtilsModule: count_nodes
import ..UtilsModule: @return_on_false, is_bad_array

macro return_on_check(val, T, n)
    # This will generate the following code:
    # if !isfinite(val)
    #     return (Array{T, 1}(undef, n), false)
    # end

    :(
        if !isfinite($(esc(val)))
            return (Array{$(esc(T)),1}(undef, $(esc(n))), false)
        end
    )
end

macro return_on_nonfinite_array(array, T, n)
    :(
        if is_bad_array($(esc(array)))
            return (Array{$(esc(T)),1}(undef, $(esc(n))), false)
        end
    )
end

"""
    eval_tree_array(tree::Node, cX::AbstractMatrix{T}, options::Options)

Evaluate a binary tree (equation) over a given input data matrix. The
options contain all of the operators used. This function fuses doublets
and triplets of operations for lower memory usage.

This function can be represented by the following pseudocode:

```
function eval(current_node)
    if current_node is leaf
        return current_node.value
    elif current_node is degree 1
        return current_node.operator(eval(current_node.left_child))
    else
        return current_node.operator(eval(current_node.left_child), eval(current_node.right_child))
```
The bulk of the code is for optimizations and pre-emptive NaN/Inf checks,
which speed up evaluation significantly.

# Returns

- `(output, complete)::Tuple{AbstractVector{T}, Bool}`: the result,
    which is a 1D array, as well as if the evaluation completed
    successfully (true/false). A `false` complete means an infinity
    or nan was encountered, and a large loss should be assigned
    to the equation.
"""
function eval_tree_array(
    tree::Node, cX::AbstractMatrix{T}, options::Options
)::Tuple{AbstractVector{T},Bool} where {T<:Real}
    n = size(cX, 2)
    result, finished = _eval_tree_array(tree, cX, options)
    @return_on_false finished result
    @return_on_nonfinite_array result T n
    return result, finished
end

# Childless node whose type describes the operation.
struct TypedNode{v_degree,v_constant,v_feature,v_op}
    degree::v_degree
    constant::v_constant  # false if variable
    val::CONST_TYPE  # If is a constant, this stores the actual value
    feature::v_feature  # If is a variable (e.g., x in cos(x)), this stores the feature index.
    op::v_op  # If operator, this is the index of the operator in options.binary_operators, or options.unary_operators
end

function TypedNode(degree::v_degree, constant::v_constant, val::CONST_TYPE, feature::v_feature, op::v_op)
    return TypedNode{v_degree, v_constant, v_feature, v_op}(degree, constant, val, feature, op)
end

function TypedNode(tree::Node)
    degree = Val(tree.degree)
    constant = Val(tree.constant)
    val = tree.val
    feature = (tree.degree > 0) ? Val(tree.feature) : Val(-1)
    op = (tree.degree > 0) ? Val(tree.op) : Val(-1)
    return TypedNode(degree, constant, val, feature, op)
end

function stack_typed_nodes(tree::Node)
    cur_node = TypedNode(tree)
    if tree.degree == 0
        return (cur_node,)
    elseif tree.degree == 1
        return (cur_node, stack_typed_nodes(tree.left_child)...)
    else
        return (cur_node, stack_typed_nodes(tree.left_child)..., stack_typed_nodes(tree.right_child)...)
    end
end


function _eval_tree_array(
    tree::Node, cX::AbstractMatrix{T}, options::Options
)::Tuple{AbstractVector{T},Bool} where {T<:Real}
    if tree.degree == 0
        deg0_eval(tree, cX, options)
    end
    tree_size = count_nodes(tree) 
    if tree_size == 5
        # Use fused version.
        typed_nodes = stack_typed_nodes(tree)
    end

    if tree.degree == 1
        deg1_eval(tree, cX, Val(tree.op), options)
    else
        deg2_eval(tree, cX, Val(tree.op), options)
    end
end

function typed_eval_tree_array(
    typed_nodes::v_typed_nodes, cX::AbstractMatrix{T}, options::Options
)::Tuple{AbstractVector{T},Bool} where {v_typed_nodes,T<:Real}
    # The tree structure is now a compile-time constant.
    vec_nodes = v_typed_nodes.types
end
    







function deg2_eval(
    tree::Node, cX::AbstractMatrix{T}, ::Val{op_idx}, options::Options
)::Tuple{AbstractVector{T},Bool} where {T<:Real,op_idx}
    n = size(cX, 2)
    (cumulator, complete) = _eval_tree_array(tree.l, cX, options)
    @return_on_false complete cumulator
    @return_on_nonfinite_array cumulator T n
    (array2, complete2) = _eval_tree_array(tree.r, cX, options)
    @return_on_false complete2 cumulator
    @return_on_nonfinite_array array2 T n
    op = options.binops[op_idx]

    # We check inputs (and intermediates), not outputs.
    @inbounds @simd for j in 1:n
        x = op(cumulator[j], array2[j])::T
        cumulator[j] = x
    end
    # return (cumulator, finished_loop) #
    return (cumulator, true)
end

function deg1_eval(
    tree::Node, cX::AbstractMatrix{T}, ::Val{op_idx}, options::Options
)::Tuple{AbstractVector{T},Bool} where {T<:Real,op_idx}
    n = size(cX, 2)
    (cumulator, complete) = _eval_tree_array(tree.l, cX, options)
    @return_on_false complete cumulator
    @return_on_nonfinite_array cumulator T n
    op = options.unaops[op_idx]
    @inbounds @simd for j in 1:n
        x = op(cumulator[j])::T
        cumulator[j] = x
    end
    return (cumulator, true) #
end

function deg0_eval(
    tree::Node, cX::AbstractMatrix{T}, options::Options
)::Tuple{AbstractVector{T},Bool} where {T<:Real}
    n = size(cX, 2)
    if tree.constant
        return (fill(convert(T, tree.val), n), true)
    else
        return (cX[tree.feature, :], true)
    end
end


# Evaluate an equation over an array of datapoints
# This one is just for reference. The fused one should be faster.
function differentiable_eval_tree_array(
    tree::Node, cX::AbstractMatrix{T}, options::Options
)::Tuple{AbstractVector{T},Bool} where {T<:Real}
    n = size(cX, 2)
    if tree.degree == 0
        if tree.constant
            return (ones(T, n) .* tree.val, true)
        else
            return (cX[tree.feature, :], true)
        end
    elseif tree.degree == 1
        return deg1_diff_eval(tree, cX, Val(tree.op), options)
    else
        return deg2_diff_eval(tree, cX, Val(tree.op), options)
    end
end

function deg1_diff_eval(
    tree::Node, cX::AbstractMatrix{T}, ::Val{op_idx}, options::Options
)::Tuple{AbstractVector{T},Bool} where {T<:Real,op_idx}
    (left, complete) = differentiable_eval_tree_array(tree.l, cX, options)
    @return_on_false complete left
    op = options.unaops[op_idx]
    out = op.(left)
    no_nans = !any(x -> (!isfinite(x)), out)
    return (out, no_nans)
end

function deg2_diff_eval(
    tree::Node, cX::AbstractMatrix{T}, ::Val{op_idx}, options::Options
)::Tuple{AbstractVector{T},Bool} where {T<:Real,op_idx}
    (left, complete) = differentiable_eval_tree_array(tree.l, cX, options)
    @return_on_false complete left
    (right, complete2) = differentiable_eval_tree_array(tree.r, cX, options)
    @return_on_false complete2 left
    op = options.binops[op_idx]
    out = op.(left, right)
    no_nans = !any(x -> (!isfinite(x)), out)
    return (out, no_nans)
end

end
