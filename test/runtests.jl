using SafeTestsets
using Test

ENV["SYMBOLIC_REGRESSION_TEST"] = "true"
TEST_SUITE = get(ENV, "SYMBOLIC_REGRESSION_TEST_SUITE", "all")

if TEST_SUITE in ("all", "integration")
    @safetestset "Aqua tests" begin
        include("test_aqua.jl")
    end
end

# Trigger extensions:
using LoopVectorization, Bumper, Zygote

if TEST_SUITE in ("all", "unit")
    @safetestset "Unit tests" begin
        include("unittest.jl")
    end
end

if TEST_SUITE in ("all", "integration")
    @eval @testset "End to end test" begin
        include("full.jl")
    end
end
