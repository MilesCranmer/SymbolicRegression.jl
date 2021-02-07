using PkgBenchmark
import SymbolicRegression

config = BenchmarkConfig(;id="HEAD", juliacmd=`julia -O3`,
                          env = Dict("JULIA_NUM_THREADS" => 4))
benchmarkpkg(SymbolicRegression, config)
