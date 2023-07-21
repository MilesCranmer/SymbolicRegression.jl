module LossFunctionsModule

import Random: randperm
using StatsBase: StatsBase
import DynamicExpressions: Node
using LossFunctions: LossFunctions
import LossFunctions: SupervisedLoss
import ..InterfaceDynamicExpressionsModule: eval_tree_array
import ..CoreModule: Options, Dataset, DATA_TYPE, LOSS_TYPE
import ..ComplexityModule: compute_complexity
import ..DimensionalAnalysisModule: violates_dimensional_constraints

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
        l(i) = loss(x[i], y[i])
        return mean(l, eachindex(x))
    end
end

function _weighted_loss(
    x::AbstractArray{T}, y::AbstractArray{T}, w::AbstractArray{T}, loss::LT
) where {T<:DATA_TYPE,LT<:GENERAL_LOSS_TYPE}
    if LT <: SupervisedLoss
        return sum(loss, x, y, w; normalize=true)
    else
        l(i) = loss(x[i], y[i], w[i])
        return sum(l, eachindex(x)) / sum(w)
    end
end

# Evaluate the loss of a particular expression on the input dataset.
function _eval_loss(
    tree::Node{T}, dataset::Dataset{T,L,AX,AY}, options::Options, regularization::Bool
)::L where {T<:DATA_TYPE,L<:LOSS_TYPE,AX<:AbstractArray{T},AY<:AbstractArray{T}}
    (prediction, completion) = eval_tree_array(tree, dataset.X, options)
    if !completion
        return L(Inf)
    end

    loss_val = if dataset.weighted
        _weighted_loss(
            prediction,
            dataset.y::AY,
            dataset.weights::AbstractVector{T},
            options.elementwise_loss,
        )
    else
        _loss(prediction, dataset.y::AY, options.elementwise_loss)
    end

    if regularization
        loss_val += dimensional_regularization(tree, dataset, options)
    end

    return loss_val
end

# This evaluates function F:
function evaluator(
    f::F, tree::Node{T}, dataset::Dataset{T,L}, options::Options
)::L where {T<:DATA_TYPE,L<:LOSS_TYPE,F}
    return f(tree, dataset, options)
end

# Evaluate the loss of a particular expression on the input dataset.
function eval_loss(
    tree::Node{T}, dataset::Dataset{T,L}, options::Options, regularization::Bool=true
)::L where {T<:DATA_TYPE,L<:LOSS_TYPE}
    loss_val = if options.loss_function === nothing
        _eval_loss(tree, dataset, options, regularization)
    else
        f = options.loss_function::Function
        evaluator(f, tree, dataset, options)
    end

    return loss_val
end

function eval_loss_batched(
    tree::Node{T}, dataset::Dataset{T,L}, options::Options, regularization::Bool=true
)::L where {T<:DATA_TYPE,L<:LOSS_TYPE}
    if options.loss_function !== nothing
        error("Batched losses for custom objectives are not yet implemented.")
    end
    batch_idx = StatsBase.sample(1:(dataset.n), options.batch_size; replace=true)
    batch_X = view(dataset.X, :, batch_idx)
    (prediction, completion) = eval_tree_array(tree, batch_X, options)
    if !completion
        return L(Inf)
    end

    batch_y = view(dataset.y::AbstractVector{T}, batch_idx)
    loss_val = if !dataset.weighted
        L(_loss(prediction, batch_y, options.elementwise_loss))
    else
        w = dataset.weights::AbstractVector{T}
        batch_w = view(w, batch_idx)
        L(_weighted_loss(prediction, batch_y, batch_w, options.elementwise_loss))
    end

    if regularization
        loss_val += dimensional_regularization(tree, dataset, options)
    end

    return loss_val
end

# Just so we can pass either PopMember or Node here:
get_tree(t::Node) = t
get_tree(m) = m.tree
# Beware: this is a circular dependency situation...
# PopMember is using losses, but then we also want
# losses to use the PopMember's cached complexity for trees.
# TODO!

# Compute a score which includes a complexity penalty in the loss
function loss_to_score(
    loss::L,
    use_baseline::Bool,
    baseline::L,
    member,
    options::Options,
    complexity::Union{Int,Nothing}=nothing,
)::L where {L<:LOSS_TYPE}
    # TODO: Come up with a more general normalization scheme.
    normalization = if baseline >= L(0.01) && use_baseline
        baseline
    else
        L(0.01)
    end
    loss_val = loss / normalization
    size = complexity === nothing ? compute_complexity(member, options) : complexity
    parsimony_term = size * options.parsimony
    loss_val += L(parsimony_term)

    return loss_val
end

# Score an equation
function score_func(
    dataset::Dataset{T,L}, member, options::Options, complexity::Union{Int,Nothing}=nothing
)::Tuple{L,L} where {T<:DATA_TYPE,L<:LOSS_TYPE}
    result_loss = eval_loss(get_tree(member), dataset, options)
    score = loss_to_score(
        result_loss,
        dataset.use_baseline,
        dataset.baseline_loss,
        member,
        options,
        complexity,
    )
    return score, result_loss
end

# Score an equation with a small batch
function score_func_batch(
    dataset::Dataset{T,L}, member, options::Options, complexity::Union{Int,Nothing}=nothing
)::Tuple{L,L} where {T<:DATA_TYPE,L<:LOSS_TYPE}
    result_loss = eval_loss_batched(get_tree(member), dataset, options)
    score = loss_to_score(
        result_loss,
        dataset.use_baseline,
        dataset.baseline_loss,
        member,
        options,
        complexity,
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

function dimensional_regularization(
    tree::Node{T}, dataset::Dataset{T,L}, options::Options
) where {T<:DATA_TYPE,L<:LOSS_TYPE}
    if !violates_dimensional_constraints(tree, dataset, options)
        return zero(L)
    elseif options.dimensional_constraint_penalty === nothing
        return L(1000)
    else
        return L(options.dimensional_constraint_penalty::Float32)
    end
end

end
