using SymbolicRegression
using Test
include("test_params.jl")

function my_custom_loss(tree::Node{T}, dataset::Dataset{T}, options::Options) where {T}
    # We multiply the tree by 2.0:
    tree = Node(1, tree, Node(T; val=2.0))
    out, completed = eval_tree_array(tree, dataset.X, options)
    if !completed
        return T(Inf)
    end
    return sum(abs, out .- dataset.y)
end

options = Options(;
    binary_operators=[*, /, +, -],
    unary_operators=[cos, sin],
    loss_function=my_custom_loss,
    elementwise_loss=nothing,
    maxsize=10,
    early_stop_condition=1e-10,
    adaptive_parsimony_scaling=100.0,
    mutation_weights=MutationWeights(; optimize=0.01),
)

X = rand(2, 100) .* 10
y = X[1, :] .+ X[2, :]

# The best tree should be 0.5 * (x1 + x2), since the custom loss function
# multiplies the tree by 2.0.

hall_of_fame = EquationSearch(
    X, y; niterations=100, options=options, parallelism=:multiprocessing, numprocs=1
)
dominating = calculate_pareto_frontier(X, y, hall_of_fame, options)

testX = rand(2, 100) .* 10
expected_y = 0.5 .* (testX[1, :] .+ testX[2, :])
@test eval_tree_array(dominating[end].tree, testX, options)[1] ≈ expected_y atol = 1e-5
