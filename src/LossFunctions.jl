module LossFunctionsModule

import Random: randperm
import LossFunctions: value, AggMode, SupervisedLoss
import ..CoreModule: Options, Dataset, Node
import ..EquationUtilsModule: compute_complexity
import ..EvaluateEquationModule: eval_tree_array, differentiable_eval_tree_array
import ..EvaluateEquationDerivativeModule: eval_grad_tree_array

function loss( # fmt: off
    x::AbstractArray{T},
    y::AbstractArray{T},
    options::Options{A,B,dA,dB,C,D}, # fmt: on
)::T where {T<:Real,A,B,dA,dB,C,D}
    if C <: SupervisedLoss
        return value(options.loss, y, x, AggMode.Mean())
    elseif C <: Function
        return sum(options.loss.(x, y)) / length(y)
    else
        error("Unrecognized type for loss function: $(C)")
    end
end

function loss(
    x::AbstractArray{T},
    y::AbstractArray{T},
    w::AbstractArray{T},
    options::Options{A,B,dA,dB,C,D},
)::T where {T<:Real,A,B,dA,dB,C,D}
    if C <: SupervisedLoss
        return value(options.loss, y, x, AggMode.WeightedMean(w))
    elseif C <: Function
        return sum(options.loss.(x, y, w)) / sum(w)
    else
        error("Unrecognized type for loss function: $(C)")
    end
end

# Evaluate the loss of a particular expression on the input dataset.
function eval_loss(tree::Node{T}, dataset::Dataset{T}, options::Options)::T where {T<:Real}
    # (prediction, completion) = eval_tree_array(tree, dataset.X, options)
    (prediction, gradient, completion) = eval_grad_tree_array(
        tree, dataset.X, options; variable=true
    )
    if !completion
        return T(Inf)
    end

    x = dataset.X[1, :]
    y = dataset.X[2, :]
    px = dataset.X[3, :]
    py = dataset.X[4, :]
    nfeatures = dataset.nfeatures

    # Normalize dH_dx and dH_dy
    l2_norm_dH = sqrt.(sum(gradient .^ 2; dims=1))

    # Make sure the normalization is never zero:
    if any(l2_norm_dH .< T(1e-8))
        return T(Inf)
    end

    # Compute the dynamical equations:
    f_x = px
    f_y = py
    f_px = -x
    f_py = -4 .* y
    dH_dx = gradient[1, :] ./ l2_norm_dH
    dH_dy = gradient[2, :] ./ l2_norm_dH
    dH_dpx = gradient[3, :] ./ l2_norm_dH
    dH_dpy = gradient[4, :] ./ l2_norm_dH

    orth_x = x
    orth_y = zero(T)
    orth_px = px
    orth_py = zero(T)

    orth2_x = zero(T)
    orth2_y = 4 .* y
    orth2_px = zero(T)
    orth2_py = py

    loss = (
        sum((f_x .* dH_dx .+ f_y .* dH_dy .+ f_px .* dH_dpx .+ f_py .* dH_dpy) .^ 2)
        + sum((orth_x .* dH_dx .+ orth_y .* dH_dy .+ orth_px .* dH_dpx .+ orth_py .* dH_dpy) .^ 2)
        + sum((orth2_x .* dH_dx .+ orth2_y .* dH_dy .+ orth2_px .* dH_dpx .+ orth2_py .* dH_dpy) .^ 2)
    )
    return loss
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
    dataset::Dataset{T}, baseline::T, tree::Node{T}, options::Options
)::Tuple{T,T} where {T<:Real}
    result_loss = eval_loss(tree, dataset, options)
    score = loss_to_score(result_loss, baseline, tree, options)
    return score, result_loss
end

# Score an equation with a small batch
function score_func_batch(
    dataset::Dataset{T}, baseline::T, tree::Node{T}, options::Options
)::Tuple{T,T} where {T<:Real}
    batch_idx = randperm(dataset.n)[1:(options.batchSize)]
    batch_X = dataset.X[:, batch_idx]
    batch_y = dataset.y[batch_idx]
    (prediction, completion) = eval_tree_array(tree, batch_X, options)
    if !completion
        return T(0), T(Inf)
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
