@testitem "Generic interface tests" begin
    using SymbolicRegression
    using SymbolicRegression: SRTestRegressor, MultitargetSRTestRegressor
    using MLJTestInterface: MLJTestInterface as MTI
    include(joinpath(@__DIR__, "..", "..", "..", "..", "test_params.jl"))

    failures, summary = MTI.test(
        [SRTestRegressor],
        MTI.make_regression()...;
        mod=@__MODULE__,
        verbosity=0,
        throw=true,
    )
    @test isempty(failures)

    X = randn(100, 3)
    Y = @. cos(X^2) * 3.2 - 0.5
    (X, Y) = MTI.table.((X, Y))
    w = ones(100)
    failures, summary = MTI.test(
        [MultitargetSRTestRegressor], X, Y, w; mod=@__MODULE__, verbosity=0, throw=true
    )
    @test isempty(failures)
end
