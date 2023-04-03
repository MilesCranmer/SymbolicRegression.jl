using JSON3
using Statistics: mean, std, quantile, median
using Revise

names = ARGS

if length(names) == 0
    # Print usage:
    @error "Usage: julia --project=benchmark benchmark/runbenchmarks.jl <rev1> <rev2> ..."
end

shas = String[]

for arg in names
    sha = readchomp(`git rev-parse $(arg)`)
    push!(shas, sha)
end

# Evaluate benchmarks defined in benchmarks.jl, at different revisions:
combined_results = Dict{String,Any}()
const DIR = @__DIR__
for (name, sha) in zip(names, shas)
    tmp_env = mktempdir()
    cmd_string = """
    using Pkg
    Pkg.add([
        PackageSpec(; name="SymbolicRegression", rev="$sha"),
        PackageSpec(; name="DynamicExpressions"),
        PackageSpec(; name="BenchmarkTools"),
        PackageSpec(; name="Random"),
        PackageSpec(; name="JSON3"),
    ])

    using BenchmarkTools: run
    using JSON3

    # Include benchmark, defining SUITE:
    const bench_path = joinpath("$DIR", "benchmarks.jl")
    include(bench_path)
    println("Running benchmarks for $name==$sha.")
    results = run(SUITE)
    println("Finished benchmarks for $name==$sha.")
    open(joinpath("$DIR", "results_$(name).json"), "w") do io
        write(io, JSON3.write(results))
    end
    """
    run(`julia -O3 --threads=4 --project=$tmp_env -e $cmd_string`)
end
