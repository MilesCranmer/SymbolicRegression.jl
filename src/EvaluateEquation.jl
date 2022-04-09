using FromFile
using LinearAlgebra
@from "Core.jl" import Node, Options
@from "Utils.jl" import @return_on_false, @return_on_false2
@from "EquationUtils.jl" import countConstants, indexConstants, NodeIndex


macro return_on_check(val, T, n)
    # This will generate the following code:
    # if !isfinite(val)
    #     return (Array{T, 1}(undef, n), false)
    # end

    :(if !isfinite($(esc(val)))
        return (Array{$(esc(T)), 1}(undef, $(esc(n))), false)
    end)
end

# Fastest way to check for NaN in an array.
# (due to optimizations in sum())
is_bad_array(array) = !isfinite(sum(array))

macro return_on_nonfinite_array(array, T, n)
    :(if is_bad_array($(esc(array)))
        return (Array{$(esc(T)), 1}(undef, $(esc(n))), false)
    end)
end


"""
    evalTreeArray(tree::Node, cX::AbstractMatrix{T}, options::Options)

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
function evalTreeArray(tree::Node, cX::AbstractMatrix{T}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real}
    n = size(cX, 2)
    result, finished = _evalTreeArray(tree, cX, options)
    @return_on_false finished result
    @return_on_nonfinite_array result T n
    return result, finished
end

function _evalTreeArray(tree::Node, cX::AbstractMatrix{T}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real}
    if tree.degree == 0
        deg0_eval(tree, cX, options)
    elseif tree.degree == 1
        # TODO: We could all do Val(tree.l.degree) here, instead of having
        # different kernels for const vs data.

        # We fuse (and compile) the following:
        #  - op(op2(x, y)), where x, y, z are constants or variables.
        #  - op(op2(x)), where x is a constant or variable.
        #  - op(x), for any x.
        if tree.l.degree == 2 && tree.l.l.degree == 0 && tree.l.r.degree == 0
            deg1_l2_ll0_lr0_eval(tree, cX, Val(tree.op), Val(tree.l.op), options)
        elseif tree.l.degree == 1 && tree.l.l.degree == 0
            deg1_l1_ll0_eval(tree, cX, Val(tree.op), Val(tree.l.op), options)
        else
            deg1_eval(tree, cX, Val(tree.op), options)
        end
    else
        # We fuse (and compile) the following:
        #  - op(x, y), where x, y are constants or variables.
        #  - op(x, y), where x is a constant or variable but y is not.
        #  - op(x, y), where y is a constant or variable but x is not.
        #  - op(x, y), for any x or y
        # TODO - add op(op2(x, y), z) and op(x, op2(y, z))
        if tree.l.degree == 0 && tree.r.degree == 0
            deg2_l0_r0_eval(tree, cX, Val(tree.op), options)
        elseif tree.l.degree == 0
            deg2_l0_eval(tree, cX, Val(tree.op), options)
        elseif tree.r.degree == 0
            deg2_r0_eval(tree, cX, Val(tree.op), options)
        else
            deg2_eval(tree, cX, Val(tree.op), options)
        end
    end
end


function deg2_eval(tree::Node, cX::AbstractMatrix{T}, ::Val{op_idx}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real,op_idx}
    n = size(cX, 2)
    (cumulator, complete) = _evalTreeArray(tree.l, cX, options)
    @return_on_false complete cumulator
    @return_on_nonfinite_array cumulator T n
    (array2, complete2) = _evalTreeArray(tree.r, cX, options)
    @return_on_false complete2 cumulator
    @return_on_nonfinite_array array2 T n
    op = options.binops[op_idx]

    # We check inputs (and intermediates), not outputs.
    @inbounds @simd for j=1:n
        x = op(cumulator[j], array2[j])::T
        cumulator[j] = x
    end
    # return (cumulator, finished_loop) #
    return (cumulator, true)
end

function deg1_eval(tree::Node, cX::AbstractMatrix{T}, ::Val{op_idx}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real,op_idx}
    n = size(cX, 2)
    (cumulator, complete) = _evalTreeArray(tree.l, cX, options)
    @return_on_false complete cumulator
    @return_on_nonfinite_array cumulator T n
    op = options.unaops[op_idx]
    @inbounds @simd for j=1:n
        x = op(cumulator[j])::T
        cumulator[j] = x
    end
    return (cumulator, true) #
end

function deg0_eval(tree::Node, cX::AbstractMatrix{T}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real}
    n = size(cX, 2)
    if tree.constant
        return (fill(convert(T, tree.val), n), true)
    else
        return (cX[tree.feature, :], true)
    end
end

function deg1_l2_ll0_lr0_eval(tree::Node, cX::AbstractMatrix{T}, ::Val{op_idx}, ::Val{op_l_idx}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real,op_idx,op_l_idx}
    n = size(cX, 2)
    op = options.unaops[op_idx]
    op_l = options.binops[op_l_idx]
    if tree.l.l.constant && tree.l.r.constant
        val_ll = convert(T, tree.l.l.val)
        val_lr = convert(T, tree.l.r.val)
        @return_on_check val_ll T n
        @return_on_check val_lr T n
        x_l = op_l(val_ll, val_lr)::T
        @return_on_check x_l T n
        x = op(x_l)::T
        @return_on_check x T n
        return (fill(x, n), true)
    elseif tree.l.l.constant
        val_ll = convert(T, tree.l.l.val)
        @return_on_check val_ll T n
        feature_lr = tree.l.r.feature
        cumulator = Array{T, 1}(undef, n)
        @inbounds @simd for j=1:n
            x_l = op_l(val_ll, cX[feature_lr, j])::T
            x = isfinite(x_l) ? op(x_l)::T : T(Inf) # These will get discovered by _evalTreeArray at end.
            cumulator[j] = x
        end
        return (cumulator, true)
    elseif tree.l.r.constant
        feature_ll = tree.l.l.feature
        val_lr = convert(T, tree.l.r.val)
        @return_on_check val_lr T n
        cumulator = Array{T, 1}(undef, n)
        @inbounds @simd for j=1:n
            x_l = op_l(cX[feature_ll, j], val_lr)::T
            x = isfinite(x_l) ? op(x_l)::T : T(Inf)
            cumulator[j] = x
        end
        return (cumulator, true)
    else
        feature_ll = tree.l.l.feature
        feature_lr = tree.l.r.feature
        cumulator = Array{T, 1}(undef, n)
        @inbounds @simd for j=1:n
            x_l = op_l(cX[feature_ll, j], cX[feature_lr, j])::T
            x = isfinite(x_l) ? op(x_l)::T : T(Inf)
            cumulator[j] = x
        end
        return (cumulator, true)
    end
end


# op(op2(x)) for x variable or constant
function deg1_l1_ll0_eval(tree::Node, cX::AbstractMatrix{T}, ::Val{op_idx}, ::Val{op_l_idx}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real,op_idx,op_l_idx}
    n = size(cX, 2)
    op = options.unaops[op_idx]
    op_l = options.unaops[op_l_idx]
    if tree.l.l.constant
        val_ll = convert(T, tree.l.l.val)
        @return_on_check val_ll T n
        x_l = op_l(val_ll)::T
        @return_on_check x_l T n
        x = op(x_l)::T
        @return_on_check x T n
        return (fill(x, n), true)
    else
        feature_ll = tree.l.l.feature
        cumulator = Array{T, 1}(undef, n)
        @inbounds @simd for j=1:n
            x_l = op_l(cX[feature_ll, j])::T
            x = isfinite(x_l) ? op(x_l)::T : T(Inf)
            cumulator[j] = x
        end
        return (cumulator, true)
    end
end

function deg2_l0_r0_eval(tree::Node, cX::AbstractMatrix{T}, ::Val{op_idx}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real,op_idx}
    n = size(cX, 2)
    op = options.binops[op_idx]
    if tree.l.constant && tree.r.constant
        val_l = convert(T, tree.l.val)
        @return_on_check val_l T n
        val_r = convert(T, tree.r.val)
        @return_on_check val_r T n
        x = op(val_l, val_r)::T
        @return_on_check x T n
        return (fill(x, n), true)
    elseif tree.l.constant
        cumulator = Array{T, 1}(undef, n)
        val_l = convert(T, tree.l.val)
        @return_on_check val_l T n
        feature_r = tree.r.feature
        @inbounds @simd for j=1:n
            x = op(val_l, cX[feature_r, j])::T
            cumulator[j] = x
        end
    elseif tree.r.constant
        cumulator = Array{T, 1}(undef, n)
        feature_l = tree.l.feature
        val_r = convert(T, tree.r.val)
        @return_on_check val_r T n
        @inbounds @simd for j=1:n
            x = op(cX[feature_l, j], val_r)::T
            cumulator[j] = x
        end
    else
        cumulator = Array{T, 1}(undef, n)
        feature_l = tree.l.feature
        feature_r = tree.r.feature
        @inbounds @simd for j=1:n
            x = op(cX[feature_l, j], cX[feature_r, j])::T
            cumulator[j] = x
        end
    end
    return (cumulator, true)
end

function deg2_l0_eval(tree::Node, cX::AbstractMatrix{T}, ::Val{op_idx}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real,op_idx}
    n = size(cX, 2)
    (cumulator, complete) = _evalTreeArray(tree.r, cX, options)
    @return_on_false complete cumulator
    @return_on_nonfinite_array cumulator T n
    op = options.binops[op_idx]
    if tree.l.constant
        val = convert(T, tree.l.val)
        @return_on_check val T n
        @inbounds @simd for j=1:n
            x = op(val, cumulator[j])::T
            cumulator[j] = x
        end
    else
        feature = tree.l.feature
        @inbounds @simd for j=1:n
            x = op(cX[feature, j], cumulator[j])::T
            cumulator[j] = x
        end
    end
    return (cumulator, true)
end

function deg2_r0_eval(tree::Node, cX::AbstractMatrix{T}, ::Val{op_idx}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real,op_idx}
    n = size(cX, 2)
    (cumulator, complete) = _evalTreeArray(tree.l, cX, options)
    @return_on_false complete cumulator
    @return_on_nonfinite_array cumulator T n
    op = options.binops[op_idx]
    if tree.r.constant
        val = convert(T, tree.r.val)
        @return_on_check val T n
        @inbounds @simd for j=1:n
            x = op(cumulator[j], val)::T
            cumulator[j] = x
        end
    else
        feature = tree.r.feature
        @inbounds @simd for j=1:n
            x = op(cumulator[j], cX[feature, j])::T
            cumulator[j] = x
        end
    end
    return (cumulator, true)
end


# Evaluate an equation over an array of datapoints
# This one is just for reference. The fused one should be faster.
function differentiableEvalTreeArray(tree::Node, cX::AbstractMatrix{T}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real}
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

function deg1_diff_eval(tree::Node, cX::AbstractMatrix{T}, ::Val{op_idx}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real,op_idx}
    n = size(cX, 2)
    (left, complete) = differentiableEvalTreeArray(tree.l, cX, options)
    @return_on_false complete left
    op = options.unaops[op_idx]
    out = op.(left)
    no_nans = !any(x -> (!isfinite(x)), out)
    return (out, no_nans)
end

function deg2_diff_eval(tree::Node, cX::AbstractMatrix{T}, ::Val{op_idx}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real,op_idx}
    n = size(cX, 2)
    (left, complete) = differentiableEvalTreeArray(tree.l, cX, options)
    @return_on_false complete left
    (right, complete2) = differentiableEvalTreeArray(tree.r, cX, options)
    @return_on_false complete2 left
    op = options.binops[op_idx]
    out = op.(left, right)
    no_nans = !any(x -> (!isfinite(x)), out)
    return (out, no_nans)
end

"""
    evalDiffTreeArray(tree::Node, cX::AbstractMatrix{T}, options::Options, direction::Int)

