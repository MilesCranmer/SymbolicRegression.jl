using JSON3
using Statistics: mean, std, quantile, median
using Revise

names = ARGS

if length(names) == 0
    # Print usage:
    @error "Usage: julia --project=benchmark benchmark/runbenchmarks.jl <rev1> <rev2> ..."
end

shas = String[]
module_names = Symbol[]

for arg in names
    sha = readchomp(`git rev-parse $(arg)`)
    push!(shas, sha)
    push!(module_names, Symbol("Module_" * sha))
end

# Evaluate benchmarks defined in benchmarks.jl, at different revisions:
combined_results = Dict{String,Any}()
for (name, sha, module_name) in zip(names, shas, module_names)
    @eval module $module_name
    using Pkg
    # Create temp env:
    tmp_env = mktempdir()
    Pkg.activate(tmp_env)
    Pkg.add([
        PackageSpec(; name="SymbolicRegression", rev=$sha),
        PackageSpec(; name="BenchmarkTools"),
        PackageSpec(; name="Random"),
    ])

    using BenchmarkTools: run

    # Include benchmark, defining SUITE:
    const bench_path = joinpath(@__DIR__, "benchmarks.jl")
    include(bench_path)
    println("Running benchmarks for ", $name, "==", $sha, ".")
    results = run(SUITE)
    println("Finished benchmarks for ", $name, "==", $sha, ".")
    end

    @eval import .$(module_name): results as $(Symbol("results_" * sha))
    combined_results[name] = @eval $(Symbol("results_" * sha))
    open(joinpath(@__DIR__, "results_$(name).json"), "w") do io
        write(io, JSON3.write(combined_results[name]))
    end
end

# Store as big json, as well as json per revision:
open(joinpath(@__DIR__, "combined_results.json"), "w") do io
    write(io, JSON3.write(combined_results))
end
