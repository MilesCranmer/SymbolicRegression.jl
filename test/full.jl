using FromFile
@from "test_params.jl" import maximum_residual
using SymbolicRegression, SymbolicUtils, Test
using SymbolicRegression: stringTree
using Random

x1=0.1f0; x2=0.1f0; x3=0.1f0; x4=0.1f0; x5=0.1f0
for batching in [false, true]
    for weighted in [false, true]
        numprocs = 4
        if weighted && batching
            numprocs = 0 #Try serial computation here.
        end
        options = SymbolicRegression.Options(
            binary_operators=(+, *),
            unary_operators=(cos,),
            npopulations=4,
            batching=batching,
            seed=0,
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
                                        numprocs=numprocs
                                       )
            dominating = calculateParetoFrontier(X, y, hallOfFame,
                                                 options; weights=weights)
        else
            y = 2 * cos.(X[4, :])
            hallOfFame = EquationSearch(X, y, niterations=2, options=options)
            dominating = calculateParetoFrontier(X, y, hallOfFame, options)
        end

        best = dominating[end]
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
end

options = SymbolicRegression.Options(
    binary_operators=(+, *),
    unary_operators=(cos,),
    npopulations=4,
    constraints=((*)=>(-1, 10), cos=>(5)),
    fast_cycle=true
)
X = randn(MersenneTwister(0), Float32, 5, 100)
y = 2 * cos.(X[4, :])
varMap = ["t1", "t2", "t3", "t4", "t5"]
hallOfFame = EquationSearch(X, y; varMap=varMap,
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
