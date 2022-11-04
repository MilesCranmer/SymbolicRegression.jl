println("Testing NaN detection.")
using SymbolicRegression
using Test

for T in [Float16, Float32, Float64], turbo in [true, false]
    T == Float16 && turbo && continue
    local options, tree, X

    options = Options(;
        binary_operators=(+, *, /, -, ^), unary_operators=(cos, sin, exp, sqrt), turbo=turbo
    )
    @extend_operators options
    # Creating a NaN via computation.
    tree = exp(exp(exp(exp(Node(T; feature=1) + 1))))
    tree = convert(Node{T}, tree)
    X = fill(T(100), 1, 10)
    output, flag = eval_tree_array(tree, X, options)
    @test !flag

    # Creating a NaN/Inf via division by constant zero.
    tree = cos(Node(T; feature=1) / zero(T))
    tree = convert(Node{T}, tree)
    output, flag = eval_tree_array(tree, X, options)
    @test !flag

    # Creating a NaN via sqrt(-1):
    tree = safe_sqrt(Node(T; feature=1) - 1)
    tree = convert(Node{T}, tree)
    X = fill(T(0), 1, 10)
    output, flag = eval_tree_array(tree, X, options)
    @test !flag

    # Creating a NaN via pow(-1, 0.5):
    tree = safe_pow(Node(T; feature=1) - 1, 0.5)
    tree = convert(Node{T}, tree)
    X = fill(T(0), 1, 10)
    output, flag = eval_tree_array(tree, X, options)
    @test !flag

    # Having a NaN/Inf constants:
    tree = cos(Node(T; feature=1) + T(Inf))
    tree = convert(Node{T}, tree)
    output, flag = eval_tree_array(tree, X, options)
    @test !flag
    tree = cos(Node(T; feature=1) + T(NaN))
    tree = convert(Node{T}, tree)
    output, flag = eval_tree_array(tree, X, options)
    @test !flag
end

println("Passed.")
