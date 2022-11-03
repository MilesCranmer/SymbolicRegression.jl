using SafeTestsets
using Test

@safetestset "Unit tests" begin
    include("unittest.jl")
end
@testset "End to end test" begin
    include("full.jl")
end
