module DatasetModule

using DynamicQuantities: Quantity

using ..UtilsModule: subscriptify, get_base_type, @constfield
using ..ProgramConstantsModule: BATCH_DIM, FEATURE_DIM, DATA_TYPE, LOSS_TYPE
using ...InterfaceDynamicQuantitiesModule: get_si_units, get_sym_units

import ...deprecate_varmap

"""
    Dataset{T<:DATA_TYPE,L<:LOSS_TYPE}

# Fields

- `X::AbstractMatrix{T}`: The input features, with shape `(nfeatures, n)`.
- `y::AbstractVector{T}`: The desired output values, with shape `(n,)`.
- `index::Int`: The index of the output feature corresponding to this
    dataset, if any.
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
- `display_variable_names::Array{String,1}`: A version of `variable_names`
    but for printing to the terminal (e.g., with unicode versions).
- `y_variable_name::String`: The name of the output variable.
- `X_units`: Unit information of `X`. When used, this is a vector
    of `DynamicQuantities.Quantity{<:Any,<:Dimensions}` with shape `(nfeatures,)`.
- `y_units`: Unit information of `y`. When used, this is a single
    `DynamicQuantities.Quantity{<:Any,<:Dimensions}`.
- `X_sym_units`: Unit information of `X`. When used, this is a vector
    of `DynamicQuantities.Quantity{<:Any,<:SymbolicDimensions}` with shape `(nfeatures,)`.
- `y_sym_units`: Unit information of `y`. When used, this is a single
    `DynamicQuantities.Quantity{<:Any,<:SymbolicDimensions}`.
"""
mutable struct Dataset{
    T<:DATA_TYPE,
    L<:LOSS_TYPE,
    AX<:AbstractMatrix{T},
    AY<:Union{AbstractVector{T},Nothing},
    AW<:Union{AbstractVector{T},Nothing},
    NT<:NamedTuple,
    XU<:Union{AbstractVector{<:Quantity},Nothing},
    YU<:Union{Quantity,Nothing},
    XUS<:Union{AbstractVector{<:Quantity},Nothing},
    YUS<:Union{Quantity,Nothing},
}
    @constfield X::AX
    @constfield y::AY
    @constfield index::Int
    @constfield n::Int
    @constfield nfeatures::Int
    @constfield weighted::Bool
    @constfield weights::AW
    @constfield extra::NT
    @constfield avg_y::Union{T,Nothing}
    use_baseline::Bool
    baseline_loss::L
    @constfield variable_names::Array{String,1}
    @constfield display_variable_names::Array{String,1}
    @constfield y_variable_name::String
    @constfield X_units::XU
    @constfield y_units::YU
    @constfield X_sym_units::XUS
    @constfield y_sym_units::YUS
end

