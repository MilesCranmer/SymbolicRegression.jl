using SymbolicRegression
using SymbolicRegression.ConstantOptimizationModule:
    Evaluator, GradEvaluator, specialized_options
using DynamicExpressions
using DifferentiationInterface: value_and_gradient
using Test

# Utility for testing derivatives
function setup_parametric_test(rng)
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

    return X, true_params, init_params, init_constants, class, y, dataset
end

function get_parametric_test_vals(
    rng, init_params, init_constants, X, class, y, zygote_backend
)
    (true_val, (true_d_params, true_d_constants)) =
        value_and_gradient(zygote_backend, (init_params, init_constants)) do (params, c)
            pred = [
                X[1, i] * X[1, i] - cos(c[1] * X[2, i] + c[2]) + params[1, class[i]] for
                i in 1:32
            ]
            sum(abs2, pred .- y) / length(y)
        end

    return true_val, true_d_params, true_d_constants
end

function create_parametric_expression(init_params, operators)
    ex = @parse_expression(
        x * x - cos(2.5 * y + -0.5) + p1,
        operators = operators,
        expression_type = ParametricExpression,
        variable_names = ["x", "y"],
        extra_metadata = (parameter_names=["p1"], parameters=init_params)
    )

    return ex
end

function test_autodiff_backend(
    ex,
    dataset,
    true_val,
    true_d_constants,
    true_d_params,
    options,
    backend;
    allow_failure=false,
)
    x0, refs = get_scalar_constants(ex)
    G = zero(x0)

    f = Evaluator(ex, refs, dataset, specialized_options(options))
    fg! = GradEvaluator(f, backend)

    @test f(x0) ≈ true_val

    try
        val = fg!(nothing, G, x0)
        @test val ≈ true_val
        @test G ≈ vcat(true_d_constants[:], true_d_params[:])
        return true
    catch e
        if allow_failure
            @warn "Expected failure" e
            return false
        else
            rethrow(e)
        end
    end
end
