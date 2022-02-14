using FromFile
@from "test_params.jl" import maximum_residual
using SymbolicRegression, SymbolicUtils
using Test
using SymbolicRegression: stringTree
using Random

x1=0.1f0; x2=0.1f0; x3=0.1f0; x4=0.1f0; x5=0.1f0
for batching in [true, false]
    for weighted in [true, false]
        numprocs = 4
        progress = false
        warmupMaxsizeBy = 0f0
        optimizer_algorithm = "NelderMead"
        multi = false
        probPickFirst = 1.0
        multithreading = false
        print("Testing with batching=$(batching) and weighted=$(weighted), ")
        if weighted && batching
            println("with serial & progress bar & warmup & BFGS")
            numprocs = 0 #Try serial computation here.
            progress = true #Also try the progress bar.
            warmupMaxsizeBy = 0.5f0 #Smaller maxsize at first, build up slowly
            optimizer_algorithm = "BFGS"
            probPickFirst = 0.8
        elseif !weighted && !batching
            println("with multi-output.")
            multi = true
        elseif !weighted && batching
            println("with multi-threading")
            multithreading = true
            numprocs = 0
        end
        options = SymbolicRegression.Options(
            binary_operators=(+, *),
            unary_operators=(cos,),
            npopulations=4,
            batching=batching,
            seed=0,
            progress=progress,
            warmupMaxsizeBy=warmupMaxsizeBy,
            optimizer_algorithm=optimizer_algorithm,
            probPickFirst=probPickFirst
        )
        X = randn(MersenneTwister(0), Float32, 5, 100)
        if weighted
            mask = rand(100) .> 0.5
            weights = map(x->convert(Float32, x), mask)
            # Completely different function superimposed - need
            # to use correct weights to figure it out!
            y = (2 .* cos.(X[4, :])) .* weights .+ (1 .- weights) .* (5 .* X[2, :])
            hallOfFame = EquationSearch(X, y, weights=weights,
                                        niterations=2, options=options,
                                        numprocs=numprocs,
                                        multithreading=multithreading
                                       )
            dominating = [calculateParetoFrontier(X, y, hallOfFame,
                                                  options; weights=weights)]
        else
            y = 2 * cos.(X[4, :])
            if multi
                # Copy the same output twice; make sure we can find it twice
                y = repeat(y, 1, 2)
                y = transpose(y)
            end
            hallOfFame = EquationSearch(X, y, niterations=2, options=options, multithreading=multithreading)
            if multi
                dominating = [calculateParetoFrontier(X, y[j, :], hallOfFame[j], options)
                              for j=1:2]
            else
                dominating = [calculateParetoFrontier(X, y, hallOfFame, options)]
            end
        end

        
        # Always assume multi
        for dom in dominating
            best = dom[end]
            eqn = node_to_symbolic(best.tree, options, evaluate_functions=true)

            local x4 = SymbolicUtils.Sym{Real}(Symbol("x4"))
            true_eqn = 2*cos(x4)
            residual = simplify(eqn - true_eqn) + x4 * 1e-10

            # Test the score
            @test best.score < maximum_residual / 10
            # Test the actual equation found:
            # eval evaluates inside global
            @test abs(eval(Meta.parse(string(residual)))) < maximum_residual
        end

        println("Passed.")
    end
end

println("Testing fast-cycle and custom variable names")

options = SymbolicRegression.Options(
    binary_operators=(+, *),
    unary_operators=(cos,),
    npopulations=4,
    constraints=((*)=>(-1, 10), cos=>(5)),
    fast_cycle=true,
    stateReturn=true,
)
X = randn(MersenneTwister(0), Float32, 5, 100)
y = 2 * cos.(X[4, :])
varMap = ["t1", "t2", "t3", "t4", "t5"]
state, hallOfFame = EquationSearch(X, y; varMap=varMap,
                            niterations=2, options=options)
dominating = calculateParetoFrontier(X, y, hallOfFame, options)

best = dominating[end]

eqn = node_to_symbolic(best.tree, options;
                       evaluate_functions=true, varMap=varMap)

t4 = SymbolicUtils.Sym{Real}(Symbol("t4"))
true_eqn = 2*cos(t4)
residual = simplify(eqn - true_eqn) + t4 * 1e-10

# Test the score
@test best.score < maximum_residual / 10
# Test the actual equation found:
t1=0.1f0; t2=0.1f0; t3=0.1f0; t4=0.1f0; t5=0.1f0
residual_value = abs(eval(Meta.parse(string(residual))))
@test residual_value < maximum_residual

# Do search again, but with saved state:
# We do 0 iterations to make sure the state is used.
println("Passed.")
println("Testing whether state saving works.")
state, hallOfFame = EquationSearch(X, y; varMap=varMap,
                                   niterations=0, options=options,
                                   saved_state=(state, hallOfFame))

dominating = calculateParetoFrontier(X, y, hallOfFame, options)
best = dominating[end]
printTree(best.tree, options)
eqn = node_to_symbolic(best.tree, options;
                       evaluate_functions=true, varMap=varMap)
residual = simplify(eqn - true_eqn) + t4 * 1e-10
@test best.score < maximum_residual / 10

println("Passed.")


println("Testing whether we can stop based on clock time.")
options = Options(timeout_in_seconds=1)
start_time = time()
EquationSearch(X, y; niterations=10000000, options=options, multithreading=true)
end_time = time()
@test end_time - start_time < 100
println("Passed.")