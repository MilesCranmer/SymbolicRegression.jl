@testitem "Test derivatives" tags = [:part1] begin
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

@testitem "Test derivatives during optimization" tags = [:part1] begin
    using SymbolicRegression
    using SymbolicRegression.ConstantOptimizationModule: Evaluator, GradEvaluator
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
    f = Evaluator(ex, last(get_scalar_constants(ex)), dataset, options)
    fg! = GradEvaluator(f, options.autodiff_backend)

    @test f(first(get_scalar_constants(ex))) isa Float64

    x = first(get_scalar_constants(ex))
    G = zero(x)
    fg!(nothing, G, x)
    @test G[] != 0
end

@testitem "Test derivatives of parametric expression during optimization" tags = [:part3] begin
    using SymbolicRegression
    using SymbolicRegression.ConstantOptimizationModule:
        Evaluator, GradEvaluator, optimize_constants, specialized_options
    using DynamicExpressions
    using Zygote: Zygote
    using Random: MersenneTwister
    using DifferentiationInterface: value_and_gradient, AutoZygote, AutoEnzyme
    enzyme_compatible = VERSION >= v"1.10.0" && VERSION < v"1.11.0-DEV.0"
    @static if enzyme_compatible
        using Enzyme: Enzyme
    end

    rng = MersenneTwister(0)
    X = rand(rng, 2, 32)
    true_params = [0.5 2.0]
    init_params = [0.1 0.2]
    init_constants = [2.5, -0.5]
    class = rand(rng, 1:2, 32)
    y = [
        X[1, i] * X[1, i] - cos(2.6 * X[2, i] - 0.2) + true_params[1, class[i]] for
        i in 1:32
    ]

    dataset = Dataset(X, y; extra=(; class))

    (true_val, (true_d_params, true_d_constants)) =
        value_and_gradient(AutoZygote(), (init_params, init_constants)) do (params, c)
            pred = [
                X[1, i] * X[1, i] - cos(c[1] * X[2, i] + c[2]) + params[1, class[i]] for
                i in 1:32
            ]
            sum(abs2, pred .- y) / length(y)
        end

    options = Options(;
        unary_operators=[cos], binary_operators=[+, *, -], autodiff_backend=:Zygote
    )

    ex = @parse_expression(
        x * x - cos(2.5 * y + -0.5) + p1,
        operators = options.operators,
        expression_type = ParametricExpression,
        variable_names = ["x", "y"],
        extra_metadata = (parameter_names=["p1"], parameters=init_params)
    )

    function test_backend(ex, @nospecialize(backend); allow_failure=false)
        x0, refs = get_scalar_constants(ex)
        G = zero(x0)

        f = Evaluator(ex, refs, dataset, specialized_options(options))
        fg! = GradEvaluator(f, backend)

        @test f(x0) ≈ true_val

        try
            val = fg!(nothing, G, x0)
            @test val ≈ true_val
            @test G ≈ vcat(true_d_constants[:], true_d_params[:])
        catch e
            if allow_failure
                @warn "Expected failure" e
            else
                rethrow(e)
            end
        end
    end

    test_backend(ex, AutoZygote(); allow_failure=false)
    @static if enzyme_compatible
        test_backend(ex, AutoEnzyme(); allow_failure=true)
    end
end
