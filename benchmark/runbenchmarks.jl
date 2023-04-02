using CSV
using Statistics: median

function parse_flags(args)
    flags = Dict{String,String}()
    for arg in args
        if occursin("--", arg)
            key, value = split(arg, "=")
            key = replace(key, "--" => "")
            flags[key] = value
        end
    end
    return flags
end

# Get sha of current commit:
default_target = readchomp(`git rev-parse HEAD`)

# Get latest tag:
default_baseline = readchomp(`git describe --tags --abbrev=0`)

target = get(parse_flags(ARGS), "target", default_target)
baseline = get(parse_flags(ARGS), "baseline", default_baseline)

# Evaluate benchmarks defined in benchmarks.jl, at different revisions:
for (module_name, sha) in zip((:TargetModule, :BaselineModule), (target, baseline))
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

        using BenchmarkTools

        # Include benchmark, defining SUITE:
        const bench_path = joinpath(@__DIR__, "benchmarks.jl")
        include(bench_path)
        println("Running tuning for ", $sha, ".")
        tune!(SUITE)
        println("Running benchmarks for ", $sha, ".")
        results = run(SUITE)
        println("Finished benchmarks for ", $sha, ".")
    end
end

import .TargetModule: results as target_results
import .BaselineModule: results as baseline_results
