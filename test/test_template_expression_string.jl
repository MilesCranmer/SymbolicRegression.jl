@testitem "template expression string representation" tags = [:part1, :template_string] begin
    using SymbolicRegression
    using StyledStrings: @styled_str, annotatedstring, AnnotatedString
    using DynamicExpressions: string_tree

    # Create a simple template structure with one expression and one parameter vector
    struct_simple = TemplateStructure{(:f,),(:p,)}(
        ((; f), (; p), (x,)) -> f(x) + sum(p); num_parameters=(; p=2)
    )

    # Create a simple expression: f(x) = x
    operators = Options().operators
    variable_names = ["x"]
    x = ComposableExpression(Node{Float64}(; feature=1); operators, variable_names)

    # Create template expression with parameters
    expr = TemplateExpression(
        (; f=x);
        structure=struct_simple,
        operators=operators,
        variable_names=variable_names,
        parameters=(; p=[1.0, 2.0]),
    )

    # Test string representation with pretty=false (compact form)
    str_compact = string_tree(expr; pretty=false)
    @test str_compact isa AnnotatedString
    # Should be something like: "f = #1; p = [1.0, 2.0]"
    @test occursin("f = ", str_compact)
    @test occursin("; p = ", str_compact)
    @test occursin("[1.0, 2.0]", str_compact)

    # Test string representation with pretty=true (tree form)
    str_pretty = string_tree(expr; pretty=true)
    @test str_pretty isa AnnotatedString
    # Should be something like:
    # ╭ f = #1
    # ╰ p = [1.0, 2.0]
    @test occursin("╭ f = ", str_pretty)
    @test occursin("\n╰ p = ", str_pretty)
    @test occursin("[1.0, 2.0]", str_pretty)

    # Test that expression and parameters have different colors
    # The expression should be magenta and parameters should be green
    # based on the _colors function in TemplateExpression.jl

    # Test color presence by checking annotations directly
    @test any(
        annotation.label == :face && annotation.value == :magenta for
        annotation in str_pretty.annotations
    )
    @test any(
        annotation.label == :face && annotation.value == :green for
        annotation in str_pretty.annotations
    )
    @test !any(
        annotation.label == :face && annotation.value == :red for
        annotation in str_pretty.annotations
    )

    # Test with longer parameter vector to verify truncation
    expr_long = TemplateExpression(
        (; f=x);
        structure=TemplateStructure{(:f,),(:p,)}(
            ((; f), (; p), (x,)) -> f(x) + sum(p); num_parameters=(; p=6)
        ),
        operators=operators,
        variable_names=variable_names,
        parameters=(; p=collect(1.0:6.0)),
    )

    str_long = string_tree(expr_long; pretty=true)
    # Should show truncated form: [1.0, 2.0, 3.0, ..., 6.0]
    @test occursin("[1.0, 2.0, 3.0, ..., 6.0]", str_long)
end
