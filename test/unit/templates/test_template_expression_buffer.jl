@testitem "TemplateExpression uses one call-time evaluation arena" begin
    using DynamicExpressions:
        ArrayBuffer, EvalContext, OperatorEnum, eval_tree_array, get_contents, get_metadata
    using SymbolicRegression
    using SymbolicRegression: D
    using SymbolicRegression.EvaluationModule: eval_loss

    @test Base.isdeprecated(SymbolicRegression, :EvalOptions)
    @test SymbolicRegression.EvalOptions === EvalContext

    operators = OperatorEnum(; binary_operators=(+, -, *))
    policy = EvalContext(; early_exit=false, use_fused=false)
    variable_names = ["x1", "x2"]
    x = ComposableExpression(
        Node{Float64}(; feature=1); operators, variable_names, eval_context=policy
    )
    f = x * x + 1.0
    g = 2.0 * x - 0.5
    X = [0.5 1.0 2.0 3.0; -2.0 -1.0 0.0 4.0]

    function check_buffered(expression, expected)
        unbuffered, unbuffered_complete = eval_tree_array(expression, X, operators)
        eval_context = EvalContext(; buffer=ArrayBuffer(Vector{Vector{Float64}}(), Ref(0)))
        buffered, buffered_complete = eval_tree_array(
            expression, X, operators; eval_context=eval_context
        )

        @test unbuffered_complete
        @test buffered_complete
        @test buffered ≈ unbuffered
        @test buffered ≈ expected
        @test all(
            inner -> get_metadata(inner).eval_context.buffer === nothing,
            values(get_contents(expression)),
        )
        return eval_context
    end

    derivative_structure = TemplateStructure{(:f,)}(
        ((; f), (x1, x2)) -> begin
            f2 = f
            df = D(f, 1)
            f2(x1) + df(x1)
        end
    )
    derivative_expression = TemplateExpression(
        (; f); structure=derivative_structure, operators, variable_names
    )
    check_buffered(derivative_expression, @. X[1, :]^2 + 1.0 + 2.0 * X[1, :])

    composed_structure = TemplateStructure{(:f, :g)}(((; f, g), (x1, x2)) -> f(x1) + g(x1))
    composed_expression = TemplateExpression(
        (; f, g); structure=composed_structure, operators, variable_names
    )
    check_buffered(composed_expression, @. X[1, :]^2 + 1.0 + 2.0 * X[1, :] - 0.5)

    repeated_structure = TemplateStructure{(:f,)}(((; f), (x1, x2)) -> f(x1) + f(x2))
    repeated_expression = TemplateExpression(
        (; f); structure=repeated_structure, operators, variable_names
    )
    repeated_eval_context = check_buffered(
        repeated_expression, @. X[1, :]^2 + X[2, :]^2 + 2.0
    )

    nested_structure = TemplateStructure{(:f, :g)}(((; f, g), (x1, x2)) -> f(g(x1)))
    nested_expression = TemplateExpression(
        (; f, g); structure=nested_structure, operators, variable_names
    )
    check_buffered(nested_expression, @. (2.0 * X[1, :] - 0.5)^2 + 1.0)

    options = Options(;
        operators, expression_spec=TemplateExpressionSpec(; structure=repeated_structure)
    )
    dataset = Dataset(X, zeros(size(X, 2)))
    repeated_eval_context.buffer.index[] = 1000
    loss = eval_loss(
        repeated_expression,
        dataset,
        options;
        regularization=false,
        eval_context=repeated_eval_context,
    )
    @test isfinite(loss)
    @test repeated_eval_context.buffer.index[] < 1000

    buffered_metadata = EvalContext(; buffer=ArrayBuffer(Vector{Vector{Float64}}(), Ref(0)))
    @test_throws ArgumentError ComposableExpression(
        Node{Float64}(; feature=1); operators, eval_context=buffered_metadata
    )
end
