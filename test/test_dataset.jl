using SymbolicRegression
using DispatchDoctor: allow_unstable

@testset "Dataset construction" begin
    # Promotion of types:
    dataset = Dataset(randn(3, 32), randn(Float32, 32); weights=randn(Float32, 32))
    @test typeof(dataset.y) == Array{Float64,1}
    @test typeof(dataset.weights) == Array{Float64,1}
end

@testset "With deprecated kwarg" begin
    dataset = allow_unstable() do
        Dataset(randn(ComplexF32, 3, 32), randn(ComplexF32, 32); loss_type=Float64)
    end
    @test dataset isa Dataset{ComplexF32,Float64}
end
