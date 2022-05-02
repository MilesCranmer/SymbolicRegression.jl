using SymbolicRegression, BenchmarkTools, Random
using SymbolicRegression: eval_tree_array

const SUITE = BenchmarkGroup()

options = Options(; binary_operators=(+, -, /, *), unary_operators=(cos, exp))
tree = Node(
    2,
    Node(
        1,
        Node(3, Node(1, Node(1.0f0), Node(2)), Node(2, Node(-1.0f0))),
        Node(1, Node(3), Node(4)),
    ),
    Node(
        4,
        Node(3, Node(1, Node(1.0f0), Node(2)), Node(2, Node(-1.0f0))),
        Node(1, Node(3), Node(4)),
    ),
)

_X = randn(MersenneTwister(0), Float32, 5, 1000)

SUITE["evaluation"] = BenchmarkGroup()
for T in [Float32, Float64, BigFloat]
    X = map(x -> convert(T, x), _X)
    f = eval_tree_array
    SUITE["evaluation"][string(T)] = @benchmarkable ($f)(tree, $X, options)
end
