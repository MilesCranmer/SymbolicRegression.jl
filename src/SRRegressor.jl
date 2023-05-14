module SRRegressorModule

import ..CoreModule: Options, LOSS_TYPE, DATA_TYPE
import ..HallOfFameModule: HallOfFame
import ..SearchUtilsModule: StateType
#! format: off
import ..equation_search
#! format: on

mutable struct SRRegressor{OPT<:Options}
    options::OPT
    niterations::Int
    warm_start::Bool
    hall_of_fame::Union{Nothing,Vector{HallOfFame{T,L} where {T,L}}}
    state::Union{Nothing,StateType}
end
function SRRegressor(args...; kwargs...)
    niterations = 10
    warm_start = false
    haskey(kwargs, :niterations) &&
        (niterations = kwargs[:niterations]; delete!(kwargs, :niterations))
    haskey(kwargs, :warm_start) &&
        (warm_start = kwargs[:warm_start]; delete!(kwargs, :warm_start))
    haskey(kwargs, :return_state) && (
        throw(
            ArgumentError(
                "return_state is not a valid keyword argument for SRRegressor. Use `warm_start` instead.",
            ),
        );
        delete!(kwargs, :return_state)
    )
    return SRRegressor(
        Options(; return_state=true, kwargs...), niterations, warm_start, nothing, nothing
    )
end

function fit!(
    m::SRRegressor,
    X::AbstractMatrix,
    y::Union{Nothing,AbstractVecOrMat}=nothing,
    w::Union{Nothing,AbstractVector}=nothing;
    kwargs...,
)
    saved_state = if m.warm_start && m.state !== nothing
        m.state
    else
        nothing
    end
    (state, hof) = equation_search(
        X,
        y;
        options=m.options,
        niterations=m.niterations,
        weights=w,
        saved_state,
        kwargs...,
    )
    m.hall_of_fame = if hof isa Vector
        hof
    else
        [hof]
    end
    m.state = (state, hof)
    return m
end
function fit(m::SRRegressor, args...; kwargs...)
    inner_regressor = deepcopy(m)
    return fit!(inner_regressor, args...; kwargs...)
end

end
