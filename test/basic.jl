using SymbolicRegression, SymbolicUtils

X = randn(Float32, 5, 100)
y = 2 * cos.(X[4, :]) + X[1, :] .^ 2 .- 2

options = SymbolicRegression.Options(
    binary_operators=(+, *),
    unary_operators=(cos,),
    npopulations=8
)
niterations = 15
hallOfFame = EquationSearch(X, y, niterations=niterations, options=options)
dominating = calculateParetoFrontier(X, y, hallOfFame, options)
best = dominating[end]
eqn = node_to_symbolic(best.tree, options, evaluate_functions=true)

@syms x1::Real x2::Real x3::Real x4::Real

true_eqn = 2*cos(x4) + x1^2 - 2

@test dominating[end].score < 1e-6
println(simplify(eqn), true_eqn, simplify(eqn - true_eqn))
