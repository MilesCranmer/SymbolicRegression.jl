using SymbolicRegression
using Test
include("test_params.jl")

_inv(x) = 1 / x
options = Options(;
    default_params...,
    binary_operators=(+, *, ^, /, greater),
    unary_operators=(_inv,),
    constraints=(_inv => 4,),
    npopulations=4,
)
@extend_operators options
tree = Node(5, safe_pow(Node(; val=3.0) * Node(1, Node("x1")), 2.0), Node(; val=-1.2))

eqn = node_to_symbolic(tree, options; varMap=["energy"], index_functions=true)
@test string(eqn) == "greater(safe_pow(3.0_inv(energy), 2.0), -1.2)"

tree2 = symbolic_to_node(eqn, options; varMap=["energy"])
@test string_tree(tree, options) == string_tree(tree2, options)
