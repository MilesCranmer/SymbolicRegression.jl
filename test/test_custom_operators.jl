using SymbolicRegression
using Test
using Random

# Test that we can work with custom operators:
function op1(x::T, y::T)::T where {T<:Real}
    return x + y
end
function op2(x::T, y::T)::T where {T<:Real}
    return x^2 + 1 / ((y)^2 + 0.1)
end
function op3(x::T)::T where {T<:Real}
    return sin(x) + cos(x)
end
local operators, tree
options = Options(; binary_operators=[op1, op2], unary_operators=[op3])
@extend_operators options
x1 = Node(; feature=1)
x2 = Node(; feature=2)
tree = op1(op2(x1, x2), op3(x1))
@test repr(tree) == "op1(op2(x1, x2), op3(x1))"
# Test evaluation:
X = randn(MersenneTwister(0), Float32, 2, 10);
@test tree(X) ≈ ((x1, x2) -> op1(op2(x1, x2), op3(x1))).(X[1, :], X[2, :])

# Now, test that we can work with operators defined in modules
module A

using SymbolicRegression
using Random

function my_func_a(x::T, y::T) where {T<:Real}
    return x^2 * y
end

function my_func_b(x::T) where {T<:Real}
    return x^3
end

options = Options(; binary_operators=[my_func_a], unary_operators=[my_func_b])
@extend_operators options

function create_and_eval_tree()
    x1 = Node(Float64; feature=1)
    x2 = Node(Float64; feature=2)
    c1 = Node(Float64; val=0.2)
    tree = my_func_a(my_func_a(x2, 0.2), my_func_b(x1))
    func = (x1, x2) -> my_func_a(my_func_a(x2, 0.2), my_func_b(x1))
    X = randn(MersenneTwister(0), 2, 20)
    return tree(X), func.(X[1, :], X[2, :])
end

end

import .A: create_and_eval_tree
prediction, truth = create_and_eval_tree()
@test prediction ≈ truth

# Now, test that we can work with operators defined in other modules
module B

my_func_c(x::T, y::T) where {T<:Real} = x * y + T(0.3)
my_func_d(x::T) where {T<:Real} = x / (abs(x)^T(0.2) + 0.1)

end

import .B: my_func_c, my_func_d
options = Options(; binary_operators=[my_func_c], unary_operators=[my_func_d])
@extend_operators options

x1 = Node(Float64; feature=1)
x2 = Node(Float64; feature=2)
c1 = Node(Float64; val=0.2)
tree = my_func_c(my_func_c(x2, 0.2), my_func_d(x1))
func = (x1, x2) -> my_func_c(my_func_c(x2, 0.2), my_func_d(x1))
X = randn(MersenneTwister(0), 2, 20)
@test tree(X) ≈ func.(X[1, :], X[2, :])
