# Evaluate an equation over an array of datapoints
# This one is just for reference. The fused one should be faster.
function unfusedEvalTreeArray(tree::Node, cX::AbstractMatrix{T}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real}
    if tree.degree == 0
        deg0_eval(tree, cX, options)
    elseif tree.degree == 1
        deg1_eval(tree, cX, Val(tree.op), options)
    else
        deg2_eval(tree, cX, Val(tree.op), options)
    end
end

# Fuse doublets and triplets of operations for speed:
function evalTreeArray(tree::Node, cX::AbstractMatrix{T}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real}
    if tree.degree == 0
        deg0_eval(tree, cX, options)
    elseif tree.degree == 1
        if tree.l.degree == 2
            deg1_l2_eval(tree, cX, Val(tree.op), Val(tree.l.op), options)
        elseif tree.l.degree == 1
            deg1_l1_eval(tree, cX, Val(tree.op), Val(tree.l.op), options)
        else
            deg1_eval(tree, cX, Val(tree.op), options)
        end
    else
        if tree.l.degree == 1 && tree.r.degree == 1
            deg2_l1_r1_eval(tree, cX, Val(tree.op), Val(tree.l.op), Val(tree.r.op), options)
        elseif tree.l.degree == 1
            deg2_l1_eval(tree, cX, Val(tree.op), Val(tree.l.op), options)
        elseif tree.r.degree == 1
            deg2_r1_eval(tree, cX, Val(tree.op), Val(tree.r.op), options)
        else
            deg2_eval(tree, cX, Val(tree.op), options)
        end
    end
end

macro break_on_check(val, flag, type)
    :(if ($(esc(val)) != $(esc(val)))::Bool || ($(esc(val)) - $(esc(val)) != convert($(esc(type)), 0))::Bool
          $(esc(flag)) = false
          break
    end)
end

macro return_on_false(flag, n, type)
    :(if !$(esc(flag))
        return (Array{$(esc(type)), 1}(undef, $(esc(n))), false)
    end)
end

function deg2_eval(tree::Node, cX::AbstractMatrix{T}, ::Val{op_idx}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real,op_idx}
    n = size(cX, 2)
    (cumulator, complete) = evalTreeArray(tree.l, cX, options)
    @return_on_false complete n T
    (array2, complete2) = evalTreeArray(tree.r, cX, options)
    @return_on_false complete2 n T
    op = options.fast_binops[op_idx]
    finished_loop = true
    @inbounds @simd for j=1:n
        x = op(cumulator[j], array2[j])
        @break_on_check x finished_loop T
        cumulator[j] = x
    end
    @return_on_false finished_loop n T
    return (cumulator, true)
end

function deg2_l1_r1_eval(tree::Node, cX::AbstractMatrix{T}, ::Val{op_idx}, ::Val{op_l_idx}, ::Val{op_r_idx}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real,op_idx,op_l_idx,op_r_idx}
    n = size(cX, 2)
    (cumulator, complete) = evalTreeArray(tree.l.l, cX, options)
    @return_on_false complete n T
    (array2, complete2) = evalTreeArray(tree.r.l, cX, options)
    @return_on_false complete2 n T
    op = options.fast_binops[op_idx]
    op_l = options.fast_unaops[op_l_idx]
    op_r = options.fast_unaops[op_r_idx]
    finished_loop = true
    @inbounds @simd for j=1:n
        x_l = op_l(cumulator[j])
        @break_on_check x_l finished_loop T
        x_r = op_r(array2[j])
        @break_on_check x_r finished_loop T
        x = op(x_l, x_r)
        @break_on_check x finished_loop T
        cumulator[j] = x
    end
    @return_on_false finished_loop n T
    return (cumulator, true)
end

