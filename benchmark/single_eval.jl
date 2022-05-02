using BenchmarkTools
using SymbolicRegression

nfeatures = 3
X = randn(nfeatures, 200)
options = Options(; binary_operators=(+, *, /, -), unary_operators=(cos, sin))

x1 = Node("x1")
x2 = Node("x2")
x3 = Node("x3")

# 48 nodes in this tree:
tree = (
    ((x2 + x2) * ((-0.5982493 / x1) / -0.54734415)) + (
        sin(
            cos(
                sin(1.2926733 - 1.6606787) /
                sin(((0.14577048 * x1) + ((0.111149654 + x1) - -0.8298334)) - -1.2071426),
            ) * (cos(x3 - 2.3201916) + ((x1 - (x1 * x2)) / x2)),
        ) / (0.14854191 - ((cos(x2) * -1.6047639) - 0.023943262))
    )
)

function testfunc()
    out = eval_tree_array(tree, X, options)
    return nothing
end
@btime testfunc()
