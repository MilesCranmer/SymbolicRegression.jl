using SymbolicRegression
using Random
using Test

X = 2 .* randn(MersenneTwister(0), Float32, 2, 1000)
y = 3 * cos.(X[2, :]) + X[1, :] .^ 2 .- 2

options = SymbolicRegression.Options(;
    binary_operators=(+, *, /, -),
    unary_operators=(cos,),
    crossover_probability=0.0,  # required for recording, as not set up to track crossovers.
    max_evals=10000,
    deterministic=true,
    seed=0,
    verbosity=0,
    progress=false,
)

# Test serial mode (original test)
all_outputs = []
for i in 1:2
    hall_of_fame = equation_search(
        X,
        y;
        niterations=5,
        options=options,
        parallelism=:serial,
        v_dim_out=Val(1),
        return_state=Val(false),
    )
    dominating = calculate_pareto_frontier(hall_of_fame)
    push!(all_outputs, dominating[end].tree)
end

@test string(all_outputs[1]) == string(all_outputs[2])
println("Serial deterministic test passed")

# Test multithreading mode with deterministic=true
if Threads.nthreads() > 1
    all_outputs_mt = []
    for i in 1:2
        hall_of_fame = equation_search(
            X,
            y;
            niterations=5,
            options=options,
            parallelism=:multithreading,
            v_dim_out=Val(1),
            return_state=Val(false),
        )
        dominating = calculate_pareto_frontier(hall_of_fame)
        push!(all_outputs_mt, dominating[end].tree)
    end

    @test string(all_outputs_mt[1]) == string(all_outputs_mt[2])
    println("Multithreading deterministic test passed")
else
    println("Skipping multithreading test (only 1 thread available)")
end
