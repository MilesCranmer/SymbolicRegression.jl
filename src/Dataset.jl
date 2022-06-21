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
    noise::Union{AbstractArray{T, 3},Nothing}  # If using noisy nodes
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
    noise::Union{AbstractArray{T,3},Nothing}=nothing,
) where {T<:Real}
    Base.require_one_based_indexing(X, y)
    n = size(X, BATCH_DIM)
    nfeatures = size(X, FEATURE_DIM)
    weighted = weights !== nothing
    if varMap === nothing
        varMap = ["x$(i)" for i in 1:nfeatures]
    end

    return Dataset{T}(X, y, n, nfeatures, weighted, weights, varMap, noise)
end

end
