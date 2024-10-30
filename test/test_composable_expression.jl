
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