Compute the forward derivative of an expression, using a similar
structure and optimization to evalTreeArray. `direction` is the index of a particular
constant in the expression. (See `indexConstants` for how order is calculated.)

# Returns

- `(evaluation, derivative, complete)::Tuple{AbstractVector{T}, AbstractVector{T}, Bool}`: the normal evaluation,
    the derivative, and whether the evaluation completed as normal (or encountered a nan or inf).
"""
function evalDiffTreeArray(tree::Node, cX::AbstractMatrix{T}, options::Options, direction::Int)::Tuple{AbstractVector{T}, AbstractVector{T}, Bool} where {T<:Real}
    evaluation, derivative, complete = _evalTreeArray(tree, cX, options)
    @return_on_false2 complete evaluation derivative
    return evaluation, derivative, !(is_bad_array(evaluation) || is_bad_array(derivative))
end

function _evalDiffTreeArray(tree::Node, cX::AbstractMatrix{T}, options::Options, direction::Int)::Tuple{AbstractVector{T}, AbstractVector{T}, Bool} where {T<:Real}
    if tree.degree == 0
        diff_deg0_eval(tree, cX, options, direction)
    elseif tree.degree == 1
        diff_deg1_eval(tree, cX, Val(tree.op), options, direction)
    else
        diff_deg2_eval(tree, cX, Val(tree.op), options, direction)
    end
end

function diff_deg0_eval(tree::Node, cX::AbstractMatrix{T}, options::Options, direction::Int)::Tuple{AbstractVector{T}, AbstractVector{T}, Bool} where {T<:Real}
    n = size(cX, 2)
    const_part = deg0_eval(tree, cX, options)[1]
    derivative_part = (tree.feature == direction) ? ones(T, n) : zeros(T, n)
    return (const_part, derivative_part, true)
end

function diff_deg1_eval(tree::Node, cX::AbstractMatrix{T}, ::Val{op_idx}, options::Options, direction::Int)::Tuple{AbstractVector{T}, AbstractVector{T}, Bool} where {T<:Real,op_idx}
    n = size(cX, 2)
    (cumulator, dcumulator, complete) = evalDiffTreeArray(tree.l, cX, options, direction)
    @return_on_false2 complete cumulator dcumulator

    op = options.unaops[op_idx]
    diff_op = options.diff_unaops[op_idx]

    @inbounds @simd for j=1:n
        x = op(cumulator[j])::T
        dx = diff_op(cumulator[j])::T * dcumulator[j]

        cumulator[j] = x
        dcumulator[j] = dx
    end
    return (cumulator, dcumulator, true)
end

function diff_deg2_eval(tree::Node, cX::AbstractMatrix{T}, ::Val{op_idx}, options::Options, direction::Int)::Tuple{AbstractVector{T}, AbstractVector{T}, Bool} where {T<:Real,op_idx}
    n = size(cX, 2)
    (cumulator, dcumulator, complete) = evalDiffTreeArray(tree.l, cX, options, direction)
    @return_on_false2 complete cumulator dcumulator
    (array2, dcumulator2, complete2) = evalDiffTreeArray(tree.r, cX, options, direction)
    @return_on_false2 complete2 array2 dcumulator2

    op = options.binops[op_idx]
    diff_op = options.diff_binops[op_idx]

    @inbounds @simd for j=1:n
        x = op(cumulator[j], array2[j])

        dx = dot(
                 diff_op(cumulator[j], array2[j]),
                        [dcumulator[j], dcumulator2[j]]
                )

        cumulator[j] = x
        dcumulator[j] = dx
    end
    return (cumulator, dcumulator, true)
end





"""
    evalGradTreeArray(tree::Node, cX::AbstractMatrix{T}, options::Options; variable::Bool=false)

