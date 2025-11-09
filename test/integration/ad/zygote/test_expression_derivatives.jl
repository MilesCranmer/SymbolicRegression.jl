@testitem "Test derivatives" begin
    using SymbolicRegression
    using Zygote: Zygote
    using Random: MersenneTwister

    ex = @parse_expression(
        x * x - cos(2.5 * y),
        unary_operators = [cos],
        binary_operators = [*, -, +],
        variable_names = [:x, :y]
    )

    rng = MersenneTwister(0)
    X = rand(rng, 2, 32)

    (δy,) = Zygote.gradient(X) do X
        x = @view X[1, :]
        y = @view X[2, :]

        sum(i -> x[i] * x[i] - cos(2.5 * y[i]), eachindex(x))
    end
    δy_hat = ex'(X)

    @test δy ≈ δy_hat

    options2 = Options(; unary_operators=[sin], binary_operators=[+, *, -])
    (δy2,) = Zygote.gradient(X) do X
        x = @view X[1, :]
        y = @view X[2, :]

        sum(i -> (x[i] + x[i]) * sin(2.5 + y[i]), eachindex(x))
    end
    δy2_hat = ex'(X, options2)

    @test δy2 ≈ δy2_hat
end

@testitem "Test derivatives during optimization" begin
    using SymbolicRegression
    using SymbolicRegression.ConstantOptimizationModule:
        Evaluator, GradEvaluator, EvaluatorContext
    using DynamicExpressions
    using Zygote: Zygote
    using Random: MersenneTwister
    using DifferentiationInterface: value_and_gradient

    rng = MersenneTwister(0)
    X = rand(rng, 2, 32)
    y = @. X[1, :] * X[1, :] - cos(2.6 * X[2, :])
    dataset = Dataset(X, y)

    options = Options(;
        unary_operators=[cos], binary_operators=[+, *, -], autodiff_backend=:Zygote
    )

    ex = @parse_expression(
        x * x - cos(2.5 * y), operators = options.operators, variable_names = [:x, :y]
    )
    ctx = EvaluatorContext(dataset, options)
    f = Evaluator(ex, last(get_scalar_constants(ex)), ctx)
    fg! = GradEvaluator(f, options.autodiff_backend)

    @test f(first(get_scalar_constants(ex))) isa Float64

    x = first(get_scalar_constants(ex))
    G = zero(x)
    fg!(nothing, G, x)
    @test G[] != 0
end

@testitem "Test derivatives of parametric expression during optimization" begin
    using SymbolicRegression
    using SymbolicRegression.ConstantOptimizationModule: specialized_options
    using DynamicExpressions
    using Zygote: Zygote
    using Random: MersenneTwister
    using DifferentiationInterface: AutoZygote

    # Import our AutoDiff helpers
    include(joinpath(@__DIR__, "..", "autodiff_helpers.jl"))

    rng = MersenneTwister(0)

    # Set up test data using our helper
    _, dataset, init_params, _, true_val, true_d_params, true_d_constants = setup_parametric_test(
        rng
    )

    # Create options and expression
    options = Options(;
        unary_operators=[cos], binary_operators=[+, *, -], autodiff_backend=:Zygote
    )

    ex = create_parametric_expression(init_params, options.operators)

    # Test with Zygote
    test_autodiff_backend(
        ex, dataset, true_val, true_d_constants, true_d_params, options, AutoZygote()
    )
end
