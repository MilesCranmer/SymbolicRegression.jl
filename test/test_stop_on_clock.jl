using SymbolicRegression
using Random
using Distributed: rmprocs
include("test_params.jl")

X = randn(MersenneTwister(0), Float32, 5, 100)
y = 2 * cos.(X[4, :])

# Ensure is precompiled:
options = Options(;
    default_params...,
    population_size=10,
    tournament_selection_n=9,
    ncycles_per_iteration=100,
    maxsize=15,
    timeout_in_seconds=1,
)
equation_search(X, y; niterations=1, options=options, parallelism=:serial)

# Ensure nothing might prevent slow checking of the clock:
rmprocs()
GC.gc(true) # full=true
start_time = time()
equation_search(X, y; niterations=10000000, options=options, parallelism=:serial)
end_time = time()
@test end_time - start_time < 100
