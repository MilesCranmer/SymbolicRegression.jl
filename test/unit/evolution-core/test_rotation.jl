@testitem "Basic `randomly_rotate_tree!`" begin
    using SymbolicRegression
    using SymbolicRegression.MutationFunctionsModule: randomly_rotate_tree!

    # Create a simple binary tree structure directly
    options = Options(; binary_operators=(+, *, -, /), unary_operators=(cos, exp))
    x1, x2, x3 = (Node(; feature=1), Node(; feature=2), Node(; feature=3))

    # No-op:
    @test randomly_rotate_tree!(x1) === x1

    # There's also no change to a single op:
    @test length(Set([randomly_rotate_tree!(x1 + x2) for _ in 1:100])) == 1

    expr = (1.5 * x1) + x2

    #  (+) -> ((*) -> (1.5, x1), x2)
    # Should get rotated to one of
    #   (*) -> (1.5, (+) -> (x1, x2))
    # OR
    #   (*) -> ((+) -> (1.5, x1), x2)
    # OR
    #   (*) -> ((+) -> (1.5, x2), x1)

    for _ in 1:100
        @test randomly_rotate_tree!(copy(expr)) in
            (1.5 * (x1 + x2), (1.5 + x1) * x2, (1.5 + x2) * x1)
    end
end

@testitem "Complex `randomly_rotate_tree!`" begin
    using SymbolicRegression
    using SymbolicRegression.MutationFunctionsModule: randomly_rotate_tree!
    using Random: MersenneTwister

    # Create a simple binary tree structure directly
    options = Options(; binary_operators=(+, *, -, /), unary_operators=(cos, exp))
    x1, x2, x3 = (Node(; feature=1), Node(; feature=2), Node(; feature=3))

    expr = (1.5 * x1) + (2.5 / x3)

    # Multiple rotations possible for
    #   (+) -> ((*) -> (1.5, x1), (/) -> (2.5, x3))

    # This can either get rotated to
    #   (*) -> (1.5, (+) -> (x1, (/) -> (2.5, x3)))
    # OR
    #   (/) -> ((+) -> ((*) -> (1.5, x1), 2.5), x3)
    # OR
    #   (*) -> ((+) -> (1.5, (/) -> (2.5, x3)), x1)
    # OR
    #   (/) -> (2.5, (+) -> ((*) -> (1.5, x1), x3))

    rng = MersenneTwister(0)
    outs = Set([randomly_rotate_tree!(copy(expr), rng) for _ in 1:300])

    @test outs == Set([
        1.5 * (x1 + (2.5 / x3)),
        ((1.5 * x1) + 2.5) / x3,
        (1.5 + (2.5 / x3)) * x1,
        2.5 / ((1.5 * x1) + x3),
    ])

    # If we have a unary operator in the mix, both of these options are valid (with
    # the unary operator moved in). We also have a third option that rotates with
    # the unary operator acting as a pivot.

    expr = (1.5 * exp(x1)) + (2.5 / x3)
    rng = MersenneTwister(0)
    outs = Set([randomly_rotate_tree!(copy(expr), rng) for _ in 1:300])
    @test outs == Set([
        ((1.5 * exp(x1)) + 2.5) / x3,
        1.5 * (exp(x1) + (2.5 / x3)),
        exp(1.5 * x1) + (2.5 / x3),
        (1.5 + (2.5 / x3)) * exp(x1),
        2.5 / ((1.5 * exp(x1)) + x3),
    ])
    # Note that we can do a rotation on the `*` _through_ the unary operator:
    #  (*) -> (1.5, (exp) -> (x1,))
    # to
    #  (exp) -> ((*) -> (1.5, x1),)

    # Or, if the unary operator is at the top:
    expr = exp((1.5 * x1) + (2.5 / x3))
    rng = MersenneTwister(0)
    outs = Set([randomly_rotate_tree!(copy(expr), rng) for _ in 1:500])
    @test outs == Set([
        exp(1.5 * x1) + (2.5 / x3),
        exp(2.5 / ((1.5 * x1) + x3)),
        exp(((1.5 * x1) + 2.5) / x3),
        exp(1.5 * (x1 + (2.5 / x3))),
        exp((1.5 + (2.5 / x3)) * x1),
        # Rotate with `exp` as the *root*:
        (1.5 * x1) + exp(2.5 / x3),
    ])
end
