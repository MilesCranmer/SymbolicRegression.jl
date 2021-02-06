# Evaluate an equation over an array of datapoints
# This one is just for reference. The fused one should be faster.
function unfusedEvalTreeArray(tree::Node, cX::AbstractMatrix{T}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real}
    if tree.degree == 0
        deg0_eval(tree, cX, options)
    elseif tree.degree == 1
        deg1_eval_unfused(tree, cX, Val(tree.op), options)
    else
        deg2_eval_unfused(tree, cX, Val(tree.op), options)
    end
end

# Fuse doublets and triplets of operations for lower memory usage:
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

macro return_on_false(flag, retval)
    :(if !$(esc(flag))
          return ($(esc(retval)), false)
    end)
end

function deg2_eval_unfused(tree::Node, cX::AbstractMatrix{T}, ::Val{op_idx}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real,op_idx}
    n = size(cX, 2)
    (cumulator, complete) = unfusedEvalTreeArray(tree.l, cX, options)
    @return_on_false complete cumulator
    (array2, complete2) = unfusedEvalTreeArray(tree.r, cX, options)
    @return_on_false complete2 cumulator
    op = options.binops[op_idx]
    finished_loop = true
    @inbounds @simd for j=1:n
        x = op(cumulator[j], array2[j])::T
        @break_on_check x finished_loop
        cumulator[j] = x
    end
    return (cumulator, finished_loop)
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
        return (copy(cX[tree.feature, :]), true)
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
            x = op(val, cumulator[j])::T
            @break_on_check x finished_loop
            cumulator[j] = x
        end
    else
        feature = tree.l.feature
        @inbounds @simd for j=1:n
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
            x = op(cumulator[j], val)::T
            @break_on_check x finished_loop
            cumulator[j] = x
        end
    else
        feature = tree.r.feature
        @inbounds @simd for j=1:n
            x = op(cumulator[j], cX[feature, j])::T
            @break_on_check x finished_loop
            cumulator[j] = x
        end
    end
    return (cumulator, finished_loop)
end
