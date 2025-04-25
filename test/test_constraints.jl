using DynamicExpressions: count_depth
using SymbolicRegression
using SymbolicRegression: check_constraints
include("test_params.jl")

_inv(x) = 1 / x
options = Options(;
    default_params...,
    binary_operators=(+, *, ^, /, greater),
    unary_operators=(_inv,),
    constraints=(_inv => 4,),
    populations=4,
)
@extend_operators options
tree = Node(5, (^)(Node(; val=3.0) * Node(1, Node("x1")), 2.0), Node(; val=-1.2))
violating_tree = Node(1, tree)

@test check_constraints(tree, options) == true
@test check_constraints(violating_tree, options) == false

# https://github.com/MilesCranmer/PySR/issues/896
x1 = Node(; feature=1)
complex_expr = x1 * x1 * x1 * x1 * x1  # Complex expression with complexity > 4
inv_complex = Node(1, complex_expr)  # _inv applied to complex expression
binary_with_nested_inv = Node(5, x1, inv_complex)  # _inv nested inside binary op, not at root
@test check_constraints(binary_with_nested_inv, options) == false

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

# Test for depth constraints:
options = Options(;
    binary_operators=(+, *), unary_operators=(cos,), maxsize=100, maxdepth=3
)
@extend_operators options
x1, x2, x3 = [Node(; feature=i) for i in 1:3]

tree = (x1 + x2) + (x3 + x1)
@test count_depth(tree) == 3
@test check_constraints(tree, options) == true

tree = (x1 + x2) + (x3 + x1) * x1
@test count_depth(tree) == 4
@test check_constraints(tree, options) == false

tree = cos(cos(x1))
@test count_depth(tree) == 3
@test check_constraints(tree, options) == true

tree = cos(cos(cos(x1)))
@test count_depth(tree) == 4
@test check_constraints(tree, options) == false
