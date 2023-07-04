import SymbolicRegression: SRRegressor
import MLJTestInterface as MTI
using Test

@testset "generic interface tests" begin
    failures, summary = MTI.test(
        [SRRegressor], MTI.make_regression()...; mod=@__MODULE__, verbosity=0, throw=true
    )
    @test isempty(failures)
end
