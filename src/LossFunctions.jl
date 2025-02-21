module LossFunctionsModule

using DispatchDoctor: @stable
using DynamicExpressions:
    AbstractExpression, AbstractExpressionNode, get_tree, eval_tree_array
using LossFunctions: LossFunctions
using LossFunctions: SupervisedLoss
using ..CoreModule:
    AbstractOptions,
    Dataset,
    create_expression,
    DATA_TYPE,
    LOSS_TYPE,
    is_weighted,
    get_indices,
    get_full_dataset
using ..ComplexityModule: compute_complexity
using ..DimensionalAnalysisModule: violates_dimensional_constraints
using ..InterfaceDynamicExpressionsModule: expected_array_type

function _loss(
    ::AbstractArray{T1}, ::AbstractArray{T2}, ::LT
) where {T1,T2,LT<:Union{Function,SupervisedLoss}}
    return error(
        "Element type of `x` is $(T1) is different from element type of `y` which is $(T2)."
    )
end
function _weighted_loss(
    ::AbstractArray{T1}, ::AbstractArray{T2}, ::AbstractArray{T3}, ::LT
) where {T1,T2,T3,LT<:Union{Function,SupervisedLoss}}
    return error(
        "Element type of `x` is $(T1), element type of `y` is $(T2), and element type of `w` is $(T3). " *
        "All element types must be the same.",
    )
end

function _loss(
    x::AbstractArray{T}, y::AbstractArray{T}, loss::LT
) where {T,LT<:Union{Function,SupervisedLoss}}
    if loss isa SupervisedLoss
        return LossFunctions.mean(loss, x, y)
    else
        l(i) = loss(x[i], y[i])
        return LossFunctions.mean(l, eachindex(x))
    end
end

function _weighted_loss(
    x::AbstractArray{T}, y::AbstractArray{T}, w::AbstractArray{T}, loss::LT
) where {T,LT<:Union{Function,SupervisedLoss}}
    if loss isa SupervisedLoss
        return sum(loss, x, y, w; normalize=true)
    else
        l(i) = loss(x[i], y[i], w[i])
        return sum(l, eachindex(x)) / sum(w)
    end
end

@stable(
    default_mode = "disable",
    default_union_limit = 2,
    begin
        function eval_tree_dispatch(
            tree::AbstractExpression, dataset::Dataset, options::AbstractOptions
        )
            A = expected_array_type(dataset.X, typeof(tree))
            out, complete = eval_tree_array(tree, dataset.X, options)
            if isnothing(out)
                return out, false
            else
                return out::A, complete::Bool
            end
        end
        function eval_tree_dispatch(
            tree::AbstractExpressionNode, dataset::Dataset, options::AbstractOptions
        )
            A = expected_array_type(dataset.X, typeof(tree))
            out, complete = eval_tree_array(tree, dataset.X, options)
            if isnothing(out)
                return out, false
            else
                return out::A, complete::Bool
            end
        end
    end
)

# Evaluate the loss of a particular expression on the input dataset.
function _eval_loss(
    tree::Union{AbstractExpression{T},AbstractExpressionNode{T}},
    dataset::Dataset{T,L},
    options::AbstractOptions,
    regularization::Bool,
)::L where {T<:DATA_TYPE,L<:LOSS_TYPE}
    (prediction, completion) = eval_tree_dispatch(tree, dataset, options)
    if !completion || isnothing(prediction)
        return L(Inf)
    end

    loss_val = if is_weighted(dataset)
        _weighted_loss(
            prediction,
            dataset.y::AbstractArray,
            dataset.weights,
            options.elementwise_loss,
        )
    else
        _loss(prediction, dataset.y::AbstractArray, options.elementwise_loss)
    end

    if regularization
        loss_val += dimensional_regularization(tree, dataset, options)
    end

    return loss_val
end

