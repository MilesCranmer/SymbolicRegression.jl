module LossFunctionsModule

using Random: MersenneTwister
using StatsBase: StatsBase
using DynamicExpressions: Node
using LossFunctions: LossFunctions
using LossFunctions: SupervisedLoss
using ..InterfaceDynamicExpressionsModule: eval_tree_array
using ..CoreModule: Options, Dataset, DATA_TYPE, LOSS_TYPE
using ..ComplexityModule: compute_complexity
using ..DimensionalAnalysisModule: violates_dimensional_constraints

function _loss(
    x::AbstractArray{T}, y::AbstractArray{T}, loss::LT
) where {T<:DATA_TYPE,LT<:Union{Function,SupervisedLoss}}
    if LT <: SupervisedLoss
        return LossFunctions.mean(loss, x, y)
    else
        l(i) = loss(x[i], y[i])
        return LossFunctions.mean(l, eachindex(x))
    end
end

function _weighted_loss(
    x::AbstractArray{T}, y::AbstractArray{T}, w::AbstractArray{T}, loss::LT
) where {T<:DATA_TYPE,LT<:Union{Function,SupervisedLoss}}
    if LT <: SupervisedLoss
        return LossFunctions.sum(loss, x, y, w; normalize=true)
    else
        l(i) = loss(x[i], y[i], w[i])
        return sum(l, eachindex(x)) / sum(w)
    end
end

"""If any of the indices are `nothing`, just return."""
@inline function maybe_getindex(v, i...)
    if any(==(nothing), i)
        return v
    else
        return getindex(v, i...)
    end
end

# Evaluate the loss of a particular expression on the input dataset.
function _eval_loss(
    tree::Node{T}, 
    dataset::Dataset{T,L}, 
    options::Options, 
    regularization::Bool;
    partition=nothing,
    idx=nothing, 
)::L where {T<:DATA_TYPE,L<:LOSS_TYPE}

    (prediction, completion) = eval_tree_array(
        tree, maybe_getindex(dataset.X, :, idx), options
    )
    if !completion
        return L(Inf)
    end

    if options.allocation
        @assert partition !== nothing
        if options.eval_probability
            for i in 1:length(partition)-1
                partition_function = sum(prediction[partition[i]+1:partition[i+1]])
                prediction[partition[i]+1:partition[i+1]] = prediction[partition[i]+1:partition[i+1]] / partition_function
            end
        else
            for i in 1:length(partition)-1
                partition_function = sum(prediction[partition[i]+1:partition[i+1]])
                total_out_flow = sum(dataset.y[idx[partition[i]+1:partition[i+1]]]) 
                prediction[partition[i]+1:partition[i+1]] = prediction[partition[i]+1:partition[i+1]] / partition_function * total_out_flow
            end
        end
    end

    loss_val = if dataset.weighted
        _weighted_loss(
            prediction,
            maybe_getindex(dataset.y, idx),
            maybe_getindex(dataset.weights, idx),
            options.elementwise_loss,
        )
    else
        _loss(prediction, maybe_getindex(dataset.y, idx), options.elementwise_loss)
    end

    if regularization
        loss_val += dimensional_regularization(tree, dataset, options)
    end

    return loss_val
end

# This evaluates function F:
function evaluator(
    f::F, tree::Node{T}, dataset::Dataset{T,L}, options::Options, idx
)::L where {T<:DATA_TYPE,L<:LOSS_TYPE,F}
    if hasmethod(f, typeof((tree, dataset, options, idx)))
        # If user defines method that accepts batching indices:
        return f(tree, dataset, options, idx)
    elseif options.batching
        error(
            "User-defined loss function must accept batching indices if `options.batching == true`. " *
            "For example, `f(tree, dataset, options, idx)`, where `idx` " *
            "is `nothing` if full dataset is to be used, " *
            "and a vector of indices otherwise.",
        )
    else
        return f(tree, dataset, options)
    end
end

# Evaluate the loss of a particular expression on the input dataset.
function eval_loss(
    tree::Node{T},
    dataset::Dataset{T,L},
    options::Options;
    regularization::Bool=true,
    idx = nothing,
)::L where {T<:DATA_TYPE,L<:LOSS_TYPE}
    if options.allocation
        id_origins = idx === nothing ? collect(1:options.num_places) : idx
        id_data = Vector{Int}()
        partition = Vector{Int}()
        push!(partition, 0)
        for id_origin in id_origins
            id_data_ori = (options.ori_sep[id_origin]+1) : options.ori_sep[id_origin+1]
            append!(id_data, id_data_ori)
            push!(partition, length(id_data))
        end
    else
        id_data = idx
        partition = nothing
    end

    loss_val = if options.loss_function === nothing
        _eval_loss(tree, dataset, options, regularization, partition = partition, idx = id_data)
    else
        f = options.loss_function::Function # zwy: here :: is an assertion of type
        evaluator(f, tree, dataset, options, id_data) # zwy: not modify this condition
    end
    return loss_val
end

function eval_loss_batched(
    tree::Node{T},
    dataset::Dataset{T,L},
    options::Options;
    regularization::Bool=true,
    idx=nothing,
)::L where {T<:DATA_TYPE,L<:LOSS_TYPE}
    _idx = idx === nothing ? batch_sample(dataset, options) : idx
    return eval_loss(tree, dataset, options; regularization=regularization, idx=_idx)
end

function batch_sample(dataset, options)
    if options.allocation
        batch = StatsBase.sample(1:(options.num_places), options.batch_size; replace=true)::Vector{Int}
    else
        batch = StatsBase.sample(1:(dataset.n), options.batch_size; replace=true)::Vector{Int}
    end 
    return batch
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
    dataset::Dataset{T,L}, member, options::Options; complexity::Union{Int,Nothing}=nothing
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
function score_func_batched(
    dataset::Dataset{T,L},
    member,
    options::Options;
    complexity::Union{Int,Nothing}=nothing,
    idx=nothing,
)::Tuple{L,L} where {T<:DATA_TYPE,L<:LOSS_TYPE}
    result_loss = eval_loss_batched(get_tree(member), dataset, options; idx=idx)
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
    example_tree = Node(T; val=dataset.avg_y) # zwy: T is data type, avg_y is a attribute
    baseline_loss = eval_loss(example_tree, dataset, options)
    if isfinite(baseline_loss)
        dataset.baseline_loss = baseline_loss
        dataset.use_baseline = true
    else
        dataset.baseline_loss = one(L) # zwy: one(L) 会返回L数据类型下的1，作为常数.
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
