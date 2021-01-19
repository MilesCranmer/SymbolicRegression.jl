using Test

using Distributed
using Random
using SymbolicUtils

addprocs(2)

@testset "Basic test" begin
    @everywhere include("src/SymbolicRegression.jl")
    @everywhere using .SymbolicRegression

    Random.seed!(0)

    X = randn(Float32, 100, 2)
    y = 2 * cos.(X[:, 2]) + X[:, 1] .^ 2 .- 2

    options = SymbolicRegression.Options(
        binary_operators=(+, *),
        unary_operators=(cos,),
        npopulations=3,
        maxsize=15
    )

    niterations = 5
    hallOfFame = RunSR(X, y, niterations, options)
    dominating = calculateParetoFrontier(X, y, hallOfFame, options)

    @test dominating[end].score < 1e-3
    @test length(stringTree(dominating[end].tree, options)) > 10
end

rmprocs()
