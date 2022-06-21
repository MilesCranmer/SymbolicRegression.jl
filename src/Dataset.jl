module DatasetModule

import ..ProgramConstantsModule: BATCH_DIM, FEATURE_DIM

struct Dataset{T<:Real}
    X::AbstractMatrix{T}
    y::AbstractVector{T}
    n::Int
    nfeatures::Int
    weighted::Bool
    weights::Union{AbstractVector{T},Nothing}
    varMap::Array{String,1}
    noise::Union{AbstractArray{T,2},Nothing}  # If using noisy nodes
    X_true_resampled::Union{AbstractMatrix{T},Nothing}
    y_true_resampled::Union{AbstractVector{T},Nothing}
    X_pred_resampled::Union{AbstractMatrix{T},Nothing}
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
    noise::Union{AbstractArray{T,2},Nothing}=nothing,
    rand_true_idx::Union{Vector{Int},Nothing}=nothing,
    rand_pred_idx::Union{Vector{Int},Nothing}=nothing,
) where {T<:Real}
    Base.require_one_based_indexing(X, y)
    n = size(X, BATCH_DIM)
    nfeatures = size(X, FEATURE_DIM)
    weighted = weights !== nothing
    if varMap === nothing
        varMap = ["x$(i)" for i in 1:nfeatures]
    end
    if rand_pred_idx !== nothing
        X_true_resampled = view(X, :, rand_true_idx)
        y_true_resampled = view(y, rand_pred_idx)
        X_pred_resampled = view(X, :, rand_pred_idx)
    else
        X_true_resampled = nothing
        y_true_resampled = nothing
        X_pred_resampled = nothing
    end

    return Dataset{T}(
        X,
        y,
        n,
        nfeatures,
        weighted,
        weights,
        varMap,
        noise,
        X_true_resampled,
        y_true_resampled,
        X_pred_resampled,
    )
end

end
