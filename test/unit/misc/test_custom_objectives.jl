@testitem "Test whether custom objectives work." begin
    using SymbolicRegression
    using SymbolicRegression: OperatorEnum, string_tree
    include(joinpath(@__DIR__, "..", "..", "test_params.jl"))

    def = quote
        _ifelse_ternary(a, b, c) = a > 0 ? b : c

        function my_custom_loss(
            tree::$(AbstractExpressionNode){T},
            dataset::$(Dataset){T},
            options::$(Options),
        ) where {T}
            out, completed = $(eval_tree_array)(tree, dataset.X, options)
            if !completed
                return T(Inf)
            end
            return sum(abs, (out .* T(0.5)) .- dataset.y)
        end
    end

    # TODO: Required for workers as they assume the function is defined in the Main module
    if (@__MODULE__) != Core.Main
        Core.eval(Core.Main, def)
        eval(:(using Main: my_custom_loss, _ifelse_ternary))
    else
        eval(def)
    end

    options = Options(;
        operators=OperatorEnum(1 => (cos, sin), 2 => (*, /, +, -), 3 => (_ifelse_ternary,)),
        loss_function=my_custom_loss,
        elementwise_loss=nothing,
        maxsize=10,
        early_stop_condition=1e-10,
        adaptive_parsimony_scaling=100.0,
        mutation_weights=MutationWeights(; optimize=0.01),
    )

    @test options.should_simplify == false

    X = rand(3, 100) .* 10 .- 5
    y = _ifelse_ternary.(X[1, :], X[2, :], X[3, :])  # y = x1 > 0 ? x2 : x3

    # The best tree should be 2.0 * _ifelse_ternary(x1, x2, x3), since the custom loss function
    # scales the tree output by 0.5.

    hall_of_fame = equation_search(
        X, y; niterations=100, options=options, parallelism=:serial
    )
    dominating = calculate_pareto_frontier(hall_of_fame)

    testX = rand(3, 100) .* 10 .- 5  # Range from -5 to 5
    expected_y = 2.0 .* _ifelse_ternary.(testX[1, :], testX[2, :], testX[3, :])
    @test eval_tree_array(dominating[end].tree, testX, options)[1] ≈ expected_y atol = 1e-5

    # Also verify that the tree actually uses the ternary operator
    tree_string = string_tree(dominating[end].tree, options)
    @test occursin("_ifelse_ternary", tree_string)
end
