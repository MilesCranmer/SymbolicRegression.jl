using SymbolicRegression, SymbolicUtils, Test
function _inv(x::T)::T where {T}
    1f0/x
end
X = rand(Float32, 5, 100) .+ 1
y = 1.2 .+ 2 ./ X[3, :]

options = SymbolicRegression.Options(
    binary_operators=(+, *),
    unary_operators=(_inv,),
    npopulations=4
)
hallOfFame = EquationSearch(X, y, niterations=2, options=options)

dominating = calculateParetoFrontier(X, y, hallOfFame, options)

best = dominating[end]
eqn = node_to_symbolic(best.tree, options, evaluate_functions=true)
@syms x1::Real x2::Real x3::Real x4::Real
true_eqn = 2 / (x3 + 1.5)
residual = simplify(eqn - true_eqn)

# Test the score
@test best.score < 1e-6
x4 = 0.1f0
# Test the actual equation found:
@test abs(eval(Meta.parse(string(residual)))) < 1e-6
