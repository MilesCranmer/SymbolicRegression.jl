@testitem "template expression color function" tags = [:part1, :template_colors] begin
    using SymbolicRegression.TemplateExpressionModule: _colors

    # Test empty case
    @test _colors(Val(0)) == ()

    # Test n <= 6 cases
    @test _colors(Val(1)) == (:magenta,)
    @test _colors(Val(2)) == (:magenta, :green)
    @test _colors(Val(6)) == (:magenta, :green, :red, :blue, :yellow, :cyan)

    # Test n > 6 cases to verify color cycling
    colors_7 = _colors(Val(7))
    @test length(colors_7) == 7
    @test colors_7[1:6] == (:magenta, :green, :red, :blue, :yellow, :cyan)
    @test colors_7[7] == :magenta  # Should cycle back to first color

    colors_8 = _colors(Val(8))
    @test length(colors_8) == 8
    @test colors_8[7:8] == (:magenta, :green)  # Should cycle colors properly
end

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
    if VERSION >= v"1.11.0-"
        @test str_compact isa AnnotatedString
    end
    # Should be something like: "f = #1; p = [1.0, 2.0]"
    @test occursin("f = ", str_compact)
    @test occursin("; p = ", str_compact)
    @test occursin("[1.0, 2.0]", str_compact)

    # Test string representation with pretty=true (tree form)
    str_pretty = string_tree(expr; pretty=true)
    if VERSION >= v"1.11.0-"
        @test str_pretty isa AnnotatedString
    end
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
    if VERSION >= v"1.11.0-"
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
    end

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
