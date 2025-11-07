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

@testitem "Cover other operators" tags = [:part2] begin
    using SymbolicRegression
    using SymbolicRegression: ComposableExpression, Node
    using DynamicExpressions: OperatorEnum

    operators = OperatorEnum(; binary_operators=(>, >=, <, <=))
    x1 = ComposableExpression(Node(Float64; feature=1); operators)
    x2 = ComposableExpression(Node(Float64; feature=2); operators)

    expr = x1 > x2
    @test string_tree(expr) == "x1 > x2"
    expr = x1 >= x2
    @test string_tree(expr) == "x1 >= x2"
    expr = x1 < x2
    @test string_tree(expr) == "x1 < x2"
    expr = x1 <= x2
    @test string_tree(expr) == "x1 <= x2"
    expr = x1 > 1.0
    @test string_tree(expr) == "x1 > 1.0"
    expr = x1 >= 1.0
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
    y = ValidVector([0.0, 2.0, 4.0], true)

    # Test binary operations between ValidVector and Number
    @test (x + 2.0).x ≈ [3.0, 4.0, 5.0]
    @test (2.0 + x).x ≈ [3.0, 4.0, 5.0]
    @test (x * 2.0).x ≈ [2.0, 4.0, 6.0]
    @test (2.0 * x).x ≈ [2.0, 4.0, 6.0]

    # Test comparison operators
    @test (x > y).x ≈ [1.0, 0.0, 0.0]
    @test (x < y).x ≈ [0.0, 0.0, 1.0]
    @test (x >= y).x ≈ [1.0, 1.0, 0.0]
    @test (x <= y).x ≈ [0.0, 1.0, 1.0]
    @test (x > 1.5).x ≈ [0.0, 1.0, 1.0]
    @test (1.5 > x).x ≈ [1.0, 0.0, 0.0]
    @test max(x, y).x ≈ [1.0, 2.0, 4.0]
    @test min(x, y).x ≈ [0.0, 2.0, 3.0]
    @test max(x, 2.0).x ≈ [2.0, 2.0, 3.0]
    @test min(x, 2.0).x ≈ [1.0, 2.0, 2.0]

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
