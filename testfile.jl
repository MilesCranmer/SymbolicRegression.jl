using SymbolicRegression
using LinearAlgebra
using SymbolicUtils
using SymbolicRegression: Node

_inv(x) = 1/x
options = Options(
    binary_operators=(+, *, ^, /, greater),
    unary_operators=(_inv,),
    constraints=(_inv=>4,),
    npopulations=4
)
tree = Node(5, (Node(3.0) * Node(1, Node("x1"))) ^ 2.0, -1.2)
eqn = node_to_symbolic(tree, options; index_functions=false)
tree2 = symbolic_to_node(eqn, options)
