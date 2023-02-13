using SymbolicRegression
using SymbolicRegression: check_constraints
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
violating_tree = Node(1, tree)

@test check_constraints(tree, options) == true
@test check_constraints(violating_tree, options) == false

# Test complexity constraints:
options = Options(; binary_operators=(+, *), maxsize=5)
@extend_operators options
x1, x2, x3 = [Node(; feature=i) for i in 1:3]
tree = x1 + x2 * x3
violating_tree = 5.1 * tree
@test check_constraints(tree, options) == true
@test check_constraints(violating_tree, options) == false

# Also test for custom complexities:
options = Options(; binary_operators=(+, *), maxsize=5, complexity_of_operators=[(*) => 3])
@test check_constraints(tree, options) == false
options = Options(; binary_operators=(+, *), maxsize=5, complexity_of_operators=[(*) => 0])
@test check_constraints(violating_tree, options) == true
