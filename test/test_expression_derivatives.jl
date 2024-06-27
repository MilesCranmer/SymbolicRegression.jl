@testitem "Test derivatives" tags = [:part1] begin
    using SymbolicRegression
    using Zygote: Zygote
    using Random: MersenneTwister

    ex = @parse_expression(
        x * x - cos(2.5 * y),
        unary_operators = [cos],
        binary_operators = [*, -, +],
        variable_names = [:x, :y]
    )

    rng = MersenneTwister(0)
    X = rand(rng, 2, 32)

    (δy,) = Zygote.gradient(X) do X
        x = @view X[1, :]
        y = @view X[2, :]

        sum(i -> x[i] * x[i] - cos(2.5 * y[i]), eachindex(x))
    end
    δŷ = ex'(X)

    @test δy ≈ δŷ

    options2 = Options(; unary_operators=[sin], binary_operators=[+, *, -])
    (δy2,) = Zygote.gradient(X) do X
        x = @view X[1, :]
        y = @view X[2, :]

        sum(i -> (x[i] + x[i]) * sin(2.5 + y[i]), eachindex(x))
    end
    δy2̂ = ex'(X, options2)

    @test δy2 ≈ δy2̂
end
