using FromFile
using Random: randperm
using LossFunctions
@from "Core.jl" import Options, Dataset, Node
@from "EquationUtils.jl" import countNodes
@from "EvaluateEquation.jl" import evalTreeArray


function Loss(x::AbstractArray{T}, y::AbstractArray{T}, options::Options)::T where {T<:Real}
    value(options.loss, y, x, AggMode.Mean())
end

function Loss(x::AbstractArray{T}, y::AbstractArray{T}, w::AbstractArray{T}, options::Options)::T where {T<:Real}
    value(options.loss, y, x, AggMode.WeightedMean(w))
end

# Loss function. Only MSE implemented right now. TODO
# Also need to put actual loss function in scoreFuncBatch!
function EvalLoss(tree::Node, dataset::Dataset{T}, options::Options)::T where {T<:Real}
    (prediction, completion) = evalTreeArray(tree, dataset.X, options)
    if !completion
        return convert(T, 1000000000)
    end

    if dataset.weighted
        return Loss(prediction, dataset.y, dataset.weights, options)
    else
        return Loss(prediction, dataset.y, options)
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

    if !dataset.weighted
        mse = Loss(prediction, batch_y, options)
    else
        batch_w = dataset.weights[batch_idx]
        mse = Loss(prediction, batch_y, batch_w, options)
    end
    return mse / baseline + countNodes(tree) * options.parsimony
end
