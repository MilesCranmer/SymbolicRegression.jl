using SymbolicRegression
using SymbolicRegression: loss
using Random
using Test
include("test_params.jl")

customloss(x, y) = abs(x - y)^2.5
customloss(x, y, w) = w * (abs(x - y)^2.5)
testl1(x, y) = abs(x - y)
testl1(x, y, w) = abs(x - y) * w

for (loss_fnc, evaluator) in [(L1DistLoss(), testl1), (customloss, customloss)]
    local options = Options(;
        default_params...,
        binary_operators=(+, *, -, /),
        unary_operators=(cos, exp),
        npopulations=4,
        loss=loss_fnc,
    )
    x = randn(MersenneTwister(0), Float32, 100)
    y = randn(MersenneTwister(1), Float32, 100)
    w = abs.(randn(MersenneTwister(2), Float32, 100))
    @test abs(loss(x, y, options) - sum(evaluator.(x, y)) / length(x)) < 1e-6
    @test abs(loss(x, y, w, options) - sum(evaluator.(x, y, w)) / sum(w)) < 1e-6
end