# This evaluates function F:
function evaluator(
    f::F,
    tree::Union{AbstractExpressionNode{T},AbstractExpression{T}},
    dataset::Dataset{T,L},
    options::AbstractOptions,
    idx,
)::L where {T<:DATA_TYPE,L<:LOSS_TYPE,F}
    full_dataset = get_full_dataset(dataset)
    idx = @something(idx, get_indices(dataset), Some(nothing))
    if hasmethod(f, typeof((tree, full_dataset, options, idx)))
        # If user defines method that accepts batching indices, we
        # can convert the BatchedDataset to the old version
        return f(tree, full_dataset, options, idx)
    else
        return f(tree, dataset, options)
    end
end

# Evaluate the loss of a particular expression on the input dataset.
function eval_loss(
    tree::Union{AbstractExpression{T},AbstractExpressionNode{T}},
    dataset::Dataset{T,L},
    options::AbstractOptions;
    regularization::Bool=true,
    idx=nothing,
)::L where {T<:DATA_TYPE,L<:LOSS_TYPE}
    loss_val = if !isnothing(options.loss_function)
        f = options.loss_function::Function
        inner_tree = tree isa AbstractExpression ? get_tree(tree) : tree
        evaluator(f, inner_tree, dataset, options, idx)
    elseif !isnothing(options.loss_function_expression)
        f = options.loss_function_expression::Function
        @assert tree isa AbstractExpression
        evaluator(f, tree, dataset, options, idx)
    else
        _eval_loss(tree, dataset, options, regularization)
    end

    return loss_val
end

# Just so we can pass either PopMember or Node here:
get_tree_from_member(t::Union{AbstractExpression,AbstractExpressionNode}) = t
get_tree_from_member(m) = m.tree
# Beware: this is a circular dependency situation...
# PopMember is using losses, but then we also want
# losses to use the PopMember's cached complexity for trees.
# TODO!

# Compute a cost which includes a complexity penalty in the loss
function loss_to_cost(
    loss::L,
    use_baseline::Bool,
    baseline::L,
    member,
    options::AbstractOptions,
    complexity::Union{Int,Nothing}=nothing,
)::L where {L<:LOSS_TYPE}
    # TODO: Come up with a more general normalization scheme.
    normalization = if baseline >= L(0.01) && use_baseline
        baseline
    else
        L(0.01)
    end
    loss_val = loss / normalization
    size = @something(complexity, compute_complexity(member, options))
    parsimony_term = size * options.parsimony
    loss_val += L(parsimony_term)

    return loss_val
end

# Score an equation
function eval_cost(
    dataset::Dataset{T,L},
    member,
    options::AbstractOptions;
    complexity::Union{Int,Nothing}=nothing,
)::Tuple{L,L} where {T<:DATA_TYPE,L<:LOSS_TYPE}
    result_loss = eval_loss(get_tree_from_member(member), dataset, options)
    cost = loss_to_cost(
        result_loss,
        dataset.use_baseline,
        dataset.baseline_loss,
        member,
        options,
        complexity,
    )
    return cost, result_loss
end

# Deprecated form
function score_func end

"""
    update_baseline_loss!(dataset::Dataset{T,L}, options::AbstractOptions) where {T<:DATA_TYPE,L<:LOSS_TYPE}

Update the baseline loss of the dataset using the loss function specified in `options`.
"""
function update_baseline_loss!(
    dataset::Dataset{T,L}, options::AbstractOptions
) where {T<:DATA_TYPE,L<:LOSS_TYPE}
    example_tree = create_expression(zero(T), options, dataset)
    # constructorof(options.node_type)(T; val=dataset.avg_y)
    # TODO: It could be that the loss function is not defined for this example type?
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
    tree::Union{AbstractExpression{T},AbstractExpressionNode{T}},
    dataset::Dataset{T,L},
    options::AbstractOptions,
) where {T<:DATA_TYPE,L<:LOSS_TYPE}
    if !violates_dimensional_constraints(tree, dataset, options)
        return zero(L)
    end
    return convert(L, something(options.dimensional_constraint_penalty, 1000))
end

end
