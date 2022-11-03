using SymbolicRegression
using Test
using Random
include("test_params.jl")

X = randn(MersenneTwister(0), Float32, 5, 100)
y = 2 * cos.(X[4, :])

options = Options(; default_params..., timeout_in_seconds=1)
start_time = time()
# With multithreading:
EquationSearch(X, y; niterations=10000000, options=options, parallelism=:multithreading)
end_time = time()
@test end_time - start_time < 100
