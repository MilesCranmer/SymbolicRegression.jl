module DatasetModule

import DynamicQuantities: Dimensions, Quantity, uparse, ustrip

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
    units::U
end

"""
    Dataset(X::AbstractMatrix{T}, y::Union{AbstractVector{T},Nothing}=nothing;
            weights::Union{AbstractVector{T}, Nothing}=nothing,
            variable_names::Union{Array{String, 1}, Nothing}=nothing,
            extra::NamedTuple=NamedTuple(),
            loss_type::Type=Nothing,
            units::Union{NamedTuple, Nothing}=nothing,
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
    if variable_names === nothing
        variable_names = ["x$(i)" for i in 1:nfeatures]
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
    _units = get_units(T, units)
    warn_on_non_si_units(_units)

    return Dataset{
        T,loss_type,typeof(X),typeof(y),typeof(weights),typeof(extra),typeof(_units)
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
        _units,
    )
end

d_eltype(::Dimensions{R}) where {R} = R
const DEFAULT_DIM = Dimensions()
const DEFAULT_DIM_TYPE = d_eltype(DEFAULT_DIM)

#! format: off
get_units(_, ::Nothing) = nothing
get_units(::Type{T}, x::AbstractString) where {T} = convert(Quantity{T,DEFAULT_DIM_TYPE}, uparse(x))
get_units(::Type{T}, x::Quantity) where {T} = convert(Quantity{T,DEFAULT_DIM_TYPE}, x)
get_units(::Type{T}, x::Dimensions) where {T} = convert(Quantity{T,DEFAULT_DIM_TYPE}, 1.0 * x)
get_units(::Type{T}, x::Number) where {T} = Quantity(convert(T, x), DEFAULT_DIM)

get_units(::Type{T}, x::AbstractVector) where {T} = Quantity{T,DEFAULT_DIM_TYPE}[get_units(T, xi) for xi in x]
get_units(::Type{T}, x::NamedTuple) where {T} = NamedTuple((k => get_units(T, x[k]) for k in keys(x)))
#! format: on

warn_on_non_si_units(::Nothing) = nothing
function warn_on_non_si_units(vq::NamedTuple)
    container = Quantity[]
    for k in keys(vq)
        v = vq[k]
        if isa(v, Quantity)
            push!(container, v)
        elseif isa(v, AbstractVector)
            append!(container, v)
        else
            error("Unknown type: $(typeof(v))")
        end
    end
    return warn_on_non_si_units(container)
end
function warn_on_non_si_units(vq::AbstractVector{<:Quantity})
    if any(!isone ∘ ustrip, vq)
        @warn "Some of your units are not in their base SI representation. While dimensional analysis will work normally, note that the scale of specific units is not taken into account when evaluating the equation. If you would like to obtain an equation that takes into account the scale of your units (e.g., `meters/kilometers == 1/1000`), please precompute this by converting your data to the base SI units before input."
    end
    return nothing
end

end
