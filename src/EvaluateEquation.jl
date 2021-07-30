using FromFile
using LinearAlgebra
@from "Core.jl" import Node, Options
@from "Utils.jl" import @return_on_false, @return_on_false2
@from "EquationUtils.jl" import countConstants, indexConstants

"""
    evalTreeArray(tree::Node, cX::AbstractMatrix{T}, options::Options)

Evaluate a binary tree (equation) over a given input data matrix. The
options contain all of the operators used. This function fuses doublets
and triplets of operations for lower memory usage.

# Returns

- `(output, complete)::Tuple{AbstractVector{T}, Bool}`: the result,
    which is a 1D array, as well as if the evaluation completed
    successfully (true/false). A `false` complete means an infinity
    or nan was encountered, and a large loss should be assigned
    to the equation.
"""
function evalTreeArray(tree::Node, cX::AbstractMatrix{T}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real}
    if tree.degree == 0
        deg0_eval(tree, cX, options)
    elseif tree.degree == 1
        if tree.l.degree == 2 && tree.l.l.degree == 0 && tree.l.r.degree == 0
            deg1_l2_ll0_lr0_eval(tree, cX, Val(tree.op), Val(tree.l.op), options)
        else
            deg1_eval(tree, cX, Val(tree.op), options)
        end
    else
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

# Break whenever there is a nan or inf. Since so many equations give
# such numbers, it saves a lot of computation to just skip computation,
# and return a large loss!
macro break_on_check(val, flag)
    :(if isnan($(esc(val))) || !isfinite($(esc(val)))
          $(esc(flag)) = false
          break
    end)
end

function deg2_eval(tree::Node, cX::AbstractMatrix{T}, ::Val{op_idx}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real,op_idx}
    n = size(cX, 2)
    (cumulator, complete) = evalTreeArray(tree.l, cX, options)
    @return_on_false complete cumulator
    (array2, complete2) = evalTreeArray(tree.r, cX, options)
    @return_on_false complete2 cumulator
    op = options.binops[op_idx]
    finished_loop = true
    @inbounds @simd for j=1:n
        @break_on_check cumulator[j] finished_loop
        @break_on_check array2[j] finished_loop
        x = op(cumulator[j], array2[j])::T
        @break_on_check x finished_loop
        cumulator[j] = x
    end
    return (cumulator, finished_loop)
end

function deg1_eval(tree::Node, cX::AbstractMatrix{T}, ::Val{op_idx}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real,op_idx}
    n = size(cX, 2)
    (cumulator, complete) = evalTreeArray(tree.l, cX, options)
    @return_on_false complete cumulator
    op = options.unaops[op_idx]
    finished_loop = true
    @inbounds @simd for j=1:n
        @break_on_check cumulator[j] finished_loop
        x = op(cumulator[j])::T
        @break_on_check x finished_loop
        cumulator[j] = x
    end
    return (cumulator, finished_loop)
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
    finished_loop = true
    if tree.l.l.constant && tree.l.r.constant
        val_ll = convert(T, tree.l.l.val)
        val_lr = convert(T, tree.l.r.val)
        x_l = op_l(val_ll, val_lr)::T
        if isnan(x_l) || !isfinite(x_l)
            return (Array{T, 1}(undef, n), false)
        end
        x = op(x_l)::T
        if isnan(x) || !isfinite(x)
            return (Array{T, 1}(undef, n), false)
        end
        return (fill(x, n), true)
    elseif tree.l.l.constant
        val_ll = convert(T, tree.l.l.val)
        feature_lr = tree.l.r.feature
        cumulator = Array{T, 1}(undef, n)
        finished_loop = true
        @inbounds @simd for j=1:n
            x_l = op_l(val_ll, cX[feature_lr, j])::T
            @break_on_check x_l finished_loop
            x = op(x_l)::T
            @break_on_check x finished_loop
            cumulator[j] = x
        end
        return (cumulator, finished_loop)
    elseif tree.l.r.constant
        feature_ll = tree.l.l.feature
        val_lr = convert(T, tree.l.r.val)
        cumulator = Array{T, 1}(undef, n)
        finished_loop = true
        @inbounds @simd for j=1:n
            x_l = op_l(cX[feature_ll, j], val_lr)::T
            @break_on_check x_l finished_loop
            x = op(x_l)::T
            @break_on_check x finished_loop
            cumulator[j] = x
        end
        return (cumulator, finished_loop)
    else
        feature_ll = tree.l.l.feature
        feature_lr = tree.l.r.feature
        cumulator = Array{T, 1}(undef, n)
        finished_loop = true
        @inbounds @simd for j=1:n
            x_l = op_l(cX[feature_ll, j], cX[feature_lr, j])::T
            @break_on_check x_l finished_loop
            x = op(x_l)::T
            @break_on_check x finished_loop
            cumulator[j] = x
        end
        return (cumulator, finished_loop)
    end
    return (cumulator, finished_loop)
end

