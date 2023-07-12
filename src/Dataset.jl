module DatasetModule

import DynamicQuantities:
    Dimensions, Quantity, uparse, ustrip, DEFAULT_DIM_BASE_TYPE

import ..UtilsModule: subscriptify
import ..ProgramConstantsModule: BATCH_DIM, FEATURE_DIM, DATA_TYPE, LOSS_TYPE
#! format: off
import ...deprecate_varmap
#! format: on

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
- `variable_names::Array{String,1}`: The names of the features,
    with shape `(nfeatures,)`.
- `pretty_variable_names::Array{String,1}`: A version of `variable_names`
    but for printing to the terminal (e.g., with unicode versions).
- `units`: Unit information. When used, this is a NamedTuple with fields
    corresponding to `:X` (vector of DynamicQuantities.Dimensions) and `:y`
    (single DynamicQuantities.Dimensions).
"""
mutable struct Dataset{
    T<:DATA_TYPE,
    L<:LOSS_TYPE,
    AX<:AbstractMatrix{T},
    AY<:Union{AbstractVector{T},Nothing},
    AW<:Union{AbstractVector{T},Nothing},
    NT<:NamedTuple,
    U<:Union{NamedTuple,Nothing},
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
    variable_names::Array{String,1}
    pretty_variable_names::Array{String,1}
    units::U
end

"""
    Dataset(X::AbstractMatrix{T}, y::Union{AbstractVector{T},Nothing}=nothing;
            weights::Union{AbstractVector{T}, Nothing}=nothing,
            variable_names::Union{Array{String, 1}, Nothing}=nothing,
            units::Union{NamedTuple, Nothing}=nothing,
            extra::NamedTuple=NamedTuple(),
            loss_type::Type=Nothing,
    )

Construct a dataset to pass between internal functions.
"""
function Dataset(
    X::AbstractMatrix{T},
    y::Union{AbstractVector{T},Nothing}=nothing;
    weights::Union{AbstractVector{T},Nothing}=nothing,
    variable_names::Union{Array{String,1},Nothing}=nothing,
    units::Union{NamedTuple,Nothing}=nothing,
    extra::NamedTuple=NamedTuple(),
    loss_type::Type=Nothing,
    # Deprecated:
    varMap=nothing,
) where {T<:DATA_TYPE}
    Base.require_one_based_indexing(X)
    y !== nothing && Base.require_one_based_indexing(y)
    # Deprecation warning:
    variable_names = deprecate_varmap(variable_names, varMap, :Dataset)

    n = size(X, BATCH_DIM)
    nfeatures = size(X, FEATURE_DIM)
    weighted = weights !== nothing
    (variable_names, pretty_variable_names) = if variable_names === nothing
        ["x$(i)" for i in 1:nfeatures], ["x$(subscriptify(i))" for i in 1:nfeatures]
    else
        (variable_names, variable_names)
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
    si_units = get_units(T, Dimensions, units, uparse)
    error_on_mismatched_size(nfeatures, si_units)
    convert_to_si_units!(X, y, si_units)

    return Dataset{
        T,
        loss_type,
        typeof(X),
        typeof(y),
        typeof(weights),
        typeof(extra),
        typeof(si_units),
    }(
        X,
        y,
        n,
        nfeatures,
        weighted,
        weights,
        extra,
        avg_y,
        use_baseline,
        baseline,
        variable_names,
        pretty_variable_names,
        si_units,
    )
end
function Dataset(
    X::AbstractMatrix,
    y::Union{<:AbstractVector,Nothing}=nothing;
    weights::Union{<:AbstractVector,Nothing}=nothing,
    kws...
)
    T = promote_type(eltype(X), (y === nothing) ? eltype(X) : eltype(y), (weights === nothing) ? eltype(X) : eltype(weights))
    X = Base.Fix1(convert, T).(X)
    if y !== nothing
        y = Base.Fix1(convert, T).(y)
    end
    if weights !== nothing
        weights = Base.Fix1(convert, T).(weights)
    end
    return Dataset(X, y; weights=weights, kws...)
end

# Base
function get_units(_, _, ::Nothing, ::Function)
    return nothing
end
function get_units(::Type{T}, ::Type{D}, x::AbstractString, f::Function) where {T,D}
    return convert(Quantity{T,D}, f(x))
end
function get_units(::Type{T}, ::Type{D}, x::Quantity, ::Function) where {T,D}
    return convert(Quantity{T,D}, x)
end
function get_units(::Type{T}, ::Type{D}, x::Dimensions, ::Function) where {T,D}
    return Quantity(one(T), x)
end
function get_units(::Type{T}, ::Type{D}, x::Number, ::Function) where {T,D}
    return Quantity(convert(T, x), D)
end

# Derived
function get_units(::Type{T}, ::Type{D}, x::AbstractVector, f::Function) where {T,D}
    return Quantity{T,D{DEFAULT_DIM_BASE_TYPE}}[get_units(T, D, xi, f) for xi in x]
end
function get_units(::Type{T}, ::Type{D}, x::NamedTuple, f::Function) where {T,D}
    return NamedTuple((k => get_units(T, D, x[k], f) for k in keys(x)))
end

error_on_mismatched_size(nfeatures, ::Nothing) = nothing
function error_on_mismatched_size(nfeatures, units::NamedTuple)
    haskey(units, :X) &&
        nfeatures != length(units.X) &&
        error(
            "Number of features ($(nfeatures)) does not match number of units ($(length(units.X)))",
        )
    return nothing
end

"""
    convert_to_si_units!(X, y, si_units)

Convert both X and y to their SI base units, in-place (if units are provided).
"""
function convert_to_si_units!(X, y, si_units)
    if si_units !== nothing
        for (ux, x) in zip(si_units.X, eachrow(X))
            x .*= ustrip(ux)
        end
        y .*= ustrip(si_units.y)
    end
    return nothing
end

end
