@testitem "Constant optimization with custom types (Issue #568)" begin
    using SymbolicRegression
    using DynamicExpressions
    using Random: AbstractRNG
    using MLJBase: machine, fit!, report

    # Custom vector type that packs two Float64s as a single "constant"
    struct MyVec2
        x::Float64
        y::Float64
    end

    # Required interface for custom types
    Base.zero(::Type{MyVec2}) = MyVec2(0.0, 0.0)
    Base.eltype(::Type{MyVec2}) = Float64

    # DynamicExpressions interface for constant optimization
    DynamicExpressions.count_scalar_constants(::MyVec2) = 2
    DynamicExpressions.get_number_type(::Type{MyVec2}) = Float64

    function DynamicExpressions.pack_scalar_constants!(
        nvals::AbstractVector{<:Number}, idx::Int, value::MyVec2
    )
        nvals[idx] = value.x
        nvals[idx + 1] = value.y
        return idx + 2
    end

    function DynamicExpressions.unpack_scalar_constants(
        nvals::AbstractVector{<:Number}, idx::Int, ::MyVec2
    )
        return (idx + 2, MyVec2(Float64(nvals[idx]), Float64(nvals[idx + 1])))
    end

    # Define arithmetic for evolution
    Base.:(+)(a::MyVec2, b::MyVec2) = MyVec2(a.x + b.x, a.y + b.y)
    Base.:(*)(s::Real, v::MyVec2) = MyVec2(s * v.x, s * v.y)
    Base.abs2(v::MyVec2) = v.x^2 + v.y^2

    # Random value generator for initial constants
    SymbolicRegression.sample_value(rng::AbstractRNG, ::Type{MyVec2}, _) = MyVec2(
        rand(rng), rand(rng)
    )

    # Enable constant optimization for MyVec2
    SymbolicRegression.ConstantOptimizationModule.can_optimize(::Type{MyVec2}, _) = true

    # Create synthetic data: y = 2*x1 + 3*x2 where x1, x2 are MyVec2
    rng = Random.MersenneTwister(42)
    n = 50
    X = [MyVec2(rand(rng), rand(rng)) for _ in 1:n]
    # Target: coefficients 2.0 and 3.0 (will be stored as MyVec2 constants)
    y = [2.0 * abs2(x) + 3.0 * abs2(x) for x in X]

    model = SRRegressor(;
        binary_operators=(+,),
        unary_operators=(),
        maxsize=5,
        niterations=5,
        populations=1,
        population_size=10,
        optimizer_nrestarts=3,  # Key: must be > 0 to trigger the bug
        optimizer_options=(; iterations=10),
        loss_type=Float64,
        deterministic=true,
    )

    # This should NOT throw MethodError: no method matching randn(..., ::Type{MyVec2})
    # The fix uses eltype(x0) = Float64 instead of T = MyVec2
    mach = machine(model, X, y; scitype_check_level=0)
    fit!(mach; verbosity=0)
    rep = report(mach)

    # Basic sanity check: should find a reasonable expression
    @test haskey(rep, :equations)
    @test length(rep.equations) > 0
end
