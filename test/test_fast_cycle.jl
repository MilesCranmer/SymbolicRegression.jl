using SymbolicRegression
using Test
using Random
include("test_params.jl")

options = SymbolicRegression.Options(;
    default_params...,
    binary_operators=(+, *),
    unary_operators=(cos,),
    npopulations=4,
    constraints=((*) => (-1, 10), cos => (5)),
    fast_cycle=true,
    skip_mutation_failures=true,
    return_state=true,
)
X = randn(MersenneTwister(0), Float32, 5, 100)
y = 2 * cos.(X[4, :])
varMap = ["t1", "t2", "t3", "t4", "t5"]
state, hallOfFame = EquationSearch(X, y; varMap=varMap, niterations=2, options=options)
dominating = calculate_pareto_frontier(X, y, hallOfFame, options)

best = dominating[end]

# Test the score
@test best.loss < maximum_residual / 10

# Do search again, but with saved state:
# We do 0 iterations to make sure the state is used.
println("Passed.")
println("Testing whether state saving works.")
state, hallOfFame = EquationSearch(
    X, y; varMap=varMap, niterations=0, options=options, saved_state=(state, hallOfFame)
)

dominating = calculate_pareto_frontier(X, y, hallOfFame, options)
best = dominating[end]
print_tree(best.tree, options)
@test best.loss < maximum_residual / 10
