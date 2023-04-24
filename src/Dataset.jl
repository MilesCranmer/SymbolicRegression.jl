module DatasetModule

import ..ProgramConstantsModule: BATCH_DIM, FEATURE_DIM, DATA_TYPE, LOSS_TYPE

"""
    Dataset{T<:DATA_TYPE,L<:LOSS_TYPE}

# Fields

- `X::AbstractMatrix{T}`: The input features, with shape `(nfeatures, n)`.
- `y::AbstractVector{T}`: The desired output values, with shape `(n,)`.
- `n::Int`: The number of samples.
- `nfeatures::Int`: The number of features.
- `weighted::Bool`: Whether the dataset is non-uniformly weighted.
- `weights::Union{AbstractVector{T},Nothing}`: If the dataset is weighted,
    these specify the per-sample weight (with shape `(n,)`).
- `extra::NamedTuple`: Extra information to pass to a custom evaluation
    function. Since this is an arbitrary named tuple, you could pass
    any sort of dataset you wish to here.
- `avg_y`: The average value of `y` (weighted, if `weights` are passed).
- `use_baseline`: Whether to use a baseline loss. This will be set to `false`
    if the baseline loss is calculated to be `Inf`.
- `baseline_loss`: The loss of a constant function which predicts the average
    value of `y`. This is loss-dependent and should be updated with
    `update_baseline_loss!`.
- `varMap::Array{String,1}`: The names of the features,
    with shape `(nfeatures,)`.
"""
mutable struct Dataset{
    T<:DATA_TYPE,
    L<:LOSS_TYPE,
    AX<:AbstractMatrix{T},
    AY<:Union{AbstractVector{T},Nothing},
    AW<:Union{AbstractVector{T},Nothing},
    NT<:NamedTuple,
}
    X::AX
    y::AY
    n::Int
    nfeatures::Int
    weighted::Bool
    weights::AW
    extra::NT
    avg_y::Union{T,Nothing}
    use_baseline::Bool
    baseline_loss::L
    varMap::Array{String,1}
end

"""
    Dataset(X::AbstractMatrix{T}, y::Union{AbstractVector{T},Nothing}=nothing;
            weights::Union{AbstractVector{T}, Nothing}=nothing,
            varMap::Union{Array{String, 1}, Nothing}=nothing,
            extra::NamedTuple=NamedTuple(),
            loss_type::Type=Nothing)

Construct a dataset to pass between internal functions.
"""
function Dataset(
    X::AbstractMatrix{T},
    y::Union{AbstractVector{T},Nothing}=nothing;
    weights::Union{AbstractVector{T},Nothing}=nothing,
    varMap::Union{Array{String,1},Nothing}=nothing,
    extra::NamedTuple=NamedTuple(),
    loss_type::Type=Nothing,
) where {T<:DATA_TYPE}
    Base.require_one_based_indexing(X)
    y !== nothing && Base.require_one_based_indexing(y)

    n = size(X, BATCH_DIM)
    nfeatures = size(X, FEATURE_DIM)
    weighted = weights !== nothing
    if varMap === nothing
        varMap = ["x$(i)" for i in 1:nfeatures]
    end
    avg_y = if y === nothing
        nothing
    else
        if weighted
            sum(y .* weights) / sum(weights)
        else
            sum(y) / n
        end
    end
    loss_type = (loss_type == Nothing) ? T : loss_type
    use_baseline = true
    baseline = one(loss_type)

    return Dataset{T,loss_type,typeof(X),typeof(y),typeof(weights),typeof(extra)}(
        X, y, n, nfeatures, weighted, weights, extra, avg_y, use_baseline, baseline, varMap
    )
end

end
