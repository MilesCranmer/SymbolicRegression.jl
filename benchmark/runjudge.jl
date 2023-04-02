# This file was modified from Transducers.jl
# which is available under an MIT license.
using PkgBenchmark

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

baseline = get(parse_flags(ARGS), "baseline", "master")

function mkconfig(; kwargs...)
    return BenchmarkConfig(; env=Dict("JULIA_NUM_THREADS" => "1"), kwargs...)
end

group_target = benchmarkpkg(
    dirname(@__DIR__), mkconfig(); resultfile=joinpath(@__DIR__, "result-target.json")
)

group_baseline = benchmarkpkg(
    dirname(@__DIR__),
    mkconfig(; id=baseline);
    resultfile=joinpath(@__DIR__, "result-baseline.json"),
)

judgement = judge(group_target, group_baseline)
