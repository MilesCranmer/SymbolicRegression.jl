using SymbolicRegression
import SymbolicRegression.AdaptiveParsimonyModule:
    RunningSearchStatistics, update_frequencies!, move_window!, normalize_frequencies!
using Test

options = Options()

statistics = RunningSearchStatistics(; options=options, window_size=100)

for i in 1:1000
    update_frequencies!(statistics; size=rand(1:10))
end

normalize_frequencies!(statistics)

@test sum(statistics.frequencies) == 1022
@test sum(statistics.normalized_frequencies) ≈ 1.0 atol = 1e-6

move_window!(statistics)

@test sum(statistics.frequencies) ≈ 100.0 atol = 1e-6

normalize_frequencies!(statistics)

@test statistics.normalized_frequencies[5] > statistics.normalized_frequencies[15]
