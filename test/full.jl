using SymbolicRegression, SymbolicUtils, Test
using SymbolicRegression: stringTree

for batching in [false, true]
    for weighted in [false, true]
        options = SymbolicRegression.Options(
            binary_operators=(+, *),
            unary_operators=(cos,),
            npopulations=4,
            batching=batching
        )
        X = randn(Float32, 5, 100)
        if weighted
            mask = rand(100) .> 0.5
            weights = map(x->convert(Float32, x), mask)
            # Completely different function superimposed - need
            # to use correct weights to figure it out!
            y = (2 .* cos.(X[4, :])) .* weights .+ (1 .- weights) .* (5 .* X[2, :])
            hallOfFame = EquationSearch(X, y, weights=weights,
                                        niterations=2, options=options)
            dominating = calculateParetoFrontier(X, y, hallOfFame,
                                                 options; weights=weights)
        else
            y = 2 * cos.(X[4, :])
            hallOfFame = EquationSearch(X, y, niterations=2, options=options)
            dominating = calculateParetoFrontier(X, y, hallOfFame, options)
        end

        best = dominating[end]
        eqn = node_to_symbolic(best.tree, options, evaluate_functions=true)

        @syms x1::Real x2::Real x3::Real x4::Real
        true_eqn = 2*cos(x4)
        residual = simplify(eqn - true_eqn)

        # Test the score
        @test best.score < 1e-6
        x4 = 0.1f0
        # Test the actual equation found:
        @test abs(eval(Meta.parse(string(residual)))) < 1e-6
    end
end
