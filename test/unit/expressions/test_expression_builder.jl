# This file tests particular functionality of ExpressionBuilderModule
@testitem "NamedTuple support in parse_expression" begin
    using SymbolicRegression
    using DynamicExpressions

    # Test basic NamedTuple parsing for template expressions
    operators = OperatorEnum(; binary_operators=[+, -, *, /], unary_operators=[cos, sin])
    variable_names = ["x1", "x2"]

    # Create a simple template using @template_spec macro
    template = @template_spec(expressions = (f, g)) do x1, x2
        f(x1, x2) * g(x1, x2)  # Simple multiplication combination
    end
    options = Options(; operators, expression_spec=template)

    # Test NamedTuple parsing with expression_options using #N placeholder syntax
    named_tuple_input = (; f="#1 + 1.0", g="#2 - 0.5")
    result = parse_expression(
        named_tuple_input;
        options.expression_options,
        operators,
        expression_type=TemplateExpression,
        node_type=Node{Float64,2},
    )

    @test result isa TemplateExpression
    @test result.trees.f isa ComposableExpression
    @test result.trees.g isa ComposableExpression
    @test length(result.trees) == 2
    @test keys(result.trees) == (:f, :g)

    # Test NamedTuple parsing with expression_spec
    result_with_spec = parse_expression(
        named_tuple_input; expression_spec=template, operators, node_type=Node{Float64,2}
    )

    @test result_with_spec isa TemplateExpression
    @test typeof(result_with_spec) == typeof(result)

    # Test that different expression strings create different expressions using #N syntax
    different_input = (; f="cos(#1)", g="sin(#2)")
    different_result = parse_expression(
        different_input;
        options.expression_options,
        operators,
        expression_type=TemplateExpression,
        node_type=Node{Float64},
    )

    @test different_result isa TemplateExpression
    @test different_result.trees.f isa ComposableExpression
    @test different_result.trees.g isa ComposableExpression
end

@testitem "ParametricExpression" begin
    using SymbolicRegression
    using SymbolicRegression.ExpressionBuilderModule:
        strip_metadata, embed_metadata, init_params

    options = Options()
    ex = parse_expression(
        :(x1 * p1);
        expression_type=ParametricExpression,
        operators=options.operators,
        parameters=ones(2, 1) * 3,
        parameter_names=["p1", "p2"],
        variable_names=["x1"],
    )
    X = ones(1, 1) * 2
    y = ones(1)
    dataset = Dataset(X, y; extra=(; class=[1]))

    @test ex isa ParametricExpression
    @test ex(dataset.X, dataset.extra.class) ≈ ones(1, 1) * 6

    # Mistake in that we gave the wrong options!
    @test_throws(
        AssertionError(
            "Need prototype to be of type $(options.expression_type), but got $(ex)::$(typeof(ex))",
        ),
        init_params(options, dataset, ex, Val(true))
    )

    options = Options(; expression_spec=ParametricExpressionSpec(; max_parameters=2))

    # Mistake in that we also gave the wrong number of parameter names!
    pop!(ex.metadata.parameter_names)
    @test_throws(
        AssertionError(
            "Mismatch between options.expression_options.max_parameters=$(options.expression_options.max_parameters) and prototype.metadata.parameter_names=$(ex.metadata.parameter_names)",
        ),
        init_params(options, dataset, ex, Val(true))
    )
    # So, we fix it:
    push!(ex.metadata.parameter_names, "p2")

    @test ex.metadata.parameter_names == ["p1", "p2"]
    @test keys(init_params(options, dataset, ex, Val(true))) ==
        (:operators, :variable_names, :parameters, :parameter_names)

    @test sprint(show, ex) == "x1 * p1"
    stripped_ex = strip_metadata(ex, options, dataset)
    # Stripping the metadata means that operations like `show`
    # do not know what binary operator to use:
    @test sprint(show, stripped_ex) == "binary_operator[4](x1, p1)"

    # However, it's important that parametric expressions are still parametric:
    @test stripped_ex isa ParametricExpression
    # And, that they still have the right parameters:
    @test haskey(getfield(stripped_ex.metadata, :_data), :parameters)
    @test stripped_ex.metadata.parameters ≈ ones(2, 1) * 3

    # Now, test that we can embed metadata back in:
    embedded_ex = embed_metadata(stripped_ex, options, dataset)
    @test embedded_ex isa ParametricExpression
    @test ex == embedded_ex
end
