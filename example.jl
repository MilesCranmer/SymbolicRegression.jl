using Distributed
using SymbolicUtils
# using ClusterManagers

# Easy to set up distributed over cores:
# procs1 = addprocs(SlurmManager(4))
# procs2 = addprocs(40) # 40 cores per node
procs = addprocs()

@everywhere include("src/SymbolicRegression.jl")
@everywhere using .SymbolicRegression

X = randn(Float32, 5, 100)
y = 2 * cos.(X[4, :]) + X[1, :] .^ 2 .- 2


@everywhere inv(x)=1/x

options = SymbolicRegression.Options(
    binary_operators=(+, *), #, /, -),
    unary_operators=(cos, exp, inv),
    npopulations=2 #populations > cores
)
niterations = 2

hallOfFame = EquationSearch(X, y, niterations=niterations, options=options)

dominating = calculateParetoFrontier(X, y, hallOfFame, options)
eqn = node_to_symbolic(dominating[end].tree, options, evaluate_functions=true)

print(simplify(eqn*5 + 3))
# hallOfFame = RunSR(transpose(X), y, niterations=niterations, options=options)

rmprocs(procs)
# rmprocs(procs1)
# rmprocs(procs2)
