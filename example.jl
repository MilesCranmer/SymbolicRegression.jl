include("src/SymbolicRegression.jl")
using .SymbolicRegression
using SymbolicUtils

X = randn(Float32, 5, 100)
y = 2 * cos.(X[4, :]) + X[1, :] .^ 2 .- 2

inv(x) = 1/x

options = SymbolicRegression.Options(
    binary_operators=(+, *),
    unary_operators=(cos, exp, inv),
    npopulations=2
)
niterations = 2

hallOfFame = EquationSearch(X, y, niterations=niterations, options=options, numprocs=4)

dominating = calculateParetoFrontier(X, y, hallOfFame, options)
eqn = node_to_symbolic(dominating[end].tree, options, evaluate_functions=true)

print(simplify(eqn*5 + 3))
