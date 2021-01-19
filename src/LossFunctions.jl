using Random: randperm

# Sum of square error between two arrays
function SSE(x::AbstractArray{T}, y::AbstractArray{T})::T where {T<:Real}
    diff = (x - y)
    return sum(diff .* diff)
end
function SSE(x::Nothing, y::AbstractArray{T})::T where {T<:Real}
    return 1000000000
end

# Sum of square error between two arrays, with weights
function SSE(x::AbstractArray{T}, y::AbstractArray{T}, w::AbstractArray{T})::T where {T<:Real}
    diff = (x - y)
    return sum(diff .* diff .* w)
end
function SSE(x::Nothing, y::AbstractArray{T}, w::AbstractArray{T})::T where {T<:Real}
    return Nothing
end

# Mean of square error between two arrays
function MSE(x::Nothing, y::AbstractArray{T})::T where {T<:Real}
    return convert(T, 1000000000)
end

# Mean of square error between two arrays
function MSE(x::AbstractArray{T}, y::AbstractArray{T})::T where {T<:Real}
    return SSE(x, y)/size(x)[1]
end

# Mean of square error between two arrays
function MSE(x::Nothing, y::AbstractArray{T}, w::AbstractArray{T})::T where {T<:Real}
    return convert(T, 1000000000)
end

# Mean of square error between two arrays
function MSE(x::AbstractArray{T}, y::AbstractArray{T}, w::AbstractArray{T})::T where {T<:Real}
    return SSE(x, y, w)/sum(w)
end

# Score an equation
function scoreFunc(X::AbstractMatrix{T}, y::AbstractVector{T},
                   baseline::T, tree::Node,
                   options::Options)::T where {T<:Real}
    prediction = evalTreeArray(tree, X, options)
    if prediction === nothing
        return convert(T, 1000000000)
    end
    if options.weighted
        mse = MSE(prediction, y, weights)
    else
        mse = MSE(prediction, y)
    end
    return mse / baseline + countNodes(tree)*options.parsimony
end

# Score an equation with a small batch
function scoreFuncBatch(X::AbstractMatrix{T}, y::AbstractVector{T},
                        baseline::T, tree::Node, options::Options)::T where {T<:Real}
    # options.batchSize
    batch_idx = randperm(size(X)[1])[1:options.batchSize]
    batch_X = X[batch_idx, :]
    prediction = evalTreeArray(tree, batch_X, options)
    if prediction === nothing
        return convert(T, 1000000000)
    end
    size_adjustment = convert(T, 1)
    batch_y = y[batch_idx]
    if options.weighted
        batch_w = weights[batch_idx]
        mse = MSE(prediction, batch_y, batch_w)
        size_adjustment = convert(T, 1) * size(X)[1] / options.batchSize
    else
        mse = MSE(prediction, batch_y)
    end
    return size_adjustment * mse / baseline + countNodes(tree)*options.parsimony
end
