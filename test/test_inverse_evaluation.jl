@testitem "Basic inversion" begin
    using SymbolicRegression
    using SymbolicRegression.EvaluateInverseModule: eval_inverse_tree_array, ResultOk

    X = randn(3, 32)
    y = randn(32)
    options = Options()
    x1 = Node{Float64}(; feature=1)

    (y_for_x1, complete) = eval_inverse_tree_array(x1, X, options.operators, x1, y)
    @test complete
    @show y_for_x1 ≈ y

    @inferred eval_inverse_tree_array(x1, X, options.operators, x1, y)
end

@testitem "Inversion with operators" begin
    using SymbolicRegression
    using SymbolicRegression.EvaluateInverseModule: eval_inverse_tree_array
    using Random: MersenneTwister

    rng = MersenneTwister(0)
    X = randn(rng, 3, 32)
    y = rand(rng, 32) .- 10
    options = Options(; binary_operators=[+, -, *, /], unary_operators=[cos, exp])

    x1, x2, x3 = map(i -> Node{Float64}(; feature=i), 1:3)

    base_tree = cos(x2 * 5.0)
    # ^We wish to invert the function at this node
    tree = cos(x1) - exp(base_tree * 2.1)

    true_inverse_for_base_tree = @. log(cos(X[1, :]) - y) / 2.1

    (y_for_base_tree, complete) = eval_inverse_tree_array(
        tree, X, options.operators, base_tree, y
    )
    @test y_for_base_tree ≈ true_inverse_for_base_tree

    # Another example:
    base_tree2 = Node{Float64}(; val=1.0)
    tree2 = x1 * x1 * base_tree2 + x2
    true_inverse_for_base_tree2 = @. (y - X[2, :]) / X[1, :] / X[1, :]
    (y_for_base_tree2, complete) = eval_inverse_tree_array(
        tree2, X, options.operators, base_tree2, y
    )
    @test y_for_base_tree2 ≈ true_inverse_for_base_tree2
end

@testitem "Inversion with invalid values" begin
    using SymbolicRegression
    using SymbolicRegression.EvaluateInverseModule: eval_inverse_tree_array
    using Random: MersenneTwister

    rng = MersenneTwister(0)
    X = randn(rng, 3, 32)
    y = rand(rng, 32) .- 10
    options = Options(; binary_operators=[+, -, *, /], unary_operators=[cos, exp])

    x1 = Node{Float64}(; feature=1)
    # Impossible to reach `y`
    tree = exp(x1)
    (_, complete) = eval_inverse_tree_array(tree, X, options.operators, x1, y)
    @test !complete

    tree = cos(x1)
    (_, complete) = eval_inverse_tree_array(tree, X, options.operators, x1, y)
    @test !complete
end
