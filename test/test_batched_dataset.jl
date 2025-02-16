@testitem "BatchedDataset properties" tags = [:part3] begin
    using SymbolicRegression
    using SymbolicRegression: batch, BatchedDataset
    using Random

    # Test basic dataset creation
    X = randn(3, 32)
    y = randn(32)
    weights = randn(32)
    dataset = Dataset(X, y; weights=weights)

    # Test batching with default RNG
    batch_size = 16
    batched = batch(dataset, batch_size)
    @test batched isa BatchedDataset
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
    @test batched2 isa BatchedDataset
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