function deg2_l1_eval(tree::Node, cX::AbstractMatrix{T}, ::Val{op_idx}, ::Val{op_l_idx}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real,op_idx,op_l_idx}
    n = size(cX, 2)
    (cumulator, complete) = evalTreeArray(tree.l.l, cX, options)
    @return_on_false complete n T
    (array2, complete2) = evalTreeArray(tree.r, cX, options)
    @return_on_false complete2 n T
    op = options.fast_binops[op_idx]
    op_l = options.fast_unaops[op_l_idx]
    finished_loop = true
    @inbounds @simd for j=1:n
        x_l = op_l(cumulator[j])
        @break_on_check x_l finished_loop T
        x = op(x_l, array2[j])
        @break_on_check x finished_loop T
        cumulator[j] = x
    end
    @return_on_false finished_loop n T
    return (cumulator, true)
end

function deg2_r1_eval(tree::Node, cX::AbstractMatrix{T}, ::Val{op_idx}, ::Val{op_r_idx}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real,op_idx,op_r_idx}
    n = size(cX, 2)
    (cumulator, complete) = evalTreeArray(tree.l, cX, options)
    @return_on_false complete n T
    (array2, complete2) = evalTreeArray(tree.r.l, cX, options)
    @return_on_false complete2 n T
    op = options.fast_binops[op_idx]
    op_r = options.fast_unaops[op_r_idx]
    finished_loop = true
    @inbounds @simd for j=1:n
        x_r = op_r(array2[j])
        @break_on_check x_r finished_loop T
        x = op(cumulator[j], x_r)
        @break_on_check x finished_loop T
        cumulator[j] = x
    end
    @return_on_false finished_loop n T
    return (cumulator, true)
end

function deg1_eval(tree::Node, cX::AbstractMatrix{T}, ::Val{op_idx}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real,op_idx}
    n = size(cX, 2)
    (cumulator, complete) = evalTreeArray(tree.l, cX, options)
    @return_on_false complete n T
    op = options.fast_unaops[op_idx]
    finished_loop = true
    @inbounds @simd for j=1:n
        x = op(cumulator[j])
        @break_on_check x finished_loop T
        cumulator[j] = x
    end
    @return_on_false finished_loop n T
    return (cumulator, true)
end

function deg0_eval(tree::Node, cX::AbstractMatrix{T}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real}
    n = size(cX, 2)
    if tree.constant
        return (fill(convert(T, tree.val), n), true)
    else
        return (copy(cX[tree.feature, :]), true)
    end
end

function deg1_l1_eval(tree::Node, cX::AbstractMatrix{T}, ::Val{op_idx}, ::Val{op_l_idx}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real,op_idx,op_l_idx}
    n = size(cX, 2)
    (cumulator, complete) = evalTreeArray(tree.l.l, cX, options)
    @return_on_false complete n T
    op = options.fast_unaops[op_idx]
    op_l = options.fast_unaops[op_l_idx]
    finished_loop = true
    @inbounds @simd for j=1:n
        x_l = op_l(cumulator[j])
        @break_on_check x_l finished_loop T
        x = op(x_l)
        @break_on_check x finished_loop T
        cumulator[j] = x
    end
    @return_on_false finished_loop n T
    return (cumulator, true)
end

function deg1_l2_eval(tree::Node, cX::AbstractMatrix{T}, ::Val{op_idx}, ::Val{op_l_idx}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real,op_idx,op_l_idx}
    n = size(cX, 2)
    (cumulator, complete) = evalTreeArray(tree.l.l, cX, options)
    @return_on_false complete n T
    (array2, complete2) = evalTreeArray(tree.l.r, cX, options)
    @return_on_false complete2 n T
    op = options.fast_unaops[op_idx]
    op_l = options.fast_binops[op_l_idx]
    finished_loop = true
    @inbounds @simd for j=1:n
        x_l = op_l(cumulator[j], array2[j])
        @break_on_check x_l finished_loop T
        x = op(x_l)
        @break_on_check x finished_loop T
        cumulator[j] = x
    end
    @return_on_false finished_loop n T
    return (cumulator, true)
end
