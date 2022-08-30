println("Testing NaN detection.")
using SymbolicRegression
using Random

for T in [Float16, Float32, Float64]
    options = Options(binary_operators=(+, *, /, -), unary_operators=(cos, sin, exp))
    # Creating a NaN via computation.
    tree = cos(exp(exp(exp(exp(Node("x1"))))))
    tree = convert(Node{T}, tree)
    X = randn(MersenneTwister(0), T, 1, 100) * 100.0f0
    output, flag = eval_tree_array(tree, X, options)
    @test !flag

    # Creating a NaN/Inf via division by constant zero.
    tree = cos(Node("x1") / 0.0f0)
    tree = convert(Node{T}, tree)
    output, flag = eval_tree_array(tree, X, options)
    @test !flag

    # Having a NaN/Inf constants:
    tree = cos(Node("x1") + Inf)
    tree = convert(Node{T}, tree)
    output, flag = eval_tree_array(tree, X, options)
    @test !flag
    tree = cos(Node("x1") + NaN)
    tree = convert(Node{T}, tree)
    output, flag = eval_tree_array(tree, X, options)
    @test !flag
end

println("Passed.")