"""
    Dataset(X::AbstractMatrix{T},
            y::Union{AbstractVector{T},Nothing}=nothing,
            loss_type::Type=Nothing;
            weights::Union{AbstractVector{T}, Nothing}=nothing,
            variable_names::Union{Array{String, 1}, Nothing}=nothing,
            y_variable_name::Union{String,Nothing}=nothing,
            extra::NamedTuple=NamedTuple(),
            X_units::Union{AbstractVector, Nothing}=nothing,
            y_units=nothing,
    ) where {T<:DATA_TYPE}

Construct a dataset to pass between internal functions.
"""
function Dataset(
    X::AbstractMatrix{T},
    y::Union{AbstractVector{T},Nothing}=nothing,
    loss_type::Type{L}=Nothing;
    index::Int=1,
    weights::Union{AbstractVector{T},Nothing}=nothing,
    variable_names::Union{Array{String,1},Nothing}=nothing,
    display_variable_names=variable_names,
    y_variable_name::Union{String,Nothing}=nothing,
    extra::NamedTuple=NamedTuple(),
    X_units::Union{AbstractVector,Nothing}=nothing,
    y_units=nothing,
    # Deprecated:
    varMap=nothing,
    kws...,
) where {T<:DATA_TYPE,L}
    Base.require_one_based_indexing(X)
    y !== nothing && Base.require_one_based_indexing(y)
    # Deprecation warning:
    variable_names = deprecate_varmap(variable_names, varMap, :Dataset)
    if haskey(kws, :loss_type)
        Base.depwarn(
            "The `loss_type` keyword argument is deprecated. Pass as an argument instead.",
            :Dataset,
        )
        return Dataset(
            X,
            y,
            kws[:loss_type];
            index,
            weights,
            variable_names,
            display_variable_names,
            y_variable_name,
            extra,
            X_units,
            y_units,
        )
    end

    n = size(X, BATCH_DIM)
    nfeatures = size(X, FEATURE_DIM)
    weighted = weights !== nothing
    variable_names = if variable_names === nothing
        ["x$(i)" for i in 1:nfeatures]
    else
        variable_names
    end
    display_variable_names = if display_variable_names === nothing
        ["x$(subscriptify(i))" for i in 1:nfeatures]
    else
        display_variable_names
    end

    y_variable_name = if y_variable_name === nothing
        ("y" ∉ variable_names) ? "y" : "target"
    else
        y_variable_name
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
    out_loss_type = if L === Nothing
        T <: Complex ? get_base_type(T) : T
    else
        L
    end

    use_baseline = true
    baseline = one(out_loss_type)
    y_si_units = get_si_units(T, y_units)
    y_sym_units = get_sym_units(T, y_units)

    # TODO: Refactor
    # This basically just ensures that if the `y` units are set,
    # then the `X` units are set as well.
    X_si_units = let (_X = get_si_units(T, X_units))
        if _X === nothing && y_si_units !== nothing
            get_si_units(T, [one(T) for _ in 1:nfeatures])
        else
            _X
        end
    end
    X_sym_units = let _X = get_sym_units(T, X_units)
        if _X === nothing && y_sym_units !== nothing
            get_sym_units(T, [one(T) for _ in 1:nfeatures])
        else
            _X
        end
    end

    error_on_mismatched_size(nfeatures, X_si_units)

    return Dataset{
        T,
        out_loss_type,
        typeof(X),
        typeof(y),
        typeof(weights),
        typeof(extra),
        typeof(X_si_units),
        typeof(y_si_units),
        typeof(X_sym_units),
        typeof(y_sym_units),
    }(
        X,
        y,
        index,
        n,
        nfeatures,
        weighted,
        weights,
        extra,
        avg_y,
        use_baseline,
        baseline,
        variable_names,
        display_variable_names,
        y_variable_name,
        X_si_units,
        y_si_units,
        X_sym_units,
        y_sym_units,
    )
end
function Dataset(
    X::AbstractMatrix,
    y::Union{<:AbstractVector,Nothing}=nothing;
    weights::Union{<:AbstractVector,Nothing}=nothing,
    kws...,
)
    T = promote_type(
        eltype(X),
        (y === nothing) ? eltype(X) : eltype(y),
        (weights === nothing) ? eltype(X) : eltype(weights),
    )
    X = Base.Fix1(convert, T).(X)
    if y !== nothing
        y = Base.Fix1(convert, T).(y)
    end
    if weights !== nothing
        weights = Base.Fix1(convert, T).(weights)
    end
    return Dataset(X, y; weights=weights, kws...)
end

function error_on_mismatched_size(_, ::Nothing)
    return nothing
end
function error_on_mismatched_size(nfeatures, X_units::AbstractVector)
    if nfeatures != length(X_units)
        error(
            "Number of features ($(nfeatures)) does not match number of units ($(length(X_units)))",
        )
    end
    return nothing
end

function has_units(dataset::Dataset)
    return dataset.X_units !== nothing || dataset.y_units !== nothing
end

# Used for Enzyme
function Base.fill!(d::Dataset, val)
    _fill!(d.X, val)
    _fill!(d.y, val)
    _fill!(d.weights, val)
    _fill!(d.extra, val)
    return d
end
_fill!(x::AbstractArray, val) = fill!(x, val)
_fill!(x::NamedTuple, val) = foreach(v -> _fill!(v, val), values(x))
_fill!(::Nothing, val) = nothing
_fill!(x, val) = x

end
