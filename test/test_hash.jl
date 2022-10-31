using SymbolicRegression
using Test

options = Options(; binary_operators=(+, *, ^, /, greater), unary_operators=(cos,))
@extend_operators options
tree = Node(3, safe_pow(Node(; val=3.0) * Node(1, Node("x1")), 2.0), Node(; val=-1.2))
x = hash(tree)
@test typeof(x) == UInt
