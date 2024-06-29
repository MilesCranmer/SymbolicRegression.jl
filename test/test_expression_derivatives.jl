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
    δŷ = ex'(X)

    @test δy ≈ δŷ

    options2 = Options(; unary_operators=[sin], binary_operators=[+, *, -])
    (δy2,) = Zygote.gradient(X) do X
        x = @view X[1, :]
        y = @view X[2, :]

        sum(i -> (x[i] + x[i]) * sin(2.5 + y[i]), eachindex(x))
    end
    δy2̂ = ex'(X, options2)

    @test δy2 ≈ δy2̂
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

    f = Evaluator(dataset, options, nothing)
    fg! = GradEvaluator(f)

    ex = @parse_expression(
        x * x - cos(2.5 * y), operators = options.operators, variable_names = [:x, :y]
    )
    @test f(ex) isa Float64

    (val, grad) = value_and_gradient(f, options.autodiff_backend, ex)
    @test val isa Float64
    @test typeof(grad.tree) <: DynamicExpressions.ChainRulesModule.NodeTangent{
        Float64,Node{Float64},Vector{Float64}
    }
    @test typeof(grad.tree.gradient) <: Vector{Float64}
end

@testitem "Test derivatives of parametric expression during optimization" tags = [:part1] begin
    using SymbolicRegression
    using SymbolicRegression.ConstantOptimizationModule:
        Evaluator, GradEvaluator, optimize_constants
    using DynamicExpressions
    using Zygote: Zygote
    using Random: MersenneTwister
    using DifferentiationInterface: value_and_gradient, AutoZygote

    rng = MersenneTwister(0)
    X = rand(rng, 2, 32)
    true_params = [0.5 2.0]
    init_params = [0.1 0.2]
    init_constants = [2.5, -0.5]
    classes = rand(rng, 1:2, 32)
    y = [
        X[1, i] * X[1, i] - cos(2.6 * X[2, i] - 0.2) + true_params[1, classes[i]] for
        i in 1:32
    ]

    dataset = Dataset(X, y; extra=(; classes))

    (true_val, (true_d_params, true_d_constants)) =
        value_and_gradient(AutoZygote(), (init_params, init_constants)) do (params, c)
            pred = [
                X[1, i] * X[1, i] - cos(c[1] * X[2, i] + c[2]) + params[1, classes[i]] for
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

    x0, refs = get_constants(ex)
    f = Evaluator(ex, refs, dataset, options, nothing)
    fg! = GradEvaluator(f)

    @test f(x0) ≈ true_val

    (val, G) = let G = Array{Float64}(undef, length(x0))
        (fg!(nothing, G, x0), G)
    end
    @test val ≈ true_val
    @test G ≈ vcat(true_d_constants[:], true_d_params[:])
end
