module LossFunctionsModule

import Random: randperm
using StatsBase: StatsBase
import LossFunctions: value, AggMode, SupervisedLoss
import DynamicExpressions: Node
import ..InterfaceDynamicExpressionsModule: eval_tree_array
import ..CoreModule: Options, Dataset
import ..ComplexityModule: compute_complexity

function _loss(
    x::AbstractArray{T}, y::AbstractArray{T}, loss::SupervisedLoss
)::T where {T<:Real}
    return value(loss, y, x, AggMode.Mean())
end

function _loss(x::AbstractArray{T}, y::AbstractArray{T}, loss::Function)::T where {T<:Real}
    return sum(loss.(x, y)) / length(y)
end

function _weighted_loss(
    x::AbstractArray{T}, y::AbstractArray{T}, w::AbstractArray{T}, loss::SupervisedLoss
)::T where {T<:Real}
    return value(loss, y, x, AggMode.WeightedMean(w))
end

function _weighted_loss(
    x::AbstractArray{T}, y::AbstractArray{T}, w::AbstractArray{T}, loss::Function
)::T where {T<:Real}
    return sum(loss.(x, y, w)) / sum(w)
end

# Evaluate the loss of a particular expression on the input dataset.
function _eval_loss(tree::Node{T}, dataset::Dataset{T}, options::Options)::T where {T<:Real}
    (prediction, completion) = eval_tree_array(tree, dataset.X, options)
    if !completion
        return T(Inf)
    end

    if dataset.weighted
        return _weighted_loss(
            prediction,
            dataset.y,
            dataset.weights::AbstractVector{T},
            options.elementwise_loss,
        )
    else
        return _loss(prediction, dataset.y, options.elementwise_loss)
    end
end

# This evaluates function F:
function evaluator(
    f::F, tree::Node{T}, dataset::Dataset{T}, options::Options
)::T where {T<:Real,F}
    return f(tree, dataset, options)
end

# Evaluate the loss of a particular expression on the input dataset.
function eval_loss(tree::Node{T}, dataset::Dataset{T}, options::Options)::T where {T<:Real}
    if options.loss_function === nothing
        return _eval_loss(tree, dataset, options)
    else
        f = options.loss_function::Function
        return evaluator(f, tree, dataset, options)
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
    batch_idx = StatsBase.sample(1:(dataset.n), options.batch_size; replace=true)
    batch_X = view(dataset.X, :, batch_idx)
    batch_y = view(dataset.y, batch_idx)
    (prediction, completion) = eval_tree_array(tree, batch_X, options)
    if !completion
        return T(0), T(Inf)
    end

    if !dataset.weighted
        result_loss = _loss(prediction, batch_y, options.elementwise_loss)
    else
        w = dataset.weights::AbstractVector{T}
        batch_w = view(w, batch_idx)
        result_loss = _weighted_loss(prediction, batch_y, batch_w, options.elementwise_loss)
    end
    score = loss_to_score(result_loss, dataset.baseline_loss, tree, options)
    return score, result_loss
end

"""
    update_baseline_loss!(dataset::Dataset{T}, options::Options) where {T<:Real}

Update the baseline loss of the dataset using the loss function specified in `options`.
"""
function update_baseline_loss!(dataset::Dataset{T}, options::Options) where {T<:Real}
    example_tree = Node(T; val=dataset.avg_y)
    dataset.baseline_loss = eval_loss(example_tree, dataset, options)
    return nothing
end

end
