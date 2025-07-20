@testitem "Test feature mutation" tags = [:part1] begin
    using SymbolicRegression
    using DynamicExpressions: Node
    using StableRNGs: StableRNG

    rng = StableRNG(0)

    @testset "Basic feature mutation" begin
        # Single feature node
        tree = Node(Float64; feature=1)
        mutated = SymbolicRegression.MutationFunctionsModule.mutate_feature(tree, 3, rng)
        @test mutated.feature != 1  # Should change
        @test 1 <= mutated.feature <= 3  # In valid range
    end

    @testset "Edge cases" begin
        # Single feature - should not change when nfeatures=1
        tree = Node(Float64; feature=1)
        mutated = SymbolicRegression.MutationFunctionsModule.mutate_feature(tree, 1, rng)
        @test mutated.feature == 1

        # Constant node - should be unchanged
        tree = Node(Float64; val=1.0)
        original_val = tree.val
        mutated = SymbolicRegression.MutationFunctionsModule.mutate_feature(tree, 3, rng)
        @test mutated.val == original_val  # Should be unchanged
    end

    @testset "Mutation weights" begin
        # Test that mutate_feature is included in MutationWeights
        weights = MutationWeights()
        @test hasfield(typeof(weights), :mutate_feature)
        @test weights.mutate_feature == 0.1
    end
end
