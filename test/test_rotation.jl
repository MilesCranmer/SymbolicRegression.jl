@testitem "Basic `randomly_rotate_tree!`" tags = [:part1] begin
    using SymbolicRegression
    using SymbolicRegression.MutationFunctionsModule: randomly_rotate_tree!
    using SymbolicRegression: Node

    # Create a simple binary tree structure directly
    options = Options(; binary_operators=(+, *, -, /), unary_operators=(cos, exp))
    x1, x2, x3 = (Node(; feature=1), Node(; feature=2), Node(; feature=3))

    # No-op:
    @test randomly_rotate_tree!(x1) === x1

    expr = 1.5 * x1 + x2

    #  (+) -> ((*) -> (1.5, x1), x2)
    # Should get rotated to
    #  (*) -> (1.5, (+) -> (x1, x2))

    @test randomly_rotate_tree!(copy(expr)) == 1.5 * (x1 + x2)

    # The only rotation option on this tree is to rotate back:
    @test randomly_rotate_tree!(randomly_rotate_tree!(copy(expr))) == expr
end

@testitem "Complex `randomly_rotate_tree!`" tags = [:part1] begin
    using SymbolicRegression
    using SymbolicRegression.MutationFunctionsModule: randomly_rotate_tree!
    using SymbolicRegression: Node

    # Create a simple binary tree structure directly
    options = Options(; binary_operators=(+, *, -, /), unary_operators=(cos, exp))
    x1, x2, x3 = (Node(; feature=1), Node(; feature=2), Node(; feature=3))

    expr = (1.5 * x1) + (2.5 / x3)

    # Multiple rotations possible:
    #  (+) -> ((*) -> (1.5, x1), (/) -> (2.5, x3))
    # This can either get rotated to
    #  (*) -> (1.5, (+) -> (x1, (/) -> (2.5, x3)))
    # OR
    #  (/) -> ((+) -> ((*) -> (1.5, x1), 2.5), x3)

    outs = Set([randomly_rotate_tree!(copy(expr)) for _ in 1:100])

    @test outs == Set([((1.5 * x1) + 2.5) / x3, 1.5 * (x1 + (2.5 / x3))])

    # Similarly, if we have a unary operator in the mix:
    expr = (1.5 * exp(x1)) + (2.5 / x3)
    outs = Set([randomly_rotate_tree!(copy(expr)) for _ in 1:100])
    @test outs == Set([((1.5 * exp(x1)) + 2.5) / x3, 1.5 * (exp(x1) + (2.5 / x3))])

    # Or, if the unary operator is at the top:
    expr = exp((1.5 * x1) + (2.5 / x3))
    outs = Set([randomly_rotate_tree!(copy(expr)) for _ in 1:100])
    @test outs == Set([exp(((1.5 * x1) + 2.5) / x3), exp(1.5 * (x1 + (2.5 / x3)))])
end
