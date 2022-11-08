using SymbolicRegression
using Test

X = randn(Float32, 5, 100)
y = 2 * cos.(X[4, :]) + X[1, :] .^ 2

early_stop(loss, c) = ((loss <= 1e-10) && (c <= 10))

options = SymbolicRegression.Options(;
    binary_operators=(+, *, /, -),
    unary_operators=(cos, exp),
    npopulations=20,
    early_stop_condition=early_stop,
)

hof = EquationSearch(X, y; options=options, niterations=1_000_000_000)

@test any(
    early_stop(member.loss, count_nodes(member.tree)) for member in hof.members[hof.exists]
)
