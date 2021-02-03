# Evaluate an equation over an array of datapoints
# This one is just for reference.
function evalTreeArray(tree::Node, cX::AbstractMatrix{T}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real}
    if tree.degree == 0
        deg0_eval(tree, cX, options)
    elseif tree.degree == 1
        deg1_eval(tree, cX, Val(tree.op), options)
    else
        deg2_eval(tree, cX, Val(tree.op), options)
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

