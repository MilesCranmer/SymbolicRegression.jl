@testitem "Early stop condition" begin
    using SymbolicRegression

    X = randn(Float32, 5, 100)
    y = 2 * cos.(X[4, :]) + X[1, :] .^ 2

    early_stop(loss, c) = ((loss <= 1e-10) && (c <= 10))

    options = SymbolicRegression.Options(;
        binary_operators=(+, *, /, -),
        unary_operators=(cos, exp),
        populations=20,
        early_stop_condition=early_stop,
    )

    hof = equation_search(X, y; options=options, niterations=1_000_000_000)

    @test any(
        early_stop(member.loss, count_nodes(member.tree)) for
        member in hof.members[hof.exists]
    )
end

@testitem "State preservation with niterations=0" begin
    using SymbolicRegression
    using Random

    # Regression test for https://github.com/MilesCranmer/SymbolicRegression.jl/issues/178

    rng = MersenneTwister(42)
    X = randn(rng, 2, 10)
    y = X[1, :] .+ X[2, :]

    options = Options(;
        binary_operators=(+,),
        unary_operators=(),
        verbosity=0,
        progress=false,
        population_size=5,
        populations=2,
        maxsize=5,
        tournament_selection_n=2,
    )

    # Manually create saved state
    dataset = Dataset(X, y)
    pop1 = Population(dataset; population_size=5, nlength=3, options=options, nfeatures=2)
    pop2 = Population(dataset; population_size=5, nlength=3, options=options, nfeatures=2)
    hof = HallOfFame(options, dataset)

    saved_pops = [[pop1, pop2]]
    saved_hof = [hof]
    saved_state = (saved_pops, saved_hof)

    # Run with niterations=0 - should preserve populations
    result_pops, result_hof = equation_search(
        X,
        y;
        niterations=0,
        saved_state=saved_state,
        options=options,
        parallelism=:serial,
        return_state=true,
    )

    # Verify populations are preserved (not reset to size 1)
    @test length(result_pops[1]) == 2
    @test all(pop -> length(pop.members) == 5, result_pops[1])
end
