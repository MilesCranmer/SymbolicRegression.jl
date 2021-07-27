using Test
using SymbolicRegression
using SymbolicRegression: evaldiffTreeArray
using Zygote
using LinearAlgebra

options = Options(;
    binary_operators=(+, *, -, /, ^),
    unary_operators=(cos, exp),
)
tree = Node(5, (Node(3.0) * Node(1, Node("x1"))) ^ 2.3, -1.2) + Node("x2") - Node("x3")

equation(x1, x2, x3) =  (abs(abs(3.0 * cos(x1)) ^ 2.3) ^ (-1.2)) + x2 - x3

input_data = transpose([1.0 2.0 3.0])
true_grad = gradient(equation, 1.0, 2.0, 3.0)

for i=1:3
    @test evaldiffTreeArray(tree, input_data, options, i)[2][1] ≈ true_grad[i]
end
