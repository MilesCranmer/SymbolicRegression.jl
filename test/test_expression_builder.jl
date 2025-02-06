# This file tests particular functionality of ExpressionBuilderModule
@testitem "ParametricExpression" tags = [:part3] begin
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
