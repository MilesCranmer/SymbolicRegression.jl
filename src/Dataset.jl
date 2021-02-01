struct Dataset{T<:Real}

    X::AbstractMatrix{T}
    y::AbstractVector{T}
    n::Int
    nfeatures::Int
    weighted::Bool
    weights::Union{AbstractVector{T}, Nothing}
    varMap::Array{String, 1}

end

function Dataset(
        X::AbstractMatrix{T},
        y::AbstractVector{T};
        weights::Union{AbstractVector{T}, Nothing}=nothing,
        varMap::Union{Array{String, 1}, Nothing}=nothing
       ) where {T<:Real}

    n = size(X, 2)
    nfeatures = size(X, 1)
    weighted = true
    if weights == nothing
        weighted = false
    end
    if varMap == nothing
        varMap = ["x$(i)" for i=1:nfeatures]
    end

    return Dataset{T}(X, y, n, nfeatures, weighted, weights, varMap)

end

