@testitem "Custom units" tags = [:part3] begin
    using SymbolicRegression
    using SymbolicRegression.InterfaceDynamicQuantitiesModule: get_units, get_si_units
    using SymbolicRegression.MLJInterfaceModule: clean_units
    using DynamicQuantities
    using Random: MersenneTwister
    using MLJBase

    struct AngleDimensions{R} <: AbstractDimensions{R}
        length::R
        mass::R
        time::R
        current::R
        temperature::R
        luminosity::R
        amount::R
        rad::R
    end
    function Base.promote_rule(
        ::Type{AngleDimensions{R1}}, ::Type{Dimensions{R2}}
    ) where {R1,R2}
        return AngleDimensions{promote_type(R1, R2)}
    end
    function Base.convert(
        ::Type{Quantity{T,AngleDimensions{R}}}, q::Quantity{<:Any,<:Dimensions}
    ) where {T,R}
        val = ustrip(q)
        d = dimension(q)
        return Quantity(
            T(val),
            AngleDimensions{R}(;
                d.length,
                d.mass,
                d.time,
                d.current,
                d.temperature,
                d.luminosity,
                d.amount,
                angle=zero(R),
            ),
        )
    end

    const kg = Quantity(1.0, AngleDimensions(; mass=1))
    const rad = Quantity(1.0, AngleDimensions(; rad=1))

    rng = MersenneTwister(0)
    X = (; m₁=rand(rng, 100) * kg, θ₁=rand(rng, 100) * rad)
    y = @. cos(X.m₁ / kg) / X.θ₁

    # function get_si_units(::Type{T}, units) where {T}
    #     return get_units(T, Dimensions{DEFAULT_DIM_BASE_TYPE}, units, uparse)
    # end
    get_si_units(Float64, [dimension(y)])

    # The true solution should have that extra constant to cancel out kg.
    # model = SRRegressor(
    #     binary_operators=[+, *, -, /],
    #     unary_operators=[cos, exp]
    # )
    # mach = machine(model, X, y)
    # fit!(mach)
    # ŷ = predict(mach, X)
    # @test ŷ ≈ y
end
