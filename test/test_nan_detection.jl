println("Testing NaN detection.")
using SymbolicRegression

for T in [Float32]
    options = Options(; binary_operators=(+, *, /, -), unary_operators=(cos, sin, exp))
    # Creating a NaN via computation.
    tree = exp(exp(exp(exp(Node("x1") + T(1)))))
    X = ones(T, 1, 10) .* 100
    output, flag = eval_tree_array(tree, X, options)
    @test !flag

    # Creating a NaN/Inf via division by constant zero.
    tree = cos(Node("x1") / 0.0f0)
    tree = convert(Node{T}, tree)
    output, flag = eval_tree_array(tree, X, options)
    @test !flag

    # Having a NaN/Inf constants:
    tree = cos(Node("x1") + T(Inf))
    output, flag = eval_tree_array(tree, X, options)
    @test !flag
    tree = cos(Node("x1") + T(NaN))
    output, flag = eval_tree_array(tree, X, options)
    @test !flag
end

println("Passed.")
