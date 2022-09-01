include("test_params.jl")
using SymbolicRegression, SymbolicUtils
using Test
using SymbolicRegression: string_tree
using Random

x1 = 0.1f0;
x2 = 0.1f0;
x3 = 0.1f0;
x4 = 0.1f0;
x5 = 0.1f0;
for i in 0:5
    batching = i in [0, 1]
    weighted = i in [0, 2]

    numprocs = 4
    progress = false
    warmupMaxsizeBy = 0.0f0
    optimizer_algorithm = "NelderMead"
    multi = false
    probPickFirst = 1.0
    multithreading = false
    crossoverProbability = 0.0f0
    skip_mutation_failures = false
    useFrequency = false
    useFrequencyInTournament = false
    T = Float32
    print("Testing with batching=$(batching) and weighted=$(weighted), ")
    if i == 0
        println("with serial & progress bar & warmup & BFGS")
        numprocs = 0 #Try serial computation here.
        progress = true #Also try the progress bar.
        warmupMaxsizeBy = 0.5f0 #Smaller maxsize at first, build up slowly
        optimizer_algorithm = "BFGS"
        probPickFirst = 0.8
    elseif i == 1
        println("with multi-output and useFrequency.")
        multi = true
        useFrequency = true
    elseif i == 3
        println("with multi-threading and crossover and useFrequencyInTournament")
        multithreading = true
        numprocs = 0
        crossoverProbability = 0.02f0
        useFrequencyInTournament = true
    elseif i == 4
        println(
            "with crossover and skip mutation failures and both frequencies options, and Float16 type",
        )
        crossoverProbability = 0.02f0
        skip_mutation_failures = true
        useFrequency = true
        useFrequencyInTournament = true
        T = Float16
    elseif i == 5
        println("with default hyperparameters, and Float64 type")
        T = Float64
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
            crossoverProbability=crossoverProbability,
            skip_mutation_failures=skip_mutation_failures,
            seed=0,
            progress=progress,
            warmupMaxsizeBy=warmupMaxsizeBy,
            optimizer_algorithm=optimizer_algorithm,
            probPickFirst=probPickFirst,
            parsimony=0.0f0,
            useFrequency=useFrequency,
            useFrequencyInTournament=useFrequencyInTournament,
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
            numprocs=numprocs,
            multithreading=multithreading,
        )
        dominating = [calculate_pareto_frontier(X, y, hallOfFame, options; weights=weights)]
    else
        y = 2 * cos.(X[4, :])
        if multi
            # Copy the same output twice; make sure we can find it twice
            y = repeat(y, 1, 2)
            y = transpose(y)
        end
        hallOfFame = EquationSearch(
            X, y; niterations=2, options=options, multithreading=multithreading
        )
        if multi
            dominating = [
                calculate_pareto_frontier(X, y[j, :], hallOfFame[j], options) for j in 1:2
            ]
        else
            dominating = [calculate_pareto_frontier(X, y, hallOfFame, options)]
        end
    end

    # Always assume multi
    for dom in dominating
        best = dom[end]
        # Assert we created the correct type of trees:
        @test typeof(best.tree) == Node{T}

        # Look at the symbolic version:
        eqn = node_to_symbolic(best.tree, options)

        local x4 = SymbolicUtils.Sym{Real}(Symbol("x4"))
        true_eqn = 2 * cos(x4)
        residual = simplify(eqn - true_eqn) + x4 * 1e-10

        # Test the score
        @test best.loss < maximum_residual / 10
        # Test the actual equation found:
        # eval evaluates inside global
        @test abs(eval(Meta.parse(string(residual)))) < maximum_residual
    end

    println("Passed.")
end # for i=1...

println("Testing fast-cycle and custom variable names, with mutations")

options = SymbolicRegression.Options(;
    default_params...,
    binary_operators=(+, *),
    unary_operators=(cos,),
    npopulations=4,
    constraints=((*) => (-1, 10), cos => (5)),
    fast_cycle=true,
    skip_mutation_failures=true,
    stateReturn=true,
)
X = randn(MersenneTwister(0), Float32, 5, 100)
y = 2 * cos.(X[4, :])
varMap = ["t1", "t2", "t3", "t4", "t5"]
state, hallOfFame = EquationSearch(X, y; varMap=varMap, niterations=2, options=options)
dominating = calculate_pareto_frontier(X, y, hallOfFame, options)

best = dominating[end]

eqn = node_to_symbolic(best.tree, options; varMap=varMap)

t4 = SymbolicUtils.Sym{Real}(Symbol("t4"))
true_eqn = 2 * cos(t4)
residual = simplify(eqn - true_eqn) + t4 * 1e-10

# Test the score
@test best.loss < maximum_residual / 10
# Test the actual equation found:
t1 = 0.1f0;
t2 = 0.1f0;
t3 = 0.1f0;
t4 = 0.1f0;
t5 = 0.1f0;
residual_value = abs(eval(Meta.parse(string(residual))))
@test residual_value < maximum_residual

# Do search again, but with saved state:
# We do 0 iterations to make sure the state is used.
println("Passed.")
println("Testing whether state saving works.")
state, hallOfFame = EquationSearch(
    X, y; varMap=varMap, niterations=0, options=options, saved_state=(state, hallOfFame)
)

dominating = calculate_pareto_frontier(X, y, hallOfFame, options)
best = dominating[end]
print_tree(best.tree, options)
eqn = node_to_symbolic(best.tree, options; varMap=varMap)
residual = simplify(eqn - true_eqn) + t4 * 1e-10
@test best.loss < maximum_residual / 10

println("Passed.")

println("Testing whether we can stop based on clock time.")
options = Options(; default_params..., timeout_in_seconds=1)
start_time = time()
EquationSearch(X, y; niterations=10000000, options=options, multithreading=true)
end_time = time()
@test end_time - start_time < 100
println("Passed.")

println("Running README example.")
include("../example.jl")
println("Passed.")

println("Testing whether the recorder works.")
include("test_recorder.jl")
println("Passed.")

println("Testing whether deterministic mode works.")
include("test_deterministic.jl")
println("Passed.")
