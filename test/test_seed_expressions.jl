@testitem "Test seed expressions functionality" tags = [:part1] begin
    using SymbolicRegression
    using DynamicExpressions
    using Random: seed!
    
    # Set seed for reproducibility
    seed!(0)
    
    # Create test data: y = 2*x1 + 3*x2 + 1
    X = [1.0 2.0 3.0 4.0 5.0;
         0.5 1.0 1.5 2.0 2.5]'
    y = 2.0 * X[:, 1] + 3.0 * X[:, 2] .+ 1.0
    
    # Test with default variable names (x1, x2)
    @testset "Default variable names" begin
        options = Options(
            binary_operators=[+, -, *, /],
            unary_operators=Function[],
            maxsize=15,
            populations=1,
            population_size=10,
            tournament_selection_n=5,
            seed_expressions=["x1 + x2", "2.1 * x1", "x1 * 2.0 + x2 * 3.1 + 0.9"],
            should_optimize_constants=true
        )
        
        hall_of_fame = equation_search(X, y; options=options, niterations=0)
        
        # Check that we got results
        @test length(hall_of_fame.members) > 0
        @test any(hall_of_fame.exists)
        
        # Check that at least one member has reasonable loss
        losses = [hall_of_fame.members[i].loss for i in 1:length(hall_of_fame.members) if hall_of_fame.exists[i]]
        @test length(losses) > 0
        @test minimum(losses) < 100.0  # Should be much better than random
        
        println("✅ Default variable names test passed!")
    end
    
    # Test with custom variable names
    @testset "Custom variable names" begin
        options = Options(
            binary_operators=[+, -, *],
            unary_operators=Function[],
            maxsize=10,
            populations=1,
            population_size=10,
            tournament_selection_n=5,
            seed_expressions=["alpha + beta", "2.5 * alpha", "alpha * 2.0 + beta * 3.2"],
            should_optimize_constants=true
        )
        
        hall_of_fame = equation_search(X, y; options=options, variable_names=["alpha", "beta"], niterations=0)
        
        # Check that we got results
        @test length(hall_of_fame.members) > 0
        @test any(hall_of_fame.exists)
        
        # Check that at least one member has reasonable loss  
        losses = [hall_of_fame.members[i].loss for i in 1:length(hall_of_fame.members) if hall_of_fame.exists[i]]
        @test length(losses) > 0
        @test minimum(losses) < 100.0  # Should be much better than random
        
        println("✅ Custom variable names test passed!")
    end
    
    println("🎉 All seed expressions tests passed!")
end