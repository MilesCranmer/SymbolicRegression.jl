using SafeTestsets
using Test

ENV["SYMBOLIC_REGRESSION_TEST"] = "true"

@safetestset "Aqua tests" begin
    include("test_aqua.jl")
end
# Trigger extensions:
using LoopVectorization, Bumper, Zygote

@safetestset "Unit tests" begin
    include("unittest.jl")
end
@testset "End to end test" begin
    include("full.jl")
end
