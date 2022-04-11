using FromFile
using Random: randperm
using LossFunctions
using Zygote: gradient
@from "Core.jl" import Options, Dataset, Node
@from "EquationUtils.jl" import countNodes
@from "EvaluateEquation.jl" import evalTreeArray
@from "EvaluateEquationDerivative.jl" import evalGradTreeArray


###############################################################################
# x is prediction, y is target. ###############################################
###############################################################################
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
function EvalLoss(tree::Node, dataset::Dataset{T}, options::Options)::T where {T<:Real}
    (prediction, completion) = evalTreeArray(tree, dataset.X, options)
    if !completion
        return T(1000000000)
    end

    if dataset.weighted
        return Loss(prediction, dataset.y, dataset.weights, options)
    else
        return Loss(prediction, dataset.y, options)
    end
end

# Gradients with respect to constants::
function dEvalLoss(tree::Node, dataset::Dataset{T}, options::Options{A,B,dA,dB,C})::AbstractVector{T} where {T<:Real,A,B,dA,dB,C<:Union{SupervisedLoss,Function}}
    prediction, dprediction_dconstants, completion = evalGradTreeArray(tree, dataset.X, options)
    # prediction: [nrows]
    # dprediction_dconstants: [nconstants, nrows]
    if !completion
        return fill(T(0), size(dprediction_dconstants, 1))
    end

    dloss_dprediction = if dataset.weighted
        gradient((x) -> Loss(x, dataset.y, dataset.weights, options), prediction)[1]
    else
        gradient((x) -> Loss(x, dataset.y, options), prediction)[1]
    end
    # dloss_dprediction: [nrows]

    dloss_dconstants = dprediction_dconstants * dloss_dprediction
    # dloss_dconstants: [nconstants]
    return dloss_dconstants
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
                   options::Options)::Tuple{T,T} where {T<:Real}
    loss = EvalLoss(tree, dataset, options)
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
