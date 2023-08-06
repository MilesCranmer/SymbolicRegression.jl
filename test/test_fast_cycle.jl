using SymbolicRegression
using Test
using Random
include("test_params.jl")

options = SymbolicRegression.Options(;
    default_params...,
    binary_operators=(+, *),
    unary_operators=(cos,),
    populations=4,
    constraints=((*) => (-1, 10), cos => (5)),
    fast_cycle=true,
    skip_mutation_failures=true,
)
X = randn(MersenneTwister(0), Float32, 5, 100)
y = 2 * cos.(X[4, :]) .- X[2, :]
variable_names = ["t1", "t2", "t3", "t4", "t5"]
state, hall_of_fame = equation_search(
    X, y; variable_names=variable_names, niterations=2, options=options, return_state=true
)
dominating = calculate_pareto_frontier(hall_of_fame)

best = dominating[end]

# Test the score
@test best.loss < maximum_residual / 10

# Do search again, but with saved state:
# We do 0 iterations to make sure the state is used.
println("Passed.")
println("Testing whether state saving works.")
new_state, new_hall_of_fame = equation_search(
    X,
    y;
    variable_names=variable_names,
    niterations=0,
    options=options,
    saved_state=(deepcopy(state), deepcopy(hall_of_fame)),
    return_state=true,
)

dominating = calculate_pareto_frontier(new_hall_of_fame)
best = dominating[end]
print_tree(best.tree, options)
@test best.loss < maximum_residual / 10

println("Testing whether state saving works with changed loss function.")
previous_loss = best.loss
new_loss(x, y) = sum(abs2, x - y) * 0.1
options = SymbolicRegression.Options(;
    default_params...,
    binary_operators=(+, *),
    unary_operators=(cos,),
    populations=4,
    constraints=((*) => (-1, 10), cos => (5)),
    fast_cycle=true,
    skip_mutation_failures=true,
    elementwise_loss=new_loss,
)
state, hall_of_fame = equation_search(
    X,
    y;
    variable_names=variable_names,
    niterations=0,
    options=options,
    saved_state=(state, hall_of_fame),
    return_state=true,
)
dominating = calculate_pareto_frontier(hall_of_fame)
best = dominating[end]
@test best.loss ≈ previous_loss * 0.1
