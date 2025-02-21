@testitem "SubDataset properties" tags = [:part3] begin
    using SymbolicRegression
    using SymbolicRegression: batch, SubDataset
    using Random

    # Test basic dataset creation
    X = randn(3, 32)
    y = randn(32)
    weights = randn(32)
    dataset = Dataset(X, y; weights=weights)

    # Test batching with default RNG
    batch_size = 16
    batched = batch(dataset, batch_size)
    @test batched isa SubDataset
    @test size(batched.X, 2) == batch_size
    @test batched.X isa SubArray
    @test length(batched.y) == batch_size
    @test length(batched.weights) == batch_size
    @test batched.n == batch_size

    # Skip X, y, weights, n which we checked above
    for prop in setdiff(propertynames(batched), (:X, :y, :weights, :n))
        @test getproperty(batched, prop) == getproperty(dataset, prop)
    end

    # Test batching with explicit RNG
    rng = Random.MersenneTwister(42)
    rng2 = Random.MersenneTwister(42)
    batched2 = batch(rng, dataset, batch_size)
    @test batched2 isa SubDataset
    @test size(batched2.X, 2) == batch_size

    @test batch(rng2, dataset, batch_size).X == batched2.X

    # Test batching with different batch sizes
    batched3 = batch(dataset, 8)
    @test size(batched3.X, 2) == 8
    @test length(batched3.y) == 8
    @test length(batched3.weights) == 8

    # Test batching without weights
    dataset_no_weights = Dataset(X, y)
    batched5 = batch(dataset_no_weights, batch_size)
    @test batched5.weights === nothing

    # Test batching without y
    dataset_no_y = Dataset(X, nothing)
    batched6 = batch(dataset_no_y, batch_size)
    @test batched6.y === nothing
end

@testitem "ParametricExpression evaluation with batched datasets" tags = [:part3] begin
    using SymbolicRegression
    using SymbolicRegression: batch
    using SymbolicRegression.LossFunctionsModule: eval_loss
    using DynamicExpressions: Node

    # Create a dataset with classes
    X = randn(2, 100)  # 2 features
    class = rand(1:3, 100)  # 3 classes
    # True function: x1 * p[class] where p = [0.5, 1.0, 2.0]
    true_params = [0.5 1.0 2.0]
    y = [X[1, i] * true_params[class[i]] for i in 1:100]

    # Create both regular and batched datasets
    dataset = Dataset(X, y; extra=(; class))
    batch_size = 32
    batched_dataset = batch(dataset, batch_size)

    # Create a parametric expression: x1 * p1
    options = Options(; expression_spec=ParametricExpressionSpec(; max_parameters=1))
    ex = parse_expression(
        :(x1 * p1);
        expression_type=ParametricExpression,
        operators=options.operators,
        parameters=copy(true_params),
        parameter_names=["p1"],
        variable_names=["x1", "x2"],
    )

    # Test through eval_loss to ensure the whole pipeline works
    loss1 = eval_loss(ex, dataset, options)
    @test loss1 < 1e-10

    loss2 = eval_loss(ex, batched_dataset, options)
    @test loss2 < 1e-10
end

@testitem "eval_loss correctness with batched datasets" tags = [:part3] begin
    using SymbolicRegression
    using SymbolicRegression: batch
    using SymbolicRegression.LossFunctionsModule: eval_loss
    using DynamicExpressions: Node

    # Create dataset with 2 classes
    X = [1.0 2.0 3.0]  # 1 feature, 3 samples
    y = [2.0, 6.0, 12.0]  # y = x1 * [2, 3, 4] based on class
    dataset = Dataset(X, y; extra=(; class=[1, 2, 3]))

    # Create expression with 1 parameter but 3 classes
    options = Options(; expression_spec=ParametricExpressionSpec(; max_parameters=1))
    ex = parse_expression(
        :(x1 * p1);
        expression_type=ParametricExpression,
        operators=options.operators,
        # Parameters matrix: 1 parameter × 3 classes
        parameters=reshape([1.0, 1.0, 1.0], 1, 3),  # Should produce errors of [1, 5, 11]
        parameter_names=["p1"],
        variable_names=["x1"],
    )

    # Test full dataset loss (MSE)
    full_loss = eval_loss(ex, dataset, options)
    @test full_loss ≈ (1.0^2 + 4.0^2 + 9.0^2) / 3

    # Test individual class batches
    batched_class1 = batch(dataset, [1])  # x=1.0, true y=2.0, pred y=1.0*1=1.0
    @test eval_loss(ex, batched_class1, options) ≈ 1.0^2

    batched_class2 = batch(dataset, [2])  # x=2.0, true y=6.0, pred y=2.0*1=2.0
    @test eval_loss(ex, batched_class2, options) ≈ (2.0 - 6.0)^2

    batched_class3 = batch(dataset, [3])  # x=3.0, true y=12.0, pred y=3.0*1=3.0
    @test eval_loss(ex, batched_class3, options) ≈ (3.0 - 12.0)^2

    # Test mixed batch
    mixed_batch = batch(dataset, [1, 3])
    @test eval_loss(ex, mixed_batch, options) ≈ (1.0^2 + 9.0^2) / 2
end
