using SymbolicRegression
using Test

options = Options(; binary_operators=(+, *, ^, /, greater), unary_operators=(cos,))
tree = Node(3, (Node(3.0) * Node(1, Node("x1")))^2.0, -1.2)
x = hash(tree)
@test typeof(x) == UInt
