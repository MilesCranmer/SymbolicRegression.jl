using SymbolicRegression, SymbolicUtils, Test
X = randn(Float32, 5, 100)
y = 2 * cos.(X[4, :])

options = SymbolicRegression.Options(
    binary_operators=(+, *),
    unary_operators=(cos,),
    npopulations=8
)
niterations = 2
hallOfFame = EquationSearch(X, y, niterations=niterations, options=options)
dominating = calculateParetoFrontier(X, y, hallOfFame, options)
best = dominating[end]
eqn = node_to_symbolic(best.tree, options, evaluate_functions=true)

@syms x1::Real x2::Real x3::Real x4::Real

true_eqn = 2*cos(x4)

@test best.score < 1e-6

recompiled_eqn = eval(string(eqn))
for st in (simplify(eqn), true_eqn, simplify(eqn - true_eqn), recompiled_eqn, simplify(eqn - true_eqn))
    println(st)
end
