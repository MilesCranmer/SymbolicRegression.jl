using Test
using SymbolicRegression
using SymbolicRegression: evalDiffTreeArray, evalGradTreeArray
using Random
using Zygote
using LinearAlgebra


for seed=1:3
    for type ∈ [Float32, Float64]
        rng = MersenneTwister(seed)
        nfeatures = 3
        N = 100

        X = rand(rng, type, nfeatures, N) * 10

        pow_abs(x::T, y::T) where {T<:Real} = abs(x) ^ y
        custom_cos(x::T) where {T<:Real} = cos(x)^2

        options = Options(;
            binary_operators=(+, *, -, /, pow_abs),
            unary_operators=(custom_cos, exp, sin),
        )

        # Define these custom functions for Node data types:
        custom_cos(x::Node)::Node = x.constant ? Node(custom_cos(x.val)::AbstractFloat) : Node(1, x)
        pow_abs(l::Node, r::Node)::Node = (l.constant && r.constant) ? Node(pow_abs(l.val, r.val)::AbstractFloat) : Node(5, l, r)
        pow_abs(l::Node, r::AbstractFloat)::Node = l.constant ? Node(pow_abs(l.val, r)::AbstractFloat) : Node(5, l, r)
        pow_abs(l::AbstractFloat, r::Node)::Node = r.constant ? Node(pow_abs(l, r.val)::AbstractFloat) : Node(5, l, r)

        # Equations to test gradients on:
        equation1(x1, x2, x3) = x1 + x2 + x3 + 3.2f0
        equation2(x1, x2, x3) = pow_abs(x1, x2) + x3 + custom_cos(1f0 + x3) + 3f0 / x1
        equation3(x1, x2, x3) = (((x2 + x2) * ((-0.5982493 / pow_abs(x1, x2)) / -0.54734415)) + (sin(custom_cos(sin(1.2926733 - 1.6606787) / sin(((0.14577048 * x1) + ((0.111149654 + x1) - -0.8298334)) - -1.2071426)) * (custom_cos(x3 - 2.3201916) + ((x1 - (x1 * x2)) / x2))) / (0.14854191 - ((custom_cos(x2) * -1.6047639) - 0.023943262))))

        nx1 = Node("x1")
        nx2 = Node("x2")
        nx3 = Node("x3")

        function array_test(ar1, ar2; rtol=1e-4)
            all(abs.(ar1 .- ar2) ./ (1e-4 .+ abs.(ar1) .+ abs.(ar2)) .< rtol)
        end

        for j=1:3
            equation = [equation1, equation2, equation3][j]

            tree = equation(nx1, nx2, nx3)
            predicted_output = evalTreeArray(tree, X, options)[1]
            true_output = equation.([X[i, :] for i=1:nfeatures]...)

            # First, check if the predictions are approximately equal:
            rtol = j == 3 ? 1e-1 : 1e-4  # Last equation is hard to get perfect equality
            @test array_test(predicted_output, true_output; rtol=rtol)

            true_grad = gradient((x1, x2, x3) -> sum(equation.(x1, x2, x3)), [X[i, :] for i=1:nfeatures]...)
            # Convert tuple of vectors to matrix:
            true_grad = reduce(hcat, true_grad)'
            predicted_grad = evalGradTreeArray(tree, X, options; variable=true)[2]
            predicted_grad2 = reduce(hcat, [evalDiffTreeArray(tree, X, options, i)[2] for i=1:nfeatures])'

            println("Seed: $(seed)")
            # Print largest difference between predicted_grad, true_grad:
            idx_big_diff = argmax(abs.(predicted_grad .- true_grad))
            println("Largest difference between predicted_grad and true_grad: predicted=$(predicted_grad[idx_big_diff]) true=$(true_grad[idx_big_diff])")
            @test array_test(predicted_grad, true_grad; rtol=rtol)
            @test array_test(predicted_grad2, true_grad; rtol=rtol)

        end

        # Test gradient with respect to constants:
        equation4(x1, x2, x3) = 3.2f0 * x1
        # The gradient should be: (C * x1) => x1 is gradient with respect to C.
        tree = equation4(nx1, nx2, nx3)
        predicted_grad = evalGradTreeArray(tree, X, options; variable=false)[2]
        @test array_test(predicted_grad[1, :], X[1, :])


        # More complex expression:
        const_value = 2.1f0
        const_value2 = -3.2f0

        equation5(x1, x2, x3) = pow_abs(x1, x2) + x3 + custom_cos(const_value + x3) + const_value2 / x1
        equation5_with_const(c1, c2, x1, x2, x3) = pow_abs(x1, x2) + x3 + custom_cos(c1 + x3) + c2 / x1

        tree = equation5(nx1, nx2, nx3)

        # Use zygote to explicitly find the gradient:
        true_grad = gradient(
            (c1, c2, x1, x2, x3) -> sum(equation5_with_const.(c1, c2, x1, x2, x3)),
            fill(const_value, N), fill(const_value2, N), [X[i, :] for i=1:nfeatures]...
        )[1:2]
        true_grad = reduce(hcat, true_grad)'
        predicted_grad = evalGradTreeArray(tree, X, options; variable=false)[2]

        @test array_test(predicted_grad, true_grad)
    end
end