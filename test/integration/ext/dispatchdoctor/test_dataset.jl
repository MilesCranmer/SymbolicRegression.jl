@testitem "Dataset construction" tags = [:part3] begin
    using SymbolicRegression
    # Promotion of types:
    dataset = Dataset(randn(3, 32), randn(Float32, 32); weights=randn(Float32, 32))

    # Will not automatically convert:
    @test typeof(dataset.X) == Array{Float64,2}
    @test typeof(dataset.y) == Array{Float32,1}
    @test typeof(dataset.weights) == Array{Float32,1}
end

@testitem "With deprecated kwarg" tags = [:part3] begin
    using SymbolicRegression
    using DispatchDoctor: allow_unstable
    dataset = allow_unstable() do
        Dataset(randn(ComplexF32, 3, 32), randn(ComplexF32, 32); loss_type=Float64)
    end
    @test dataset isa Dataset{ComplexF32,Float64}
end

@testitem "vector output" tags = [:part3] begin
    using SymbolicRegression

    X = randn(Float64, 3, 32)
    y = [ntuple(_ -> randn(Float64), 3) for _ in 1:32]
    dataset = Dataset(X, y)
    @test dataset isa Dataset{Float64,Float64}
    @test dataset.y isa Vector{NTuple{3,Float64}}
end
