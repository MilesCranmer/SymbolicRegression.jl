module DatasetModule

import ..ProgramConstantsModule: BATCH_DIM, FEATURE_DIM

"""
    Dataset{T<:Real}

# Fields

- `X::AbstractMatrix{T}`: The input features, with shape `(nfeatures, n)`.
- `y::AbstractVector{T}`: The desired output values, with shape `(n,)`.
- `n::Int`: The number of samples.
- `nfeatures::Int`: The number of features.
- `weighted::Bool`: Whether the dataset is non-uniformly weighted.
- `weights::Union{AbstractVector{T},Nothing}`: If the dataset is weighted,
    these specify the per-sample weight (with shape `(n,)`).
- `avg_y`: The average value of `y` (weighted, if `weights` are passed).
- `baseline_loss`: The loss of a constant function which predicts the average
    value of `y`. This is loss-dependent and should be updated with
    `update_baseline_loss!`.
- `varMap::Array{String,1}`: The names of the features,
    with shape `(nfeatures,)`.
"""
mutable struct Dataset{T<:Real}
    X::AbstractMatrix{T}
    y::AbstractVector{T}
    n::Int
    nfeatures::Int
    weighted::Bool
    weights::Union{AbstractVector{T},Nothing}
    avg_y::T
    baseline_loss::T
    varMap::Array{String,1}
end

"""
    Dataset(X::AbstractMatrix{T}, y::AbstractVector{T};
            weights::Union{AbstractVector{T}, Nothing}=nothing,
            varMap::Union{Array{String, 1}, Nothing}=nothing)

Construct a dataset to pass between internal functions.
"""
function Dataset(
    X::AbstractMatrix{T},
    y::AbstractVector{T};
    weights::Union{AbstractVector{T},Nothing}=nothing,
    varMap::Union{Array{String,1},Nothing}=nothing,
) where {T<:Real}
    Base.require_one_based_indexing(X, y)
    n = size(X, BATCH_DIM)
    nfeatures = size(X, FEATURE_DIM)
    weighted = weights !== nothing
    if varMap === nothing
        varMap = ["x$(i)" for i in 1:nfeatures]
    end
    avg_y = if weighted
        sum(y .* weights) / sum(weights)
    else
        sum(y) / n
    end
    baseline = one(T)

    return Dataset{T}(X, y, n, nfeatures, weighted, weights, avg_y, baseline, varMap)
end

end
