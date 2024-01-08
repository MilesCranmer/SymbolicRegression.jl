using SymbolicRegression
using Latexify: latexify, @L_str

options = Options(; binary_operators=(+, -, *, /), unary_operators=(cos, sin))
x1, x2, x3 = (i -> Node(Float64; feature=i)).(1:3)
tree = cos(x1 - 0.9) * x2 - 0.9 / x3

latex_output = latexify(tree, options)
@test latex_output == L"$\cos\left( x_1 - 0.9 \right) \cdot x_2 - \frac{0.9}{x_3}$"

latex_output_diff_names = latexify(tree, options; variable_names=["a", "b", "c"])
@test latex_output_diff_names == L"$\cos\left( a - 0.9 \right) \cdot b - \frac{0.9}{c}$"

@test_throws ArgumentError latexify(tree)
VERSION >= v"1.9" &&
    @test_throws "You must pass an Options object to latexify" latexify(tree)

# With weird operators:
options = Options(; binary_operators=(-,), unary_operators=(erf,))
@extend_operators options
x1 = Node(; feature=1)
tree = erf(x1 - 0.9)
@test latexify(tree, options) == L"$\mathrm{erf}\left( x_1 - 0.9 \right)$"

# With user-defined operator:
myop(x, y) = x + y
options = Options(; binary_operators=(myop,))
@extend_operators options
x1 = Node(; feature=1)
tree = myop(x1, 0.9)
@test latexify(tree, options) == L"$\mathrm{myop}\left( x_1, 0.9 \right)$"

# Issue with operators that have underscores:
my_op(x, y) = x + y
options = Options(; binary_operators=(my_op,))
@extend_operators options
x1 = Node(; feature=1)
tree = my_op(x1, 0.9)
@test_broken latexify(tree, options) == L"$\mathrm{myop}\left( x_1, 0.9 \right)$"
