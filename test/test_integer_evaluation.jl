using SymbolicRegression
using Random
using Test
include("test_params.jl")

# Test evaluation on integer-based trees.
options = Options(;
    default_params..., binary_operators=(+, *, /, -), unary_operators=(square,)
)

nodefnc(x1, x2, x3) = x2 * x3 + Int32(2) - square(x1)

x1, x2, x3 = Node("x1"), Node("x2"), Node("x3")
tree = nodefnc(x1, x2, x3)

tree = convert(Node{Int32}, tree)
X = Int32.(rand(MersenneTwister(0), -5:5, 3, 100))

true_out = nodefnc.(X[1, :], X[2, :], X[3, :])
@test eltype(true_out) == Int32
out, flag = eval_tree_array(tree, X, options)
@test flag
@test isapprox(out, true_out)
@test eltype(out) == Int32
