include("test_params.jl")
using SymbolicRegression, Test

binary_operators = (+, -, /, *)

index_of_mult = [i for (i, op) in enumerate(binary_operators) if op == *][1]

options = Options(; default_params..., binary_operators=binary_operators)

tree = Node("x1") + Node("x1")

# Should simplify to 2*x1:
import SymbolicUtils: simplify, Symbolic

eqn = convert(Symbolic, tree, options)
eqn2 = simplify(eqn)
# Should correctly simplify to 2 x1:
@test occursin("2", "$(repr(eqn2)[1])")

# Let's convert back:
tree = convert(Node, eqn2, options)
# Make sure one of the nodes is now 2.0:
@test (tree.l.constant ? tree.l : tree.r).val == 2
# Make sure the other node is x1:
@test (!tree.l.constant ? tree.l : tree.r).feature == 1

# Finally, let's try simplifying a product, and ensure
# that SymbolicUtils does not convert it to a power:
tree = Node("x1") * Node("x1")
eqn = convert(Symbolic, tree, options)
@test repr(eqn) == "x1*x1"
# Test converting back:
tree_copy = convert(Node, eqn, options)
@test repr(tree_copy) == "(x1 * x1)"
