using SymbolicRegression
using Test
using JSON3

X = 2 .* randn(Float32, 2, 1000)
y = 3 * cos.(X[2, :]) + X[1, :] .^ 2 .- 2

options = SymbolicRegression.Options(;
    binary_operators=(+, *, /, -),
    unary_operators=(cos,),
    recorder=true,
    recorder_file="pysr_recorder.json",
    crossover_probability=0.0,  # required for recording, as not set up to track crossovers.
    npopulations=2,
    npop=100,
    maxsize=20,
    complexity_of_operators=[cos => 2],
)

hall_of_fame = EquationSearch(
    X, y; niterations=5, options=options, parallelism=:multithreading
)

data = open(options.recorder_file, "r") do io
    JSON3.read(io; allow_inf=true)
end

@test haskey(data, :options)
@test haskey(data, :out1_pop1)
@test haskey(data, :out1_pop2)
@test haskey(data, :mutations)

# Test that "Options" is part of the string in `data.options`:
@test contains(data.options, "Options")
@test length(data.mutations) > 1000

# Check whether 10 random elements have the right properties:
for (i, key) in enumerate(keys(data.mutations))
    @test haskey(data.mutations[key], :events)
    @test haskey(data.mutations[key], :score)
    @test haskey(data.mutations[key], :tree)
    @test haskey(data.mutations[key], :loss)
    @test haskey(data.mutations[key], :parent)
    if i > 10
        break
    end
end
