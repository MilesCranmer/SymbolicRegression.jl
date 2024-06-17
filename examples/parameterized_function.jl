using SymbolicRegression
using Zygote
using DifferentiationInterface: AutoZygote

X = randn(Float32, 5, 100)
classes = rand(1:3, 100)
p1 = rand(Float32, 3)
p2 = rand(Float32, 3)

y = [
    2 * cos(X[4, i] + p1[classes[i]]) + X[1, i]^2 - p2[classes[i]] for
    i in eachindex(classes)
]

y .+= classes

options = SymbolicRegression.Options(;
    binary_operators=[+, *, /, -],
    unary_operators=[cos, exp],
    populations=20,
    expression_type=ParametricExpression,
    expression_options=(; max_parameters=2),
    autodiff_backend=AutoZygote(),
)

hall_of_fame = equation_search(
    X, y; extra=(; classes), niterations=400, options=options, parallelism=:multithreading
)

dominating = calculate_pareto_frontier(hall_of_fame)
