using PkgBenchmark
using DataFrames
using CSV
using Statistics: median
using SymbolicRegression: SymbolicRegression
config = BenchmarkConfig(; juliacmd=`julia -O3`, env=Dict("JULIA_NUM_THREADS" => 4))
_results = benchmarkpkg(SymbolicRegression, config; script="benchmark/.benchmarks.jl")
results = vcat(
    [
        [["evaluation_" * k, median(v.times)] for (k, v) in bigV] for
        (bigK, bigV) in _results.benchmarkgroup.data
    ]...,
)
df = DataFrame(;
    commit=_results.commit,
    name=[results[i][1] for i in 1:length(results)],
    time=[results[i][2] for i in 1:length(results)],
)

CSV.write("output.csv", df; append=true)
