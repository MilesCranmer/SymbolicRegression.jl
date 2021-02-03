# Evaluate an equation over an array of datapoints
# This one is just for reference.
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
        if tree.l.degree == 1
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

function check_array(cumulator::AbstractVector{T})::Bool where {T<:Real}
    @inbounds @simd for i=1:size(cumulator, 1)
        if (cumulator[i] != cumulator[i])::Bool || (cumulator[i] - cumulator[i] != convert(T, 0))::Bool
            return false
        end
    end
    return true
end

function deg2_eval(tree::Node, cX::AbstractMatrix{T}, ::Val{op_idx}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real,op_idx}
     (cumulator, complete) = evalTreeArray(tree.l, cX, options)
     if !complete
         return (cumulator, false)
     end
     (array2, complete2) = evalTreeArray(tree.r, cX, options)
     if !complete2
         return (cumulator, false)
     end
     op = options.binops[op_idx]
     @inbounds @simd for j=1:size(cumulator, 1)
         cumulator[j] = op(cumulator[j], array2[j])
     end
     return (cumulator, check_array(cumulator))
end

function deg2_l1_r1_eval(tree::Node, cX::AbstractMatrix{T}, ::Val{op_idx}, ::Val{op_l_idx}, ::Val{op_r_idx}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real,op_idx,op_l_idx,op_r_idx}
     (cumulator, complete) = evalTreeArray(tree.l.l, cX, options)
     if !complete
         return (cumulator, false)
     end
     (array2, complete2) = evalTreeArray(tree.r.l, cX, options)
     if !complete2
         return (cumulator, false)
     end
     op = options.binops[op_idx]
     op_l = options.unaops[op_l_idx]
     op_r = options.unaops[op_r_idx]
     @inbounds @simd for j=1:size(cumulator, 1)
         cumulator[j] = op(op_l(cumulator[j]), op_r(array2[j]))
     end
     return (cumulator, check_array(cumulator))
end

function deg2_l1_eval(tree::Node, cX::AbstractMatrix{T}, ::Val{op_idx}, ::Val{op_l_idx}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real,op_idx,op_l_idx}
     (cumulator, complete) = evalTreeArray(tree.l.l, cX, options)
     if !complete
         return (cumulator, false)
     end
     (array2, complete2) = evalTreeArray(tree.r, cX, options)
     if !complete2
         return (cumulator, false)
     end
     op = options.binops[op_idx]
     op_l = options.unaops[op_l_idx]
     @inbounds @simd for j=1:size(cumulator, 1)
         cumulator[j] = op(op_l(cumulator[j]), array2[j])
     end
     return (cumulator, check_array(cumulator))
end

function deg2_r1_eval(tree::Node, cX::AbstractMatrix{T}, ::Val{op_idx}, ::Val{op_r_idx}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real,op_idx,op_r_idx}
     (cumulator, complete) = evalTreeArray(tree.l, cX, options)
     if !complete
         return (cumulator, false)
     end
     (array2, complete2) = evalTreeArray(tree.r.l, cX, options)
     if !complete2
         return (cumulator, false)
     end
     op = options.binops[op_idx]
     op_r = options.unaops[op_r_idx]
     @inbounds @simd for j=1:size(cumulator, 1)
         cumulator[j] = op(cumulator[j], op_r(array2[j]))
     end
     return (cumulator, check_array(cumulator))
end

function deg1_eval(tree::Node, cX::AbstractMatrix{T}, ::Val{op_idx}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real,op_idx}
     (cumulator, complete) = evalTreeArray(tree.l, cX, options)
     if !complete
         return (cumulator, false)
     end
     op = options.unaops[op_idx]
     @inbounds @simd for j=1:size(cumulator, 1)
         cumulator[j] = op(cumulator[j])
     end
     return (cumulator, check_array(cumulator))
end

function deg0_eval(tree::Node, cX::AbstractMatrix{T}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real}
     if tree.constant
         return (fill(convert(T, tree.val), size(cX, 2)), true)
     else
         return (copy(cX[tree.feature, :]), true)
     end
end

function deg1_l1_eval(tree::Node, cX::AbstractMatrix{T}, ::Val{op_idx}, ::Val{op_l_idx}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real,op_idx,op_l_idx}
     (cumulator, complete) = evalTreeArray(tree.l.l, cX, options)
     if !complete
         return (cumulator, false)
     end
     op = options.unaops[op_idx]
     op_l = options.unaops[op_l_idx]
     @inbounds @simd for j=1:size(cumulator, 1)
         cumulator[j] = op(op_l(cumulator[j]))
     end
     return (cumulator, check_array(cumulator))
end
