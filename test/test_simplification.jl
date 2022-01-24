using SymbolicRegression, Test

binary_operators = (+, -, /, *)

index_of_mult = [i for (i, op) in enumerate(binary_operators) if op == *][1]

options = Options(binary_operators=binary_operators)

tree = Node("x1") + Node("x1")

# Should simplify to 2*x1:
eqn = node_to_symbolic(tree, options; index_functions=true)
eqn2 = custom_simplify(eqn, options)

@test occursin("2", "$(eqn2[1])")

# Repeat test with simplifyWithSymbolicUtils:
simple_tree = simplifyWithSymbolicUtils(tree, options, 5)

# Check that the first operator is *, for 2 * x1:
@test simple_tree.op == index_of_mult

tree = Node("x1") * Node("x1") + Node("x1") * Node("x1")

# Should not convert this to power:
@test !occursin("^", stringTree(simplifyWithSymbolicUtils(tree, options), options))