using Test
using SymbolicRegression
using SymbolicRegression: eval_diff_tree_array, eval_grad_tree_array
using Random
using Zygote
using LinearAlgebra

seed = 0
pow_abs2(x::T1, y::T2) where {T1<:Number,T2<:Number} = abs(x)^y
custom_cos(x::T) where {T<:Number} = cos(x)^2

# Define these custom functions for Node data types:
pow_abs2(l::Node, r::Node)::Node =
    (l.constant && r.constant) ? Node(pow_abs2(l.val, r.val)::AbstractFloat) : Node(5, l, r)
pow_abs2(l::Node, r::AbstractFloat)::Node =
    l.constant ? Node(pow_abs2(l.val, r)) : Node(5, l, r)
pow_abs2(l::AbstractFloat, r::Node)::Node =
    r.constant ? Node(pow_abs2(l, r.val)) : Node(5, l, r)
custom_cos(x::Node)::Node = x.constant ? Node(custom_cos(x.val)) : Node(1, x)

equation1(x1, x2, x3) = x1 + x2 + x3 + 3.2f0
equation2(x1, x2, x3) = pow_abs2(x1, x2) + x3 + custom_cos(1.0f0 + x3) + 3.0f0 / x1

nx1 = Node("x1")
nx2 = Node("x2")
nx3 = Node("x3")

# Equations to test gradients on:

function array_test(ar1, ar2; rtol=0.1)
    return isapprox(ar1, ar2; rtol=rtol)
end

options = Options(;
    binary_operators=(+, *, -, /, pow_abs2),
    unary_operators=(custom_cos, exp, sin),
    enable_autodiff=true,
)


for type in [Float32, Float16, Float64]
    println("Testing derivatives with respect to variables, with type=$(type).")
    rng = MersenneTwister(seed)
    nfeatures = 3
    N = 10

    X = rand(rng, nfeatures, N) .* 5
    X = convert(AbstractMatrix{type}, X)

    for j in 1:2
        println("Equation: $(j)")
        equation = [equation1, equation2][j]

        tree = convert(Node{type}, equation(nx1, nx2, nx3))
        predicted_output = eval_tree_array(tree, X, options)[1]
        true_output = equation.([X[i, :] for i in 1:nfeatures]...)
        true_output = convert(AbstractArray{type}, true_output)

        # First, check if the predictions are approximately equal:
        @test array_test(predicted_output, true_output)

        true_grad = gradient(
            (x1, x2, x3) -> sum(equation.(x1, x2, x3)), [X[i, :] for i in 1:nfeatures]...
        )
        # Convert tuple of vectors to matrix:
        true_grad = reduce(hcat, true_grad)'
        predicted_grad = eval_grad_tree_array(tree, copy(X), options; variable=true)[2]
        predicted_grad2 =
            reduce(
                hcat, [eval_diff_tree_array(tree, copy(X), options, i)[2] for i in 1:nfeatures]
            )'

        # Print largest difference between predicted_grad, true_grad:
        @test array_test(predicted_grad, true_grad)
        @test array_test(predicted_grad2, true_grad)

        # Make sure that the array_test actually works:
        @test !array_test(predicted_grad .* 0, true_grad)
        @test !array_test(predicted_grad2 .* 0, true_grad)
    end
    println("Done.")
    println("Testing derivatives with respect to constants, with type=$(type).")

    # Test gradient with respect to constants:
    equation4(x1, x2, x3) = 3.2f0 * x1
    # The gradient should be: (C * x1) => x1 is gradient with respect to C.
    tree = equation4(nx1, nx2, nx3)
    tree = convert(Node{type}, tree)
    predicted_grad = eval_grad_tree_array(tree, X, options; variable=false)[2]
    @test array_test(predicted_grad[1, :], X[1, :])

    # More complex expression:
    const_value = 2.1f0
    const_value2 = -3.2f0

    function equation5(x1, x2, x3)
        return pow_abs2(x1, x2) + x3 + custom_cos(const_value + x3) + const_value2 / x1
    end
    function equation5_with_const(c1, c2, x1, x2, x3)
        return pow_abs2(x1, x2) + x3 + custom_cos(c1 + x3) + c2 / x1
    end

    tree = equation5(nx1, nx2, nx3)
    tree = convert(Node{type}, tree)

    # Use zygote to explicitly find the gradient:
    true_grad = gradient(
        (c1, c2, x1, x2, x3) -> sum(equation5_with_const.(c1, c2, x1, x2, x3)),
        fill(const_value, N),
        fill(const_value2, N),
        [X[i, :] for i in 1:nfeatures]...,
    )[1:2]
    true_grad = reduce(hcat, true_grad)'
    predicted_grad = eval_grad_tree_array(tree, X, options; variable=false)[2]

    @test array_test(predicted_grad, true_grad)
    println("Done.")
end

println("Testing NodeIndex.")

import SymbolicRegression: get_constants, NodeIndex, index_constants

options = Options(;
    binary_operators=(+, *, -, /, pow_abs2),
    unary_operators=(custom_cos, exp, sin),
    enable_autodiff=true,
)
tree = equation2(nx1, nx2, nx3)

"""Check whether the ordering of constant_list is the same as the ordering of node_index."""
function check_tree(tree::Node, node_index::NodeIndex, constant_list::AbstractVector)
    if tree.degree == 0
        (!tree.constant) || tree.val == constant_list[node_index.constant_index]
    elseif tree.degree == 1
        check_tree(tree.l, node_index.l, constant_list)
    else
        check_tree(tree.l, node_index.l, constant_list) &&
            check_tree(tree.r, node_index.r, constant_list)
    end
end

@test check_tree(tree, index_constants(tree), get_constants(tree))

println("Done.")
