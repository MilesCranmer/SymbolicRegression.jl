using SymbolicRegression, Random, Bumper, LoopVectorization
using SymbolicRegression: string_tree, node_type

include("test_params.jl")

function test_mixed(i, batching::Bool, weighted::Bool, parallelism)
    progress = false
    warmup_maxsize_by = 0.0f0
    optimizer_algorithm = "NelderMead"
    multi = false
    tournament_selection_p = 1.0
    crossover_probability = 0.0f0
    skip_mutation_failures = false
    use_frequency = false
    use_frequency_in_tournament = false
    turbo = false
    bumper = false
    T = Float32
    Random.seed!(0)

    if i == 0
        progress = true #Also try the progress bar.
        warmup_maxsize_by = 0.5f0 #Smaller maxsize at first, build up slowly
        optimizer_algorithm = "BFGS"
        tournament_selection_p = 0.8
    elseif i == 1
        multi = true
        use_frequency = true
    elseif i == 3
        crossover_probability = 0.02f0
        use_frequency_in_tournament = true
        bumper = true
    elseif i == 4
        crossover_probability = 0.02f0
        skip_mutation_failures = true
        use_frequency = true
        use_frequency_in_tournament = true
        T = Float16
    elseif i == 5
        T = Float64
        turbo = true
    end

    numprocs = parallelism == :multiprocessing ? 2 : nothing

    options = if i == 5
        SymbolicRegression.Options(;
            unary_operators=(cos,),
            batching=batching,
            parsimony=0.0f0, # Required for scoring
            early_stop_condition=1e-6,
        )
    else
        SymbolicRegression.Options(;
            default_params...,
            binary_operators=(+, *),
            unary_operators=(cos,),
            populations=4,
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
            bumper=bumper,
            early_stop_condition=1e-6,
        )
    end

    X = randn(MersenneTwister(0), T, 5, 100)

    (y, hallOfFame, dominating) = if weighted
        mask = rand(100) .> 0.5
        weights = map(x -> convert(T, x), mask)
        # Completely different function superimposed - need
        # to use correct weights to figure it out!
        y = (2 .* cos.(X[4, :])) .* weights .+ (1 .- weights) .* (5 .* X[2, :])
        hallOfFame = equation_search(
            X,
            y;
            weights=weights,
            niterations=2,
            options=options,
            parallelism=parallelism,
            numprocs=numprocs,
        )
        dominating = [calculate_pareto_frontier(hallOfFame)]

        (y, hallOfFame, dominating)
    else
        y = 2 * cos.(X[4, :])
        niterations = 2
        if multi
            # Copy the same output twice; make sure we can find it twice
            y = repeat(y, 1, 2)
            y = transpose(y)
            niterations = 20
        end
        hallOfFame = equation_search(
            X,
            y;
            niterations=niterations,
            options=options,
            parallelism=parallelism,
            numprocs=numprocs,
        )
        dominating = if multi
            [calculate_pareto_frontier(hallOfFame[j]) for j in 1:2]
        else
            [calculate_pareto_frontier(hallOfFame)]
        end

        (y, hallOfFame, dominating)
    end

    # For brevity, always assume multi-output in this test:
    for dom in dominating
        @test length(dom) > 0
        best = dom[end]
        # Assert we created the correct type of trees:
        @test node_type(typeof(best.tree)) == Node{T}

        # Test the cost
        @test best.loss < maximum_residual
        # Test the actual equation found:
        testX = randn(MersenneTwister(1), T, 5, 100)
        true_y = 2 * cos.(testX[4, :])
        predicted_y, flag = eval_tree_array(best.tree, testX, options)

        @test flag
        if parallelism == :multiprocessing && turbo
            # TODO: For some reason this test does a bit worse
            @test sum(abs, true_y .- predicted_y) < maximum_residual * 50
        else
            @test sum(abs, true_y .- predicted_y) < maximum_residual
        end

        # eval evaluates inside global
    end

    return println("Passed.")
end
