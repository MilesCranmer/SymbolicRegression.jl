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

@testitem "Test interface" tags = [:part2] begin
    using SymbolicRegression: ComposableExpression
    using DynamicExpressions.InterfacesModule: Interfaces, ExpressionInterface
    using DynamicExpressions: OperatorEnum

    operators = OperatorEnum(; binary_operators=(+, *, /, -), unary_operators=(sin, cos))
    variable_names = (i -> "x$i").(1:3)
    f = ComposableExpression(Node(Float64; feature=1); operators, variable_names)

    @test Interfaces.test(ExpressionInterface, ComposableExpression, [f])
end

@testitem "Printing and evaluation of HierarchicalExpression" begin
    using SymbolicRegression

    structure = HierarchicalStructure{(:f, :g)}(
        ((; f, g), (x1, x2, x3)) -> let
            sin(f(x1, x2)) + g(x3)^2
        end
    )
    operators = Options().operators
    variable_names = ["x1", "x2", "x3"]

    x1, x2, x3 = [
        ComposableExpression(Node{Float64}(; feature=i); operators, variable_names) for
        i in 1:3
    ]
    f = x1 * x2
    g = x1
    expr = HierarchicalExpression((; f, g); structure, operators, variable_names)

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