function deg2_l0_r0_eval(tree::Node, cX::AbstractMatrix{T}, ::Val{op_idx}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real,op_idx}
    n = size(cX, 2)
    op = options.binops[op_idx]
    finished_loop = true
    if tree.l.constant && tree.r.constant
        val_l = convert(T, tree.l.val)
        val_r = convert(T, tree.r.val)
        x = op(val_l, val_r)::T
        if isnan(x) || !isfinite(x)
            return (Array{T, 1}(undef, n), false)
        end
        return (fill(x, n), true)
    elseif tree.l.constant
        cumulator = Array{T, 1}(undef, n)
        val_l = convert(T, tree.l.val)
        feature_r = tree.r.feature
        @inbounds @simd for j=1:n
            x = op(val_l, cX[feature_r, j])::T
            @break_on_check x finished_loop
            cumulator[j] = x
        end
    elseif tree.r.constant
        cumulator = Array{T, 1}(undef, n)
        feature_l = tree.l.feature
        val_r = convert(T, tree.r.val)
        @inbounds @simd for j=1:n
            x = op(cX[feature_l, j], val_r)::T
            @break_on_check x finished_loop
            cumulator[j] = x
        end
    else
        cumulator = Array{T, 1}(undef, n)
        feature_l = tree.l.feature
        feature_r = tree.r.feature
        @inbounds @simd for j=1:n
            x = op(cX[feature_l, j], cX[feature_r, j])::T
            @break_on_check x finished_loop
            cumulator[j] = x
        end
    end
    return (cumulator, finished_loop)
end

function deg2_l0_eval(tree::Node, cX::AbstractMatrix{T}, ::Val{op_idx}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real,op_idx}
    n = size(cX, 2)
    (cumulator, complete) = evalTreeArray(tree.r, cX, options)
    @return_on_false complete cumulator
    op = options.binops[op_idx]
    finished_loop = true
    if tree.l.constant
        val = convert(T, tree.l.val)
        @inbounds @simd for j=1:n
            @break_on_check cumulator[j] finished_loop
            x = op(val, cumulator[j])::T
            @break_on_check x finished_loop
            cumulator[j] = x
        end
    else
        feature = tree.l.feature
        @inbounds @simd for j=1:n
            @break_on_check cumulator[j] finished_loop
            x = op(cX[feature, j], cumulator[j])::T
            @break_on_check x finished_loop
            cumulator[j] = x
        end
    end
    return (cumulator, finished_loop)
end

function deg2_r0_eval(tree::Node, cX::AbstractMatrix{T}, ::Val{op_idx}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real,op_idx}
    n = size(cX, 2)
    (cumulator, complete) = evalTreeArray(tree.l, cX, options)
    @return_on_false complete cumulator
    op = options.binops[op_idx]
    finished_loop = true
    if tree.r.constant
        val = convert(T, tree.r.val)
        @inbounds @simd for j=1:n
            @break_on_check cumulator[j] finished_loop
            x = op(cumulator[j], val)::T
            @break_on_check x finished_loop
            cumulator[j] = x
        end
    else
        feature = tree.r.feature
        @inbounds @simd for j=1:n
            @break_on_check cumulator[j] finished_loop
            x = op(cumulator[j], cX[feature, j])::T
            @break_on_check x finished_loop
            cumulator[j] = x
        end
    end
    return (cumulator, finished_loop)
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
    no_nans = !any(x -> (isnan(x) || !isfinite(x)), out)
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
    no_nans = !any(x -> (isnan(x) || !isfinite(x)), out)
    return (out, no_nans)
end

################################
### Forward derivative of a graph
################################

function evaldiffTreeArray(tree::Node, cX::AbstractMatrix{T}, options::Options, direction::Int)::Tuple{AbstractVector{T}, AbstractVector{T}, Bool} where {T<:Real}
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
    (cumulator, dcumulator, complete) = evaldiffTreeArray(tree.l, cX, options, direction)
    @return_on_false2 complete cumulator dcumulator

    op = options.unaops[op_idx]
    diff_op = options.diff_unaops[op_idx]

    finished_loop = true
    @inbounds @simd for j=1:n
        @break_on_check cumulator[j] finished_loop
        @break_on_check dcumulator[j] finished_loop

        x = op(cumulator[j])::T
        dx = diff_op(cumulator[j])::T * dcumulator[j]

        @break_on_check x finished_loop
        @break_on_check dx finished_loop

        cumulator[j] = x
        dcumulator[j] = dx
    end
    return (cumulator, dcumulator, finished_loop)
end

function diff_deg2_eval(tree::Node, cX::AbstractMatrix{T}, ::Val{op_idx}, options::Options, direction::Int)::Tuple{AbstractVector{T}, AbstractVector{T}, Bool} where {T<:Real,op_idx}
    n = size(cX, 2)
    (cumulator, dcumulator, complete) = evaldiffTreeArray(tree.l, cX, options, direction)

    @return_on_false2 complete cumulator dcumulator

    (array2, dcumulator2, complete2) = evaldiffTreeArray(tree.r, cX, options, direction)
    @return_on_false2 complete2 array2 dcumulator2

    op = options.binops[op_idx]
    diff_op = options.diff_binops[op_idx]

    finished_loop = true
    @inbounds @simd for j=1:n
        @break_on_check cumulator[j] finished_loop
        @break_on_check array2[j] finished_loop

        x = op(cumulator[j], array2[j])

        @break_on_check x finished_loop

        dx = dot(
                 diff_op(cumulator[j], array2[j]),
                        [dcumulator[j], dcumulator2[j]]
                )

        @break_on_check dx finished_loop

        cumulator[j] = x
        dcumulator[j] = dx
    end
    return (cumulator, dcumulator, finished_loop)
