using PkgBenchmark
import SymbolicRegression

results = []
cp("benchmark/benchmarks.jl", "benchmark/.benchmarks.jl"; force=true)

for i=1:10
    config = BenchmarkConfig(;id=(i == 1 ? nothing : "HEAD~$i"),
                              juliacmd=`julia -O3`,
                              env=Dict("JULIA_NUM_THREADS" => 4))
    push!(results,
          benchmarkpkg(SymbolicRegression, config; script="benchmark/.benchmarks.jl"))
end
