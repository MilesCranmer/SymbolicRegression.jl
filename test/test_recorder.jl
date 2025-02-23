using SymbolicRegression
using SymbolicRegression.UtilsModule: recursive_merge
using JSON3
include("test_params.jl")

base_dir = mktempdir()
recorder_file = joinpath(base_dir, "pysr_recorder.json")
X = 2 .* randn(Float32, 2, 1000)
y = 3 * cos.(X[2, :]) + X[1, :] .^ 2 .- 2

options = SymbolicRegression.Options(;
    binary_operators=(+, *, /, -),
    unary_operators=(cos,),
    use_recorder=true,
    recorder_file=recorder_file,
    populations=2,
    population_size=100,
    maxsize=20,
    complexity_of_operators=[cos => 2],
)

hall_of_fame = equation_search(
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
    @test haskey(data.mutations[key], :cost)
    @test haskey(data.mutations[key], :tree)
    @test haskey(data.mutations[key], :loss)
    @test haskey(data.mutations[key], :parent)
    if i > 10
        break
    end
end

@test_throws ErrorException recursive_merge()