end

################################
### Backward derivative of a graph
################################
function evalgradTreeArray(tree::Node, cX::AbstractMatrix{T}, options::Options; variable::Bool=false)::Tuple{AbstractVector{T},AbstractMatrix{T}, Bool} where {T<:Real}
    return evalgradTreeArray(tree, cX, options, Array{T}(undef, 0, 2); variable=variable)
end


function evalgradTreeArray(tree::Node, cX::AbstractMatrix{T}, options::Options, gradient_list::AbstractMatrix{T}; variable::Bool=false)::Tuple{AbstractVector{T},AbstractMatrix{T}, Bool} where {T<:Real}
    if isempty(gradient_list)
        if variable
            n_variables = size(cX, 1)
            gradient_list = zeros(n_variables, size(cX, 2))
        else
            n_constants = countConstants(tree)
            indexConstants(tree, 0)
            gradient_list = zeros(n_constants, size(cX, 2))
        end
    end
    if tree.degree == 0
        grad_deg0_eval(tree, cX, options, gradient_list; variable=variable)
    elseif tree.degree == 1
        grad_deg1_eval(tree, cX, Val(tree.op), options, gradient_list; variable=variable)
    else
        grad_deg2_eval(tree, cX, Val(tree.op), options, gradient_list; variable=variable)
    end
end

function grad_deg0_eval(tree::Node, cX::AbstractMatrix{T}, options::Options, gradient_list::AbstractMatrix{T}; variable::Bool=false)::Tuple{AbstractVector{T},AbstractMatrix{T}, Bool} where {T<:Real}
    n = size(cX, 2)
    const_part = deg0_eval(tree, cX, options)[1]
    if variable
        if tree.constant
            derivative_part = zeros(size(gradient_list))
            return (const_part, derivative_part, true)
        else
            index = tree.feature
            derivative_part = copy(gradient_list)
            derivative_part[index, :] .= ones(size(gradient_list[index, :]))
            return (const_part, derivative_part, true)
        end
    else
        if tree.constant
            constant_index = tree.constant_index
            derivative_part = copy(gradient_list)
            derivative_part[constant_index, :] .= ones(size(gradient_list[constant_index, :]))
            return (const_part, derivative_part, true)
        else
            derivative_part = zeros(size(gradient_list))
            return (const_part, derivative_part, true)
        end
    end
end

function grad_deg1_eval(tree::Node, cX::AbstractMatrix{T}, ::Val{op_idx}, options::Options, gradient_list::AbstractMatrix{T}; variable::Bool=false)::Tuple{AbstractVector{T},AbstractMatrix{T}, Bool} where {T<:Real,op_idx}
    n = size(cX, 2)
    (cumulator, dcumulator, complete) = evalgradTreeArray(tree.l, cX, options, gradient_list; variable=variable)
    @return_on_false complete cumulator

    op = options.unaops[op_idx]
    diff_op = options.diff_unaops[op_idx]

    finished_loop = true
    @inbounds @simd for j=1:n
        x = op(cumulator[j])::T
        dx = diff_op(cumulator[j])::T*dcumulator[j]

        cumulator[j] = x 
        @inbounds @simd for k=1:size(dcumulator, 1)
            dcumulator[k, j] = dx
        end
    end
    return (cumulator, dcumulator, finished_loop)
end

function grad_deg2_eval(tree::Node, cX::AbstractMatrix{T}, ::Val{op_idx}, options::Options, gradient_list::AbstractMatrix{T}; variable::Bool=false)::Tuple{AbstractVector{T},AbstractMatrix{T}, Bool} where {T<:Real,op_idx}
    n = size(cX, 2)

    derivative_part = copy(gradient_list)
    (cumulator1, dcumulator1, complete) = evalgradTreeArray(tree.l, cX, options, gradient_list; variable=variable)
    @return_on_false complete cumulator1
    (cumulator2, dcumulator2, complete2) = evalgradTreeArray(tree.r, cX, options, gradient_list; variable=variable)
    @return_on_false complete2 cumulator2

    op = options.binops[op_idx]
    diff_op = options.diff_binops[op_idx]

    finished_loop = true
    @inbounds @simd for j=1:n
        x = op(cumulator1[j], cumulator2[j])
        dx = diff_op(cumulator1[j], cumulator2[j])

        cumulator1[j] = x
        @inbounds @simd for k=1:size(dcumulator1, 1)
            derivative_part[k, j] = dx[1]*dcumulator1[k, j]+dx[2]*dcumulator2[k, j]
        end
    end
    return (cumulator1, derivative_part, finished_loop)
end


