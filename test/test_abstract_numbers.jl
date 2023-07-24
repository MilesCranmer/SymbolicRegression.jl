using SymbolicRegression
using Test
using Random

get_base_type(::Type{<:Complex{BT}}) where {BT} = BT

for T in (ComplexF16, ComplexF32, ComplexF64)
    L = get_base_type(T)
    @testset "Test search with $T type" begin
        X = randn(MersenneTwister(0), T, 1, 100)
        y = @. (2 - 0.5im) * cos((1 + 1im) * X[1, :]) |> T

        early_stop(loss::L, c) where {L} = ((loss <= L(1e-2)) && (c <= 15))

        options = SymbolicRegression.Options(;
            binary_operators=[+, *, -, /],
            unary_operators=[cos],
            populations=20,
            early_stop_condition=early_stop,
            elementwise_loss=(prediction, target) -> abs2(prediction - target),
        )

        dataset = Dataset(X, y; loss_type=L)
        hof = if T == ComplexF16
            equation_search([dataset]; options=options, niterations=1_000_000_000)
        else
            # Should automatically find correct type:
            equation_search(X, y; options=options, niterations=1_000_000_000)
        end

        dominating = calculate_pareto_frontier(hof)
        @test typeof(dominating[end].loss) == L
        output, _ = eval_tree_array(dominating[end].tree, X, options)
        @test typeof(output) <: AbstractArray{T}
        @test sum(abs2, output .- y) / length(output) <= L(1e-2)
    end
end
