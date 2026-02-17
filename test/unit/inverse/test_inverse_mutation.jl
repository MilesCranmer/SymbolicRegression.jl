@testitem "Test inverse mutation" tags = [:part1] begin
    using SymbolicRegression
    using SymbolicRegression.InverseFunctionsModule: approx_inverse
    using SymbolicRegression.EvaluateInverseModule: eval_inverse_tree_array
    using SymbolicRegression.MutationFunctionsModule: backsolve_rewrite_random_node
    using DynamicExpressions: Node, OperatorEnum, count_nodes, Expression
    using StableRNGs: StableRNG

    rng = StableRNG(0)

    @testset "InverseFunctions - Unary operators" begin
        # Test basic unary inverse functions
        @test approx_inverse(sin) == SymbolicRegression.CoreModule.safe_asin
        @test approx_inverse(cos) == SymbolicRegression.CoreModule.safe_acos
        @test approx_inverse(exp) == SymbolicRegression.CoreModule.safe_log
        @test approx_inverse(SymbolicRegression.CoreModule.safe_sqrt) == SymbolicRegression.CoreModule.square
        @test approx_inverse(abs) === nothing
        @test approx_inverse(SymbolicRegression.CoreModule.relu) === nothing
        @test approx_inverse(SymbolicRegression.CoreModule.neg) == SymbolicRegression.CoreModule.neg
    end

    @testset "InverseFunctions - Binary operators" begin
        # Test Fix2 inverse for multiplication
        f_mul_2 = Base.Fix2(*, 2.0)
        inv_f = approx_inverse(f_mul_2)
        @test inv_f isa Base.Fix2{typeof(/)}
        @test inv_f.x == 2.0

        # Test Fix2 inverse for pow - returns lambda for logarithm
        f_2_pow = Base.Fix1(SymbolicRegression.CoreModule.safe_pow, 2.0)
        inv_f = approx_inverse(f_2_pow)
        # Inverse of 2^x is log_2(y) = log(y)/log(2), implemented as lambda
        @test inv_f isa Function
        @test inv_f(8.0) ≈ 3.0  # 2^3 = 8
    end

    @testset "EvaluateInverse - Simple unary tree" begin
        # Tree: sin(x)
        # Invert at x with y = [0.5]
        # Expected: x = asin(0.5) ≈ 0.524
        operators = OperatorEnum(; binary_operators=[+, *], unary_operators=[sin])
        x_node = Node(Float64; feature=1)
        tree = Node(1, x_node)  # sin(x)

        X = reshape([1.0], 1, 1)
        y = [0.5]

        inverted, success = eval_inverse_tree_array(tree, X, operators, x_node, y)

        @test success
        @test length(inverted) == 1
        @test inverted[1] ≈ asin(0.5) atol = 1e-10
    end

    @testset "EvaluateInverse - Binary tree" begin
        # Tree: x + 2
        # Invert at x with y = [5.0]
        # Expected: x = 5.0 - 2.0 = 3.0
        operators = OperatorEnum(; binary_operators=[+, *], unary_operators=[sin])
        x_node = Node(Float64; feature=1)
        const_node = Node(Float64; val=2.0)
        tree = Node(1, x_node, const_node)  # x + 2

        X = reshape([1.0], 1, 1)
        y = [5.0]

        inverted, success = eval_inverse_tree_array(tree, X, operators, x_node, y)

        @test success
        @test length(inverted) == 1
        @test inverted[1] ≈ 3.0 atol = 1e-10
    end

    @testset "EvaluateInverse - Complex tree" begin
        # Tree: sin(x * 2)
        # Invert at x with y = [0.5]
        # Expected: x = asin(0.5) / 2 ≈ 0.262
        operators = OperatorEnum(; binary_operators=[+, *], unary_operators=[sin])
        x_node = Node(Float64; feature=1)
        const_node = Node(Float64; val=2.0)
        mul_node = Node(2, x_node, const_node)  # x * 2
        tree = Node(1, mul_node)  # sin(x * 2)

        X = reshape([1.0], 1, 1)
        y = [0.5]

        inverted, success = eval_inverse_tree_array(tree, X, operators, x_node, y)

        @test success
        @test length(inverted) == 1
        @test inverted[1] ≈ asin(0.5) / 2.0 atol = 1e-10
    end

    @testset "EvaluateInverse - Multiple data points" begin
        # Tree: x + 1
        # Invert at x with y = [2.0, 3.0, 4.0]
        # Expected: x = [1.0, 2.0, 3.0]
        operators = OperatorEnum(; binary_operators=[+, *], unary_operators=[sin])
        x_node = Node(Float64; feature=1)
        const_node = Node(Float64; val=1.0)
        tree = Node(1, x_node, const_node)  # x + 1

        X = reshape([1.0, 2.0, 3.0], 1, 3)
        y = [2.0, 3.0, 4.0]

        inverted, success = eval_inverse_tree_array(tree, X, operators, x_node, y)

        @test success
        @test length(inverted) == 3
        @test inverted ≈ [1.0, 2.0, 3.0] atol = 1e-10
    end

    @testset "backsolve_rewrite_random_node - Basic mutation" begin
        # Create dataset
        X = reshape(Float64[1.0, 2.0, 3.0], 1, 3)
        y = Float64[2.0, 3.0, 4.0]
        dataset = Dataset(X, y)

        # Create options
        operators = OperatorEnum(; binary_operators=[+, *, -, /], unary_operators=[sin, cos])
        options = Options(; binary_operators=[+, *, -, /], unary_operators=[sin, cos])

        # Tree: sin(x1) + 2
        x_node = Node(Float64; feature=1)
        sin_node = Node(1, x_node)  # sin(x1)
        const_node = Node(Float64; val=2.0)
        tree = Node(1, sin_node, const_node)  # sin(x1) + 2

        # Mutate - should replace some node with a constant
        mutated_tree = backsolve_rewrite_random_node(tree, dataset, options, rng)

        # Check that mutation happened (tree structure might have changed)
        @test mutated_tree !== nothing
        @test count_nodes(mutated_tree) >= 1
    end

    @testset "backsolve_rewrite_random_node - Handles single node" begin
        # Single node tree should return unchanged
        X = reshape(Float64[1.0], 1, 1)
        y = Float64[1.0]
        dataset = Dataset(X, y)

        options = Options(; binary_operators=[+], unary_operators=[sin])

        tree = Node(Float64; val=1.0)
        mutated_tree = backsolve_rewrite_random_node(tree, dataset, options, rng)

        @test mutated_tree === tree  # Should be unchanged
    end

    @testset "backsolve_rewrite_random_node - Handles invalid inversion" begin
        # Tree that might produce invalid values during inversion
        X = reshape(Float64[1.0, 2.0], 1, 2)
        y = Float64[10.0, 20.0]  # Values that might be out of domain
        dataset = Dataset(X, y)

        operators = OperatorEnum(; binary_operators=[+, *], unary_operators=[sin])
        options = Options(; binary_operators=[+, *], unary_operators=[sin])

        # Tree: sin(x1)
        x_node = Node(Float64; feature=1)
        tree = Node(1, x_node)

        # Mutate - should handle gracefully
        mutated_tree = backsolve_rewrite_random_node(tree, dataset, options, rng)

        # Should either mutate successfully or return original
        @test mutated_tree !== nothing
    end

    @testset "MutationWeights - backsolve_rewrite field" begin
        # Test that backsolve_rewrite is included in MutationWeights
        weights = MutationWeights()
        @test hasfield(typeof(weights), :backsolve_rewrite)
        @test weights.backsolve_rewrite == 0.0  # disabled by default (opt-in)

        # Test that a custom value can be set
        weights_on = MutationWeights(; backsolve_rewrite=0.5)
        @test weights_on.backsolve_rewrite == 0.5
    end

    @testset "Integration - backsolve_rewrite in mutation pipeline" begin
        # Test that the mutation can be sampled and executed
        using SymbolicRegression.MutateModule: mutate!

        X = reshape(Float64[1.0, 2.0, 3.0], 1, 3)
        y = Float64[2.0, 4.0, 6.0]
        dataset = Dataset(X, y)

        options = Options(; binary_operators=[+, *], unary_operators=[sin])

        # Create a simple population member
        x_node = Node(Float64; feature=1)
        const_node = Node(Float64; val=1.0)
        tree = Node(1, x_node, const_node)  # x + 1

        ex = Expression(tree; operators=options.operators)
        member = PopMember(dataset, tree, options; deterministic=true)

        # Test that mutate! with Val{:backsolve_rewrite} works
        result = mutate!(
            ex,
            member,
            Val(:backsolve_rewrite),
            options.mutation_weights,
            options;
            recorder=Dict{String,Any}(),
            dataset=dataset,
        )

        @test result isa SymbolicRegression.MutateModule.MutationResult
        @test result.tree !== nothing || result.member !== nothing
    end
end
