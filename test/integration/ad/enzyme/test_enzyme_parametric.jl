@testitem "Test Enzyme derivatives of parametric expression" begin
    using SymbolicRegression
    using SymbolicRegression.ConstantOptimizationModule: specialized_options
    using DynamicExpressions
    using Random: MersenneTwister
    using DifferentiationInterface: AutoZygote

    # Import our AutoDiff helpers shared with the Zygote tests
    include(joinpath(@__DIR__, "..", "autodiff_helpers.jl"))

    # Try to load Enzyme - skip test if not available
    (enzyme_loaded, enzyme_error) = try
        using Enzyme
        using DifferentiationInterface: AutoEnzyme
        (true, nothing)
    catch e
        (false, e)
    end

    if !enzyme_loaded
        @warn "Skipping Enzyme tests because Enzyme.jl could not be loaded" exception =
            enzyme_error
        @test_skip "Enzyme.jl is not available"
    else
        rng = MersenneTwister(0)

        # Set up test data using our helper
        _, dataset, init_params, _, true_val, true_d_params, true_d_constants = setup_parametric_test(
            rng
        )

        # Create options with Enzyme backend
        options = Options(;
            unary_operators=[cos], binary_operators=[+, *, -], autodiff_backend=:Enzyme
        )

        ex = create_parametric_expression(init_params, options.operators)

        # Test with Enzyme
        test_autodiff_backend(
            ex,
            dataset,
            true_val,
            true_d_constants,
            true_d_params,
            options,
            AutoEnzyme();
            allow_failure=true,
        )
    end
    # TODO: Test with batched dataset
end
