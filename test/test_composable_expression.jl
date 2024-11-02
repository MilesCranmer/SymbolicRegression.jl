@testitem "Integration Test with fit! and Performance Check" tags = [:part3] begin
    include("../examples/template_expression.jl")
end
@testitem "Test ComposableExpression" tags = [:part2] begin
    using SymbolicRegression: ComposableExpression, Node
    using DynamicExpressions: OperatorEnum

    operators = OperatorEnum(; binary_operators=(+, *, /, -), unary_operators=(sin, cos))
    variable_names = (i -> "x$i").(1:3)
    ex = ComposableExpression(Node(Float64; feature=1); operators, variable_names)
    x = randn(32)
    y = randn(32)

    @test ex(x, y) == x
end

@testitem "Test interface for ComposableExpression" tags = [:part2] begin
    using SymbolicRegression: ComposableExpression
    using DynamicExpressions.InterfacesModule: Interfaces, ExpressionInterface
    using DynamicExpressions: OperatorEnum

    operators = OperatorEnum(; binary_operators=(+, *, /, -), unary_operators=(sin, cos))
    variable_names = (i -> "x$i").(1:3)
    x1 = ComposableExpression(Node(Float64; feature=1); operators, variable_names)
    x2 = ComposableExpression(Node(Float64; feature=2); operators, variable_names)

    f = x1 * sin(x2)
    g = f(f, f)

    @test string_tree(f) == "x1 * sin(x2)"
    @test string_tree(g) == "(x1 * sin(x2)) * sin(x1 * sin(x2))"

    @test Interfaces.test(ExpressionInterface, ComposableExpression, [f, g])
end

@testitem "Test interface for TemplateExpression" tags = [:part2] begin
    using SymbolicRegression
    using SymbolicRegression: TemplateExpression
    using DynamicExpressions.InterfacesModule: Interfaces, ExpressionInterface
    using DynamicExpressions: OperatorEnum

    operators = OperatorEnum(; binary_operators=(+, *, /, -), unary_operators=(sin, cos))
    variable_names = (i -> "x$i").(1:3)
    x1 = ComposableExpression(Node(Float64; feature=1); operators, variable_names)
    x2 = ComposableExpression(Node(Float64; feature=2); operators, variable_names)

    structure = TemplateStructure{(:f, :g)}(
        ((; f, g), (x1, x2)) -> f(f(f(x1))) - f(g(x2, x1))
    )
    @test structure.num_features == (; f=1, g=2)

    expr = TemplateExpression((; f=x1, g=x2 * x2); structure, operators, variable_names)

    @test String(string_tree(expr)) == "f = #1; g = #2 * #2"
    @test String(string_tree(expr; pretty=true)) == "f = #1\ng = #2 * #2"
    @test string_tree(get_tree(expr), operators) == "x1 - (x1 * x1)"
    @test Interfaces.test(ExpressionInterface, TemplateExpression, [expr])
end

@testitem "Printing and evaluation of TemplateExpression" tags = [:part2] begin
    using SymbolicRegression

    structure = TemplateStructure{(:f, :g)}(
        ((; f, g), (x1, x2, x3)) -> sin(f(x1, x2)) + g(x3)^2
    )
    operators = Options().operators
    variable_names = ["x1", "x2", "x3"]

    x1, x2, x3 = [
        ComposableExpression(Node{Float64}(; feature=i); operators, variable_names) for
        i in 1:3
    ]
    f = x1 * x2
    g = x1
    expr = TemplateExpression((; f, g); structure, operators, variable_names)

    # Default printing strategy:
    @test String(string_tree(expr)) == "f = x1 * x2\ng = x1"

    x1_val = randn(5)
    x2_val = randn(5)

    # The feature indicates the index passed as argument:
    @test x1(x1_val) ≈ x1_val
    @test x2(x1_val, x2_val) ≈ x2_val
    @test x1(x2_val) ≈ x2_val

    # Composing expressions and then calling:
    @test String(string_tree((x1 * x2)(x3, x3))) == "x3 * x3"

    # Can evaluate with `sin` even though it's not in the allowed operators!
    X = randn(3, 5)
    x1_val = X[1, :]
    x2_val = X[2, :]
    x3_val = X[3, :]
    @test expr(X) ≈ @. sin(x1_val * x2_val) + x3_val^2

    # This is even though `g` is defined on `x1` only:
    @test g(x3_val) ≈ x3_val
