using SymbolicRegression
using Test

@testset "Dataset construction" begin
    # Promotion of types:
    dataset = Dataset(randn(3, 32), randn(Float32, 32); weights=randn(Float32, 32))
    @test typeof(dataset.y) <: AbstractArray{Float64,1}
    @test typeof(dataset.weights) <: AbstractArray{Float64,1}
end

@testset "With deprecated kwarg" begin
    dataset = Dataset(randn(ComplexF32, 3, 32), randn(ComplexF32, 32); loss_type=Float64)
    @test dataset isa Dataset{ComplexF32,Float64}
end
