@testitem "Test feature mutation" begin
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

    @testset "get_nfeatures_for_mutation API" begin
        using DynamicExpressions: Expression
        using SymbolicRegression.MutationFunctionsModule: get_nfeatures_for_mutation

        # Test default implementation
        operators = OperatorEnum(; binary_operators=[+, *], unary_operators=[cos])
        ex = Expression(Node{Float64}(; feature=1); operators=operators)

        # Default implementation should return global nfeatures
        @test get_nfeatures_for_mutation(ex, nothing, 5) == 5
        @test get_nfeatures_for_mutation(ex, nothing, 10) == 10
    end

    @testset "TemplateExpression get_nfeatures_for_mutation" begin
        # Create a template structure with different feature counts per subexpression
        struct_different_features = TemplateStructure{(:f, :g)}(
            ((; f, g), (x1, x2, x3, x4)) -> f(x1, x2) + g(x1, x3, x4);
            # f uses features 1, 2; g uses features 1, 3, 4
        )

        options = Options(;
            binary_operators=(+, *),
            unary_operators=(sin,),
            expression_spec=TemplateExpressionSpec(; structure=struct_different_features),
        )
        operators = options.operators
        variable_names = ["x1", "x2", "x3", "x4"]

        # Create composable expressions
        f_expr = ComposableExpression(Node{Float64}(; feature=1); operators, variable_names)
        g_expr = ComposableExpression(Node{Float64}(; feature=1); operators, variable_names)

        # Create template expression
        template_ex = TemplateExpression(
            (; f=f_expr, g=g_expr); structure=struct_different_features, operators=operators
        )

        using SymbolicRegression.MutationFunctionsModule: get_nfeatures_for_mutation

        # Test that each subexpression gets its specific feature count
        @test get_nfeatures_for_mutation(template_ex, :f, 4) == 2
        @test get_nfeatures_for_mutation(template_ex, :g, 4) == 3
    end
end