end

@testitem "Test error handling" tags = [:part2] begin
    using SymbolicRegression
    using SymbolicRegression: ComposableExpression, Node, ValidVector
    using DynamicExpressions: OperatorEnum

    operators = OperatorEnum(; binary_operators=(+, *, /, -), unary_operators=(sin, cos))
    variable_names = (i -> "x$i").(1:3)
    ex = ComposableExpression(Node{Float64}(; feature=1); operators, variable_names)

    # Test error for unsupported input type with specific message
    @test_throws "ComposableExpression does not support input of type String" ex(
        "invalid input"
    )

    # Test ValidVector operations with numbers
    x = ValidVector([1.0, 2.0, 3.0], true)

    # Test binary operations between ValidVector and Number
    @test (x + 2.0).x ≈ [3.0, 4.0, 5.0]
    @test (2.0 + x).x ≈ [3.0, 4.0, 5.0]
    @test (x * 2.0).x ≈ [2.0, 4.0, 6.0]
    @test (2.0 * x).x ≈ [2.0, 4.0, 6.0]

    # Test unary operations on ValidVector
    @test sin(x).x ≈ sin.([1.0, 2.0, 3.0])
    @test cos(x).x ≈ cos.([1.0, 2.0, 3.0])
    @test abs(x).x ≈ [1.0, 2.0, 3.0]
    @test (-x).x ≈ [-1.0, -2.0, -3.0]

    # Test propagation of invalid flag
    invalid_x = ValidVector([1.0, 2.0, 3.0], false)
    @test !((invalid_x + 2.0).valid)
    @test !((2.0 + invalid_x).valid)
    @test !(sin(invalid_x).valid)

    # Test that regular numbers are considered valid
    @test (x + 2).valid
    @test sin(x).valid
end
@testitem "Test validity propagation with NaN" tags = [:part2] begin
    using SymbolicRegression: ComposableExpression, Node, ValidVector
    using DynamicExpressions: OperatorEnum

    operators = OperatorEnum(; binary_operators=(+, *, /, -), unary_operators=(sin, cos))
    variable_names = (i -> "x$i").(1:3)
    x1 = ComposableExpression(Node{Float64}(; feature=1); operators, variable_names)
    x2 = ComposableExpression(Node{Float64}(; feature=2); operators, variable_names)
    x3 = ComposableExpression(Node{Float64}(; feature=3); operators, variable_names)

    ex = 1.0 + x2 / x1

    @test ex([1.0], [2.0]) ≈ [3.0]

    @test ex([1.0, 1.0], [2.0, 2.0]) |> Base.Fix1(count, isnan) == 0
    @test ex([1.0, 0.0], [2.0, 2.0]) |> Base.Fix1(count, isnan) == 2

    x1_val = ValidVector([1.0, 2.0], false)
    x2_val = ValidVector([1.0, 2.0], false)
    @test ex(x1_val, x2_val).valid == false
end

@testitem "Test nothing return and type inference for TemplateExpression" tags = [:part2] begin
    using SymbolicRegression
    using Test: @inferred

    # Create a template expression that divides by x1
    structure = TemplateStructure{(:f,)}(((; f), (x1, x2)) -> 1.0 + f(x1) / x1)
    operators = Options(; binary_operators=(+, -, *, /)).operators
    variable_names = ["x1", "x2"]

    x1 = ComposableExpression(Node{Float64}(; feature=1); operators, variable_names)
    x2 = ComposableExpression(Node{Float64}(; feature=2); operators, variable_names)
    expr = TemplateExpression((; f=x1); structure, operators, variable_names)

    # Test division by zero returns nothing
    X = [0.0 1.0]'
    @test expr(X) === nothing

    # Test type inference
    X_good = [1.0 2.0]'
    @test @inferred(Union{Nothing,Vector{Float64}}, expr(X_good)) ≈ [2.0]

    # Test type inference with ValidVector input
    x1_val = ValidVector([1.0], true)
    x2_val = ValidVector([2.0], true)
    @test @inferred(ValidVector{Vector{Float64}}, x1(x1_val, x2_val)).x ≈ [1.0]

    x2_val_false = ValidVector([2.0], false)
    @test @inferred(x1(x1_val, x2_val_false)).valid == false
end
