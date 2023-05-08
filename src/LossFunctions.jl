module LossFunctionsModule

import Random: randperm
using StatsBase: StatsBase
import DynamicExpressions: Node
using LossFunctions: LossFunctions
import LossFunctions: SupervisedLoss
import ..InterfaceDynamicExpressionsModule: eval_tree_array
import ..CoreModule: Options, Dataset, DATA_TYPE, LOSS_TYPE
import ..ComplexityModule: compute_complexity

const OLD_LOSS_FUNCTIONS = hasproperty(LossFunctions, :value)
const GENERAL_LOSS_TYPE = OLD_LOSS_FUNCTIONS ? Function : Union{Function,SupervisedLoss}

if OLD_LOSS_FUNCTIONS
    @eval begin
        import LossFunctions: value, AggMode
        #! format: off
        function _loss(
            x::AbstractArray{T},
            y::AbstractArray{T},
            loss::SupervisedLoss
        ) where {T<:DATA_TYPE}
            return value(loss, y, x, AggMode.Mean())
        end
        function _weighted_loss(
            x::AbstractArray{T},
            y::AbstractArray{T},
            w::AbstractArray{T},
            loss::SupervisedLoss,
        ) where {T<:DATA_TYPE}
            return value(loss, y, x, AggMode.WeightedMean(w))
        end
        #! format: on
    end
else
    @eval import LossFunctions: mean, sum
end

function _loss(
    x::AbstractArray{T}, y::AbstractArray{T}, loss::LT
) where {T<:DATA_TYPE,LT<:GENERAL_LOSS_TYPE}
    if LT <: SupervisedLoss
        return mean(loss, x, y)
    else
        return quote
            l(i) = loss(x[i], y[i])
            return mean(l, eachindex(x))
        end
    end
end

function _weighted_loss(
    x::AbstractArray{T}, y::AbstractArray{T}, w::AbstractArray{T}, loss::LT
) where {T<:DATA_TYPE,LT<:GENERAL_LOSS_TYPE}
    if LT <: SupervisedLoss
        return sum(loss, x, y, w; normalize=true)
    else
        return quote
            l(i) = loss(x[i], y[i], w[i])
            return sum(l, eachindex(x)) / sum(w)
        end
    end
end

# Evaluate the loss of a particular expression on the input dataset.
function _eval_loss(
    tree::Node{T}, dataset::Dataset{T,L,AX,AY}, options::Options
)::L where {T<:DATA_TYPE,L<:LOSS_TYPE,AX<:AbstractArray{T},AY<:AbstractArray{T}}
    (prediction, completion) = eval_tree_array(tree, dataset.X, options)
    if !completion
        return L(Inf)
    end

    if dataset.weighted
        return _weighted_loss(
            prediction,
            dataset.y::AY,
            dataset.weights::AbstractVector{T},
            options.elementwise_loss,
        )
    else
        return _loss(prediction, dataset.y::AY, options.elementwise_loss)
    end
end

# This evaluates function F:
function evaluator(
    f::F, tree::Node{T}, dataset::Dataset{T,L}, options::Options
)::L where {T<:DATA_TYPE,L<:LOSS_TYPE,F}
    return f(tree, dataset, options)
end

# Evaluate the loss of a particular expression on the input dataset.
function eval_loss(
    tree::Node{T}, dataset::Dataset{T,L}, options::Options
)::L where {T<:DATA_TYPE,L<:LOSS_TYPE}
    if options.loss_function === nothing
        return _eval_loss(tree, dataset, options)
    else
        f = options.loss_function::Function
        return evaluator(f, tree, dataset, options)
    end
end

# Compute a score which includes a complexity penalty in the loss
function loss_to_score(
    loss::L, use_baseline::Bool, baseline::L, tree::Node{T}, options::Options
)::L where {T<:DATA_TYPE,L<:LOSS_TYPE}
    # TODO: Come up with a more general normalization scheme.
    normalization = if baseline >= L(0.01) && use_baseline
        baseline
    else
        L(0.01)
    end
    normalized_loss_term = loss / normalization
    size = compute_complexity(tree, options)
    parsimony_term = size * options.parsimony

    return normalized_loss_term + parsimony_term
end

# Score an equation
function score_func(
    dataset::Dataset{T,L}, tree::Node{T}, options::Options
)::Tuple{L,L} where {T<:DATA_TYPE,L<:LOSS_TYPE}
    result_loss = eval_loss(tree, dataset, options)
    score = loss_to_score(
        result_loss, dataset.use_baseline, dataset.baseline_loss, tree, options
    )
    return score, result_loss
end

# Score an equation with a small batch
function score_func_batch(
    dataset::Dataset{T,L}, tree::Node{T}, options::Options
)::Tuple{L,L} where {T<:DATA_TYPE,L<:LOSS_TYPE}
    if options.loss_function !== nothing
        error("Batched losses for custom objectives are not yet implemented.")
    end
    batch_idx = StatsBase.sample(1:(dataset.n), options.batch_size; replace=true)
    batch_X = view(dataset.X, :, batch_idx)
    (prediction, completion) = eval_tree_array(tree, batch_X, options)
    if !completion
        return L(0), L(Inf)
    end

    batch_y = view(dataset.y::AbstractVector{T}, batch_idx)
    if !dataset.weighted
        result_loss = L(_loss(prediction, batch_y, options.elementwise_loss))
    else
        w = dataset.weights::AbstractVector{T}
        batch_w = view(w, batch_idx)
        result_loss = L(
            _weighted_loss(prediction, batch_y, batch_w, options.elementwise_loss)
        )
    end
    score = loss_to_score(
        result_loss, dataset.use_baseline, dataset.baseline_loss, tree, options
    )
    return score, result_loss
end

"""
    update_baseline_loss!(dataset::Dataset{T,L}, options::Options) where {T<:DATA_TYPE,L<:LOSS_TYPE}

Update the baseline loss of the dataset using the loss function specified in `options`.
"""
function update_baseline_loss!(
    dataset::Dataset{T,L}, options::Options
) where {T<:DATA_TYPE,L<:LOSS_TYPE}
    example_tree = Node(T; val=dataset.avg_y)
    baseline_loss = eval_loss(example_tree, dataset, options)
    if isfinite(baseline_loss)
        dataset.baseline_loss = baseline_loss
        dataset.use_baseline = true
    else
        dataset.baseline_loss = one(L)
        dataset.use_baseline = false
    end
    return nothing
end

end