Compute the backward gradients of an expression, using a similar
structure and optimization to evalTreeArray. `variable` specifies whether
we should take derivatives with respect to features (i.e., cX), or with respect
to every constant in the expression.

# Returns

- `(evaluation, gradient, complete)::Tuple{AbstractVector{T}, AbstractMatrix{T}, Bool}`: the normal evaluation,
    the gradient, and whether the evaluation completed as normal (or encountered a nan or inf).
"""
function evalGradTreeArray(tree::Node, cX::AbstractMatrix{T}, options::Options; variable::Bool=false)::Tuple{AbstractVector{T},AbstractMatrix{T}, Bool} where {T<:Real}
    if variable
        n_variables = size(cX, 1)
        gradient_list = zeros(T, n_variables, size(cX, 2))
    else
        n_constants = countConstants(tree)
        gradient_list = zeros(T, n_constants, size(cX, 2))
    end
    index_tree = indexConstants(tree, 0)
    return evalGradTreeArray(tree, index_tree, cX, options, gradient_list; variable=variable)
end


function evalGradTreeArray(tree::Node, index_tree::NodeIndex, cX::AbstractMatrix{T}, options::Options, gradient_list::AbstractMatrix{T}; variable::Bool=false)::Tuple{AbstractVector{T},AbstractMatrix{T}, Bool} where {T<:Real}
    if tree.degree == 0
        grad_deg0_eval(tree, index_tree, cX, options, gradient_list; variable=variable)
    elseif tree.degree == 1
        grad_deg1_eval(tree, index_tree, cX, Val(tree.op), options, gradient_list; variable=variable)
    else
        grad_deg2_eval(tree, index_tree, cX, Val(tree.op), options, gradient_list; variable=variable)
    end
end

function grad_deg0_eval(tree::Node, index_tree::NodeIndex, cX::AbstractMatrix{T}, options::Options, gradient_list::AbstractMatrix{T}; variable::Bool=false)::Tuple{AbstractVector{T},AbstractMatrix{T}, Bool} where {T<:Real}
    n = size(cX, 2)
    const_part = deg0_eval(tree, cX, options)[1]

    if variable == tree.constant
        return (const_part, zeros(T, size(gradient_list)), true)
    end

    index = variable ? tree.feature : index_tree.constant_index
    # derivative_part = copy(gradient_list) # Why is this copied? Shouldn't it be zero?
    derivative_part = zeros(T, size(gradient_list))
    derivative_part[index, :] .= T(1)
    return (const_part, derivative_part, true)
end

function grad_deg1_eval(tree::Node, index_tree::NodeIndex, cX::AbstractMatrix{T}, ::Val{op_idx}, options::Options, gradient_list::AbstractMatrix{T}; variable::Bool=false)::Tuple{AbstractVector{T},AbstractMatrix{T}, Bool} where {T<:Real,op_idx}
    n = size(cX, 2)
    (cumulator, dcumulator, complete) = evalGradTreeArray(tree.l, index_tree.l, cX, options, gradient_list; variable=variable)
    @return_on_false2 complete cumulator dcumulator

    op = options.unaops[op_idx]
    diff_op = options.diff_unaops[op_idx]

    @inbounds @simd for j=1:n
        # TODO(miles): Do these breaks slow down the computation?
        @skip_on_bad_value cumulator[j] cumulator[j] begin
        x = op(cumulator[j])::T
        @skip_on_bad_value x cumulator[j] begin
        dx = diff_op(cumulator[j])
        @skip_on_bad_value dx[1] cumulator[j] begin

        cumulator[j] = x 
        @inbounds @simd for k=1:size(dcumulator, 1)
            @skip_on_bad_value dcumulator[k, j] dcumulator[k, j] begin
            dcumulator[k, j] = dx * dcumulator[k, j]
            end
        end
        end; end; end
    end
    return (cumulator, dcumulator, !any(isinf, cumulator) && !any(isinf, dcumulator))
end

function grad_deg2_eval(tree::Node, index_tree::NodeIndex, cX::AbstractMatrix{T}, ::Val{op_idx}, options::Options, gradient_list::AbstractMatrix{T}; variable::Bool=false)::Tuple{AbstractVector{T},AbstractMatrix{T}, Bool} where {T<:Real,op_idx}
    n = size(cX, 2)

    derivative_part = copy(gradient_list)
    (cumulator1, dcumulator1, complete) = evalGradTreeArray(tree.l, index_tree.l, cX, options, gradient_list; variable=variable)
    @return_on_false2 complete cumulator1 dcumulator1
    (cumulator2, dcumulator2, complete2) = evalGradTreeArray(tree.r, index_tree.r, cX, options, gradient_list; variable=variable)
    @return_on_false2 complete2 cumulator1 dcumulator1

    op = options.binops[op_idx]
    diff_op = options.diff_binops[op_idx]

    @inbounds @simd for j=1:n
        @skip_on_bad_value cumulator1[j] cumulator1[j] begin
        @skip_on_bad_value cumulator2[j] cumulator1[j] begin
        x = op(cumulator1[j], cumulator2[j])
        @skip_on_bad_value x cumulator1[j] begin
        dx = diff_op(cumulator1[j], cumulator2[j])
        @skip_on_bad_value dx[1] cumulator1[j] begin
        @skip_on_bad_value dx[2] cumulator1[j] begin

        cumulator1[j] = x
        @inbounds @simd for k=1:size(dcumulator1, 1)
            @skip_on_bad_value dcumulator1[k, j] dcumulator1[k, j] begin
            @skip_on_bad_value dcumulator2[k, j] dcumulator1[k, j] begin
            derivative_part[k, j] = dx[1]*dcumulator1[k, j]+dx[2]*dcumulator2[k, j]
            end; end
        end
        end; end; end; end; end
    end
    return (cumulator1, derivative_part, !any(isinf, cumulator1) && !any(isinf, dcumulator1))
end


