using PkgBenchmark
import SymbolicRegression

results = []

for i=1:10
    config = BenchmarkConfig(;id=(i == 1 ? nothing : "HEAD~$i"),
                              juliacmd=`julia -O3`,
                              env=Dict("JULIA_NUM_THREADS" => 4))
    push!(results,
          benchmarkpkg(SymbolicRegression, config))
end
