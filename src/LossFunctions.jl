using FromFile
using Random: randperm
using LossFunctions
@from "Core.jl" import Options, Dataset, Node
@from "EquationUtils.jl" import countNodes
@from "EvaluateEquation.jl" import evalTreeArray, differentiableEvalTreeArray


function Loss(x::AbstractArray{T}, y::AbstractArray{T}, options::Options{A,B,dA,dB,C})::T where {T<:Real,A,B,dA,dB,C<:SupervisedLoss}
    value(options.loss, y, x, AggMode.Mean())
end
function Loss(x::AbstractArray{T}, y::AbstractArray{T}, options::Options{A,B,dA,dB,C})::T where {T<:Real,A,B,dA,dB,C<:Function}
    sum(options.loss.(x, y))/length(y)
end

function Loss(x::AbstractArray{T}, y::AbstractArray{T}, w::AbstractArray{T}, options::Options{A,B,dA,dB,C})::T where {T<:Real,A,B,dA,dB,C<:SupervisedLoss}
    value(options.loss, y, x, AggMode.WeightedMean(w))
end
function Loss(x::AbstractArray{T}, y::AbstractArray{T}, w::AbstractArray{T}, options::Options{A,B,dA,dB,C})::T where {T<:Real,A,B,dA,dB,C<:Function}
    sum(options.loss.(x, y, w))/sum(w)
end

# Loss function. Only MSE implemented right now. TODO
# Also need to put actual loss function in scoreFuncBatch!
function EvalLoss(tree::Node, dataset::Dataset{T}, options::Options;
                  allow_diff=false)::T where {T<:Real}
    if !allow_diff
        (prediction, completion) = evalTreeArray(tree, dataset.X, options)
    else
        (prediction, completion) = differentiableEvalTreeArray(tree, dataset.X, options)
    end
    if !completion
        return T(1000000000)
    end

    if dataset.weighted
        return Loss(prediction, dataset.y, dataset.weights, options)
    else
        return Loss(prediction, dataset.y, options)
    end
end

# Compute a score which includes a complexity penalty in the loss
function lossToScore(loss::T, baseline::T, tree::Node, options::Options)::T where {T<:Real}
    normalized_loss_term = loss / baseline
    size = countNodes(tree)
    parsimony_term = size*options.parsimony

    return normalized_loss_term + parsimony_term
end

# Score an equation
function scoreFunc(dataset::Dataset{T},
                   baseline::T, tree::Node,
                   options::Options; allow_diff=false)::Tuple{T,T} where {T<:Real}
    loss = EvalLoss(tree, dataset, options; allow_diff=allow_diff)
    score = lossToScore(loss, baseline, tree, options)
    return score, loss
end

# Score an equation with a small batch
function scoreFuncBatch(dataset::Dataset{T}, baseline::T,
                        tree::Node, options::Options)::Tuple{T,T} where {T<:Real}
    batchSize = options.batchSize
    batch_idx = randperm(dataset.n)[1:options.batchSize]
    batch_X = dataset.X[:, batch_idx]
    batch_y = dataset.y[batch_idx]
    (prediction, completion) = evalTreeArray(tree, batch_X, options)
    if !completion
        return T(1000000000), T(1000000000)
    end

    if !dataset.weighted
        loss = Loss(prediction, batch_y, options)
    else
        batch_w = dataset.weights[batch_idx]
        loss = Loss(prediction, batch_y, batch_w, options)
    end
    score = lossToScore(loss, baseline, tree, options)
    return score, loss
end
