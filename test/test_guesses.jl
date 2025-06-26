@testitem "Single output, single guess" tags = [:part1] begin
    using SymbolicRegression
    using SymbolicRegression: calculate_pareto_frontier
    using Test

    X = randn(2, 50)
    y = @. 2.0 * X[1, :]^2 + 3.0 * X[2, :] + 0.5

    options = Options(;
        binary_operators=(+, *), unary_operators=(), verbosity=0, progress=false
    )

    # See if a good guess helps the search
    good_guess = "2.0*x1*x1 + 3.0*x2 + 0.5"
    hof = equation_search(X, y; niterations=0, options, guesses=[good_guess])
    dominating = calculate_pareto_frontier(hof)

    @test any(m -> m.loss < 1e-10, dominating)

    # We also test that this test correctly measures the behavior
    bad_guess = "1.0*x1 + 1.0*x2 + 0.0"
    hof = equation_search(X, y; niterations=0, options, guesses=[bad_guess])
    dominating = calculate_pareto_frontier(hof)

    @test !any(m -> m.loss < 1e-10, dominating)
end

# TODO: Multiple guesses
# TODO: Multiple outputs
# TODO: Different variable names
# TODO: User-defined operators
# TODO: Template expressions?
