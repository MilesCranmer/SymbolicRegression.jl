using SafeTestsets
using Test

ENV["SYMBOLIC_REGRESSION_TEST"] = "true"

@safetestset "Unit tests" begin
    include("unittest.jl")
end
@testset "End to end test" begin
    include("full.jl")
end
