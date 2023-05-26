using SymbolicRegression
using Test
using Measurements

X = randn(3, 64) .± (rand(3, 64) .* 0.1)
y = @. cos(X[3, :] * 0.9 - 0.2) * 2.5 - 2 * X[2, :]^2

options = Options(; elementwise_loss=(prediction, target) -> abs2(prediction - target).val)

EquationSearch(X, y; options)
