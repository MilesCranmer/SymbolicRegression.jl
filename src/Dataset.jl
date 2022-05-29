module DatasetModule

import ..ProgramConstantsModule: BATCH_DIM, FEATURE_DIM

struct Dataset{X_type,y_type}
    X::X_type
    y::y_type
    abstract::Bool
    n::Int
    nfeatures::Int
    weighted::Bool
    weights::Union{y_type,Nothing}
    varMap::Array{String,1}
end

"""
    Dataset(X::AbstractMatrix{T}, y::AbstractVector{T};
            weights::Union{AbstractVector{T}, Nothing}=nothing,
            varMap::Union{Array{String, 1}, Nothing}=nothing)

Construct a dataset to pass between internal functions.
"""
function Dataset(
    X::X_type,
    y::y_type;
    weights::Union{y_type,Nothing}=nothing,
    varMap::Union{Array{String,1},Nothing}=nothing,
) where {X_type,y_type}
    if X_type <: AbstractMatrix && y_type <: AbstractVector
        Base.require_one_based_indexing(X, y)
        n = size(X, BATCH_DIM)
        nfeatures = size(X, FEATURE_DIM)
        weighted = weights !== nothing
        if varMap === nothing
            varMap = ["x$(i)" for i in 1:nfeatures]
        end
        return Dataset{X_type,y_type}(X, y, false, n, nfeatures, weighted, weights, varMap)
    else
        println("Assuming abstract dataset.")
        @assert weights === nothing
        @assert varMap === nothing
        return Dataset{X_type,y_type}(X, y, true, 0, 0, false, nothing, String[])
    end
end

end
