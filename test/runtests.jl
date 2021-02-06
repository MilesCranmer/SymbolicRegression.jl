using SafeTestsets

@safetestset "Unit tests" begin include("unittest.jl") end
@safetestset "End to end test" begin include("full.jl") end
@safetestset "End to end test" begin include("user_defined_operator.jl") end
