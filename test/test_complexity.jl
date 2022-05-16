println("Testing custom complexities.")
using SymbolicRegression, Test

x1, x2, x3 = Node("x1"), Node("x2"), Node("x3")

# First, test regular complexities:
function make_options(; kw...)
    return Options(; binary_operators=(+, -, *, /, ^), unary_operators=(cos, sin), kw...)
end
options = make_options()
tree = sin((x1 + x2 + x3)^2.3)
@test compute_complexity(tree, options) == 8

# - `complexity_of_operators`: What complexity should be assigned to each operator,
#     and the occurrence of a constant or variable. By default, this is 1
#     for all operators. Can be a real number as well, in which case
#     the complexity of an expression will be rounded to the nearest integer.
#     Input this in the form of, e.g., [(^)]
# - `complexity_of_constant`: What complexity should be assigned to use of a constant.
#     By default, this is 1.
# - `complexity_of_variable`: What complexity should be assigned to each variable.
#     By default, this is 1.

options = make_options(complexity_of_operators=[sin => 3])
@test compute_complexity(tree, options) == 10
options = make_options(complexity_of_operators=[sin => 3, (+) => 2])
@test compute_complexity(tree, options) == 12

# Real numbers:
options = make_options(complexity_of_operators=[sin => 3, (+) => 2, (^) => 3.2])
@test compute_complexity(tree, options) == round(Int, 12 + (3.2 - 1))

# Now, test other things, like variables and constants:
options = make_options(complexity_of_operators=[sin => 3, (+) => 2], complexity_of_variables=2)
@test compute_complexity(tree, options) == 12 + 3 * 1
options = make_options(complexity_of_operators=[sin => 3, (+) => 2], complexity_of_variables=2, complexity_of_constants=2)
@test compute_complexity(tree, options) == 12 + 3 * 1 + 1
options = make_options(complexity_of_operators=[sin => 3, (+) => 2], complexity_of_variables=2, complexity_of_constants=2.6)
@test compute_complexity(tree, options) == 12 + 3 * 1 + 1 + 1

println("Passed.")
