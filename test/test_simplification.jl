using SymbolicRegression, Test

options = Options(binary_operators=(+, -, /, *))

tree = Node("x1") + Node("x1")

# Should simplify to 2*x1:
eqn = node_to_symbolic(tree, options; index_functions=true)
eqn2 = custom_simplify(eqn, options)

@test "$(eqn2[1])" == "2x1"
