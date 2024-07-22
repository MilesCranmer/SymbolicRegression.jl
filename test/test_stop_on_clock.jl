using SymbolicRegression
using Random
include("test_params.jl")

X = randn(MersenneTwister(0), Float32, 5, 100)
y = 2 * cos.(X[4, :])

# Ensure is precompiled:
options = Options(; default_params..., timeout_in_seconds=1)
equation_search(X, y; niterations=1, options=options, parallelism=:multithreading)

start_time = time()
equation_search(X, y; niterations=10000000, options=options, parallelism=:multithreading)
end_time = time()
@test end_time - start_time < 100
