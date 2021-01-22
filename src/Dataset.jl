struct Dataset{T} where {T<:Real}

    X::AbstractMatrix{T}
    y::AbstractVector{T}
    n::Int
    nfeatures::Int
    weighted::Bool
    weights::Union{AbstractVector{T}, nothing}
    varMap::Array{String, 1}
    useVarMap::Array{String, 1}

end

function Dataset(;
        X::AbstractMatrix{T},
        y::AbstractVector{T},
        weights::Union{AbstractVector{T}, nothing}=nothing,
        varMap=nothing
   ) where {T<:Real}

    n = length(X)
    nfeatures = size(X)[2]
    weighted = true
    if weights == nothing
        weighted = false
    end
    if varMap == nothing
        varMap = ["x$(i)" for i=1:nfeatures]
    end

    return Dataset{T}(X, y, n, nfeatures, weighted, weights, varMap)

end

