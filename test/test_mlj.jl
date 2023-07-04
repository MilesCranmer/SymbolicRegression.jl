import SymbolicRegression: SRRegressor, MultiSRRegressor
import MLJTestInterface as MTI
using Test

@testset "generic interface tests" begin
    failures, summary = MTI.test(
        [SRRegressor], MTI.make_regression()...; mod=@__MODULE__, verbosity=0, throw=true
    )
    @test isempty(failures)

    X = randn(100, 3)
    Y = @. cos(X^2) * 3.2 - 0.5
    (X, Y) = MTI.table.((X, Y))
    failures, summary = MTI.test(
        [MultiSRRegressor], X, Y; mod=@__MODULE__, verbosity=0, throw=true
    )
    @test isempty(failures)
end
