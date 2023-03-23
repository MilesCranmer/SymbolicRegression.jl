using SymbolicRegression, Test
include("test_params.jl")

_inv(x::Float32)::Float32 = 1.0f0 / x
X = rand(Float32, 5, 100) .+ 1
y = 1.2f0 .+ 2 ./ X[3, :]

parallelism_kws = if Sys.iswindows()
    (parallelism=:multithreading, numprocs=nothing)
else
    (parallelism=:multiprocessing, numprocs=2)
end

options = SymbolicRegression.Options(;
    default_params..., binary_operators=(+, *), unary_operators=(_inv,), npopulations=8
)
hallOfFame = EquationSearch(X, y; niterations=8, options=options, parallelism_kws...)

dominating = calculate_pareto_frontier(X, y, hallOfFame, options)

best = dominating[end]
# Test the score
@test best.loss < maximum_residual / 10
