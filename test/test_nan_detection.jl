println("Testing NaN detection.")
using SymbolicRegression
using Test

for T in [Float16, Float32, Float64], turbo in [true, false]
    T == Float16 && turbo && continue
    local options, tree, X

    options = Options(; binary_operators=(+, *, /, -), unary_operators=(cos, sin, exp))
    # Creating a NaN via computation.
    tree = exp(exp(exp(exp(Node("x1") + 1))))
    tree = convert(Node{T}, tree)
    X = ones(T, 1, 10) .* 100
    output, flag = eval_tree_array(tree, X, options; turbo=turbo)
    @test !flag

    # Creating a NaN/Inf via division by constant zero.
    tree = cos(Node("x1") / 0.0f0)
    tree = convert(Node{T}, tree)
    output, flag = eval_tree_array(tree, X, options; turbo=turbo)
    @test !flag

    # Having a NaN/Inf constants:
    tree = cos(Node("x1") + T(Inf))
    tree = convert(Node{T}, tree)
    output, flag = eval_tree_array(tree, X, options; turbo=turbo)
    @test !flag
    tree = cos(Node("x1") + T(NaN))
    tree = convert(Node{T}, tree)
    output, flag = eval_tree_array(tree, X, options; turbo=turbo)
    @test !flag
end

println("Passed.")