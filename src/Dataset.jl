using FromFile
@from "ProgramConstants.jl" import BATCH_DIM, FEATURE_DIM

struct Dataset{T<:Real}

    X::AbstractMatrix{T}
    y::AbstractArray{T}
    nexample::Int
    noutput::Int
    nfeatures::Int
    weighted::Bool
    weights::Union{AbstractVector{T}, Nothing}
    varMap::Array{String, 1}

end

"""
    Dataset(X::AbstractMatrix{T}, y::AbstractVector{T};
            weights::Union{AbstractVector{T}, Nothing}=nothing,
            varMap::Union{Array{String, 1}, Nothing}=nothing)

Construct a dataset to pass between internal functions.
"""
function Dataset(
        X::AbstractMatrix{T},
        y::AbstractArray{T};
        weights::Union{AbstractVector{T}, Nothing}=nothing,
        varMap::Union{Array{String, 1}, Nothing}=nothing
       ) where {T<:Real}

    @assert size(X, BATCH_DIM)==size(y, BATCH_DIM) "The number of input and output example has to be the same."

    nexample = size(X, BATCH_DIM)
    nfeatures = size(X, FEATURE_DIM)
    noutput = size(y, FEATURE_DIM)
    weighted = weights !== nothing
    if varMap == nothing
        varMap = ["x$(i)" for i=1:nfeatures]
    end

    return Dataset{T}(X, y, nexample, noutput, nfeatures, weighted, weights, varMap)

end

