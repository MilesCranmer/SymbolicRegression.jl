module LossFunctionsModule

import Random: randperm
import LossFunctions: value, AggMode, SupervisedLoss
import DynamicExpressions:
    eval_tree_array, eval_tree_array, differentiable_eval_tree_array, Node
import ..CoreModule: Options, Dataset
import ..ComplexityModule: compute_complexity

function _loss(
    x::AbstractArray{T}, y::AbstractArray{T}, options::Options{LossType}
)::T where {T<:Real,LossType}
    if LossType <: SupervisedLoss
        return value(options.loss, y, x, AggMode.Mean())
    elseif LossType <: Function
        return sum(options.loss.(x, y)) / length(y)
    else
        error("Unrecognized type for loss function: $(C)")
    end
end

function _weighted_loss(
    x::AbstractArray{T}, y::AbstractArray{T}, w::AbstractArray{T}, options::Options{LossType}
)::T where {T<:Real,LossType}
    if LossType <: SupervisedLoss
        return value(options.loss, y, x, AggMode.WeightedMean(w))
    elseif LossType <: Function
        return sum(options.loss.(x, y, w)) / sum(w)
    else
        error("Unrecognized type for loss function: $(C)")
    end
end

# Evaluate the loss of a particular expression on the input dataset.
function eval_loss(tree::Node{T}, dataset::Dataset{T}, options::Options)::T where {T<:Real}
    (prediction, completion) = eval_tree_array(tree, dataset.X, options.operators)
    if !completion
        return T(Inf)
    end

    if dataset.weighted
        return _weighted_loss(prediction, dataset.y, dataset.weights, options)
    else
        return _loss(prediction, dataset.y, options)
    end
end

# Compute a score which includes a complexity penalty in the loss
function loss_to_score(
    loss::T, baseline::T, tree::Node{T}, options::Options
)::T where {T<:Real}
    normalization = if baseline < T(0.01)
        T(0.01)
    else
        baseline
    end
    normalized_loss_term = loss / normalization
    size = compute_complexity(tree, options)
    parsimony_term = size * options.parsimony

    return normalized_loss_term + parsimony_term
end

# Score an equation
function score_func(
    dataset::Dataset{T}, tree::Node{T}, options::Options
)::Tuple{T,T} where {T<:Real}
    result_loss = eval_loss(tree, dataset, options)
    score = loss_to_score(result_loss, dataset.baseline_loss, tree, options)
    return score, result_loss
end

# Score an equation with a small batch
function score_func_batch(
    dataset::Dataset{T}, tree::Node{T}, options::Options
)::Tuple{T,T} where {T<:Real}
    batch_idx = randperm(dataset.n)[1:(options.batchSize)]
    batch_X = dataset.X[:, batch_idx]
    batch_y = dataset.y[batch_idx]
    (prediction, completion) = eval_tree_array(tree, batch_X, options.operators)
    if !completion
        return T(0), T(Inf)
    end

    if !dataset.weighted
        result_loss = _loss(prediction, batch_y, options)
    else
        batch_w = dataset.weights[batch_idx]
        result_loss = _weighted_loss(prediction, batch_y, batch_w, options)
    end
    score = loss_to_score(result_loss, dataset.baseline_loss, tree, options)
    return score, result_loss
end

function update_baseline_loss!(dataset::Dataset{T}, options::Options) where {T<:Real}
    dataset.baseline_loss = if dataset.weighted
        _weighted_loss(dataset.y, ones(T, dataset.n) .* dataset.avg_y, dataset.weights, options)
    else
        _loss(dataset.y, ones(T, dataset.n) .* dataset.avg_y, options)
    end
    return nothing
end

end
