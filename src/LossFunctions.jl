using Random: randperm

# Sum of square error between two arrays
function SSE(x::AbstractArray{T}, y::AbstractArray{T})::T where {T<:Real}
    diff = (x - y)
    return sum(diff .* diff)
end

# Sum of square error between two arrays, with weights
function SSE(x::AbstractArray{T}, y::AbstractArray{T}, w::AbstractArray{T})::T where {T<:Real}
    diff = (x - y)
    return sum(diff .* diff .* w)
end

# Mean of square error between two arrays
function MSE(x::AbstractArray{T}, y::AbstractArray{T})::T where {T<:Real}
    return SSE(x, y)/size(x)[1]
end

# Mean of square error between two arrays
function MSE(x::AbstractArray{T}, y::AbstractArray{T}, w::AbstractArray{T})::T where {T<:Real}
    return SSE(x, y, w)/sum(w)
end

# Loss function. Only MSE implemented right now. TODO
# Also need to put actual loss function in scoreFuncBatch!
function EvalLoss(tree::Node, dataset::Dataset{T}, options::Options)::T where {T<:Real}
    (prediction, completion) = evalTreeArray(tree, dataset.X, options)
    if !completion
        return convert(T, 1000000000)
    end

    if dataset.weighted
        return MSE(prediction, dataset.y, dataset.weights)
    else
        return MSE(prediction, dataset.y)
    end
end

# Score an equation
function scoreFunc(dataset::Dataset{T},
                   baseline::T, tree::Node,
                   options::Options)::T where {T<:Real}
    mse = EvalLoss(tree, dataset, options)
    return mse / baseline + countNodes(tree)*options.parsimony
end

# Score an equation with a small batch
function scoreFuncBatch(dataset::Dataset{T}, baseline::T,
                        tree::Node, options::Options)::T where {T<:Real}
    batchSize = options.batchSize
    batch_idx = randperm(dataset.n)[1:options.batchSize]
    batch_X = dataset.X[:, batch_idx]
    batch_y = dataset.y[batch_idx]
    (prediction, completion) = evalTreeArray(tree, batch_X, options)
    if !completion
        return convert(T, 1000000000)
    end

    if dataset.weighted
        mse = MSE(prediction, batch_y)
    else
        batch_w = dataset.weights[batch_idx]
        mse = MSE(prediction, batch_y, batch_w)
    end
    return mse / baseline + countNodes(tree) * options.parsimony
end
