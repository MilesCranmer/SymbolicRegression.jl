using FromFile
using SymbolicRegression, Test
@from "test_params.jl" import maximum_residual

_inv(x::Float32)::Float32 = 1f0/x
X = rand(Float32, 5, 100) .+ 1
y = 1.2f0 .+ 2 ./ X[3, :]

options = SymbolicRegression.Options(
    binary_operators=(+, *),
    unary_operators=(_inv,),
    npopulations=8
)
hallOfFame = EquationSearch(X, y, niterations=8, options=options, numprocs=4)

dominating = calculateParetoFrontier(X, y, hallOfFame, options)

best = dominating[end]
# Test the score
@test best.score < maximum_residual / 10
