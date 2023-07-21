using SymbolicRegression
using Test

@testset "Dataset construction" begin
    # Promotion of types:
    dataset = Dataset(randn(3, 32), randn(Float32, 32); weights=randn(Float32, 32))
    @test typeof(dataset.y) == Array{Float64,1}
    @test typeof(dataset.weights) == Array{Float64,1}
end
