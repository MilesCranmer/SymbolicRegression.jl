module LossFunctionsModule

import KernelFunctions: SqExponentialKernel, ScaleTransform, kernelmatrix
import Random: randperm, MersenneTwister
import LossFunctions: value, AggMode, SupervisedLoss
import ..CoreModule: Options, Dataset, Node
import ..EquationUtilsModule: compute_complexity
import ..EvaluateEquationModule: eval_tree_array, differentiable_eval_tree_array

function loss(
    x::AbstractArray{T}, y::AbstractArray{T}, options::Options{A,B,dA,dB,C,D}
)::T where {T<:Real,A,B,dA,dB,C<:SupervisedLoss,D}
    return value(options.loss, y, x, AggMode.Mean())
end
function loss(
    x::AbstractArray{T}, y::AbstractArray{T}, options::Options{A,B,dA,dB,C,D}
)::T where {T<:Real,A,B,dA,dB,C<:Function,D}
    return sum(options.loss.(x, y)) / length(y)
end

function loss(
    x::AbstractArray{T},
    y::AbstractArray{T},
    w::AbstractArray{T},
    options::Options{A,B,dA,dB,C,D},
)::T where {T<:Real,A,B,dA,dB,C<:SupervisedLoss,D}
    return value(options.loss, y, x, AggMode.WeightedMean(w))
end
function loss(
    x::AbstractArray{T},
    y::AbstractArray{T},
    w::AbstractArray{T},
    options::Options{A,B,dA,dB,C,D},
)::T where {T<:Real,A,B,dA,dB,C<:Function,D}
    return sum(options.loss.(x, y, w)) / sum(w)
end

# Evaluate the loss of a particular expression on the input dataset.
function eval_loss(tree::Node, dataset::Dataset{T}, options::Options)::T where {T<:Real}
    if options.noisy_nodes
        return eval_loss_noisy_nodes(tree, dataset, options)
    end

    (prediction, completion) = eval_tree_array(tree, dataset.X, options)

    if !completion
        return T(1000000000)
    end

    if dataset.weighted
        return loss(prediction, dataset.y, dataset.weights, options)
    else
        return loss(prediction, dataset.y, options)
    end
end

function mmd_loss(
    x::AbstractMatrix{T}, y::AbstractMatrix{T}, ::Val{n}, ::Val{nfeatures}, options::Options
)::T where {T<:Real,n,nfeatures}
    # x: (feature, row)
    # y: (feature, row)
    mmd_raw = T(0)

    mmd_kernel_width = T(options.noisy_kernel_width)  # TODO: make this a parameter
    k_raw = SqExponentialKernel() ∘ ScaleTransform(1 / mmd_kernel_width)

    k = (args...) -> kernelmatrix(k_raw, args...; obsdim=2)

    mmd_raw = sum(k(x) .+ k(y) .- 2 .* k(x, y))
    mmd = mmd_raw / n^2
    return mmd
end

function eval_loss_noisy_nodes(
    tree::Node, dataset::Dataset{T}, options::Options
)::T where {T<:Real}
    @assert !dataset.weighted

    baseX = dataset.X
    # Settings for noise generation:
    num_noise_features = options.noisy_features
    num_seeds = options.num_seeds

    losses = Array{T}(undef, num_seeds)
    z_true = Array{T}(undef, dataset.nfeatures + num_noise_features + 1, dataset.n)
    z_pred = Array{T}(undef, dataset.nfeatures + num_noise_features + 1, dataset.n)

    noise_start = dataset.nfeatures + 1
    noise_end = noise_start + num_noise_features
    val_n = Val(dataset.n)
    val_nfeatures = Val(dataset.nfeatures + num_noise_features + 1)

    z_true[1:(dataset.nfeatures), :] .= baseX
    z_pred[1:(dataset.nfeatures), :] .= baseX

    z_true[end, :] .= dataset.y

    for noise_seed in 1:num_seeds

        # Current batch of noise:
        z_true[noise_start:noise_end, :] .= view(dataset.noise, noise_seed, :, :)
        z_pred[noise_start:noise_end, :] .= view(dataset.noise, noise_seed, :, :)

        # Noise enters as a feature:
        (prediction, completion) = eval_tree_array(
            tree, view(z_true, 1:noise_end, :), options
        )
        if !completion
            return T(1000000000)
        end

        # We compare joint distribution of (x, y) to (x, y_predicted)
        z_pred[end, :] .= prediction
        losses[noise_seed] = mmd_loss(z_pred, z_true, val_n, val_nfeatures, options)
    end
    return sum(losses) / num_seeds
end

# Compute a score which includes a complexity penalty in the loss
function loss_to_score(
    loss::T, baseline::T, tree::Node, options::Options
)::T where {T<:Real}
    normalized_loss_term = loss / baseline
    size = compute_complexity(tree, options)
    parsimony_term = size * options.parsimony

    return normalized_loss_term + parsimony_term
end

# Score an equation
function score_func(
    dataset::Dataset{T}, baseline::T, tree::Node, options::Options
)::Tuple{T,T} where {T<:Real}
    result_loss = eval_loss(tree, dataset, options)
    score = loss_to_score(result_loss, baseline, tree, options)
    return score, result_loss
end

# Score an equation with a small batch
function score_func_batch(
    dataset::Dataset{T}, baseline::T, tree::Node, options::Options
)::Tuple{T,T} where {T<:Real}
    batch_idx = randperm(dataset.n)[1:(options.batchSize)]
    batch_X = dataset.X[:, batch_idx]
    batch_y = dataset.y[batch_idx]
    (prediction, completion) = eval_tree_array(tree, batch_X, options)
    if !completion
        return T(1000000000), T(1000000000)
    end

    if !dataset.weighted
        result_loss = loss(prediction, batch_y, options)
    else
        batch_w = dataset.weights[batch_idx]
        result_loss = loss(prediction, batch_y, batch_w, options)
    end
    score = loss_to_score(result_loss, baseline, tree, options)
    return score, result_loss
end

end
