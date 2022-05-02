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
