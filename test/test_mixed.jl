using SymbolicRegression
using Test
using SymbolicRegression: string_tree
using Random
include("test_params.jl")

for i in 0:5
    local options, X, y, tree
    batching = i in [0, 1]
    weighted = i in [0, 2]

    numprocs = 2
    progress = false
    warmup_maxsize_by = 0.0f0
    optimizer_algorithm = "NelderMead"
    multi = false
    tournament_selection_p = 1.0
    parallelism = :multiprocessing
    crossover_probability = 0.0f0
    skip_mutation_failures = false
    use_frequency = false
    use_frequency_in_tournament = false
    turbo = false
    T = Float32
    print("Testing with batching=$(batching) and weighted=$(weighted), ")
    if i == 0
        println("with serial & progress bar & warmup & BFGS")
        numprocs = nothing #Try serial computation here.
        parallelism = :serial
        progress = true #Also try the progress bar.
        warmup_maxsize_by = 0.5f0 #Smaller maxsize at first, build up slowly
        optimizer_algorithm = "BFGS"
        tournament_selection_p = 0.8
    elseif i == 1
        println("with multi-output and use_frequency and string-specified parallelism.")
        multi = true
        use_frequency = true
        parallelism = "multiprocessing"
    elseif i == 3
        println("with multi-threading and crossover and use_frequency_in_tournament")
        parallelism = :multithreading
        numprocs = nothing
        crossover_probability = 0.02f0
        use_frequency_in_tournament = true
    elseif i == 4
        println(
            "with crossover and skip mutation failures and both frequencies options, and Float16 type",
        )
        crossover_probability = 0.02f0
        skip_mutation_failures = true
        use_frequency = true
        use_frequency_in_tournament = true
        T = Float16
    elseif i == 5
        println("with default hyperparameters, Float64 type, and turbo=true")
        T = Float64
        turbo = true
    end
    if i == 5
        options = SymbolicRegression.Options(;
            unary_operators=(cos,),
            batching=batching,
            parsimony=0.0f0, # Required for scoring
        )
    else
        options = SymbolicRegression.Options(;
            default_params...,
            binary_operators=(+, *),
            unary_operators=(cos,),
            npopulations=4,
            batching=batching,
            crossover_probability=crossover_probability,
            skip_mutation_failures=skip_mutation_failures,
            seed=0,
            progress=progress,
            warmup_maxsize_by=warmup_maxsize_by,
            optimizer_algorithm=optimizer_algorithm,
            tournament_selection_p=tournament_selection_p,
            parsimony=0.0f0,
            use_frequency=use_frequency,
            use_frequency_in_tournament=use_frequency_in_tournament,
            turbo=turbo,
        )
    end

    X = randn(MersenneTwister(0), T, 5, 100)
    if weighted
        mask = rand(100) .> 0.5
        weights = map(x -> convert(T, x), mask)
        # Completely different function superimposed - need
        # to use correct weights to figure it out!
        y = (2 .* cos.(X[4, :])) .* weights .+ (1 .- weights) .* (5 .* X[2, :])
        hallOfFame = EquationSearch(
            X,
            y;
            weights=weights,
            niterations=2,
            options=options,
            parallelism=parallelism,
            numprocs=numprocs,
        )
        dominating = [calculate_pareto_frontier(X, y, hallOfFame, options; weights=weights)]
    else
        y = 2 * cos.(X[4, :])
        niterations = 2
        if multi
            # Copy the same output twice; make sure we can find it twice
            y = repeat(y, 1, 2)
            y = transpose(y)
            niterations = 20
        end
        hallOfFame = EquationSearch(
            X,
            y;
            niterations=niterations,
            options=options,
            parallelism=parallelism,
            numprocs=numprocs,
        )
        dominating = if multi
            [calculate_pareto_frontier(X, y[j, :], hallOfFame[j], options) for j in 1:2]
        else
            [calculate_pareto_frontier(X, y, hallOfFame, options)]
        end
    end

    # For brevity, always assume multi-output in this test:
    for dom in dominating
        @test length(dom) > 0
        best = dom[end]
        # Assert we created the correct type of trees:
        @test typeof(best.tree) == Node{T}

        # Test the score
        @test best.loss < maximum_residual
        # Test the actual equation found:
        testX = randn(MersenneTwister(1), T, 5, 100)
        true_y = 2 * cos.(testX[4, :])
        predicted_y, flag = eval_tree_array(best.tree, testX, options)
        @test flag
        @test sum(abs, true_y .- predicted_y) < maximum_residual
        # eval evaluates inside global
    end

    println("Passed.")
end # for i=1...
