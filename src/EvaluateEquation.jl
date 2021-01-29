# The Val{i} optimizes it into a branching statement (https://discourse.julialang.org/t/meta-programming-an-if-else-statement-of-user-defined-length/53525)
function BINOP!(x::AbstractVector{T}, y::AbstractVector{T}, ::Val{i}, ::Val{clen}, options::Options) where {i,clen,T<:Real}
    op = options.binops[i]
    # broadcast!(op, x, x, y)
    @inbounds @simd for j=1:clen
        x[j] = op(x[j], y[j])
    end
end

function UNAOP!(x::AbstractVector{T}, ::Val{i}, ::Val{clen}, options::Options) where {i,clen,T<:Real}
    op = options.unaops[i]
    @inbounds @simd for j=1:clen
        x[j] = op(x[j])
    end
end


#isnan(x::AbstractFloat) = (x != x)::Bool
#isfinite(x::AbstractFloat) = x - x == 0

# Evaluate an equation over an array of datapoints
function evalTreeArray(tree::Node, cX::AbstractMatrix{T}, options::Options)::Tuple{AbstractVector{T}, Bool} where {T<:Real}
    clen = size(cX)[2]
    if tree.degree == 0
        if tree.constant #TODO: Make this done with types instead
            return (fill(convert(T, tree.val), clen), true)
        else
            return (copy(cX[tree.feature, :]), true)
        end
    end

    (cumulator, complete) = evalTreeArray(tree.l, cX, options)
    if !complete
        return (cumulator, false)
    end

    if tree.degree == 1
        op_idx = tree.op
        UNAOP!(cumulator, Val(op_idx), Val(clen), options)
    else
        (array2, complete2) = evalTreeArray(tree.r, cX, options)
        if !complete2
            return (cumulator, false)
        end
        op_idx = tree.op
        BINOP!(cumulator, array2, Val(op_idx), Val(clen), options)
    end

	# TODO - consider checking this at end.
    @inbounds @simd for i=1:clen
        if (cumulator[i] != cumulator[i])::Bool || (cumulator[i] - cumulator[i] != convert(T, 0))::Bool
            return (cumulator, false)
        end
    end

    return (cumulator, true)
end
