using SymbolicRegression
import SymbolicRegression.AdaptiveParsimonyModule:
    RunningSearchStatistics, update_frequencies!, move_window!, normalize_frequencies!
using Test
using Random

options = Options()

statistics = RunningSearchStatistics(; options=options, window_size=500)

for i in 1:1000
    update_frequencies!(statistics; size=rand(MersenneTwister(i), 1:10))
end

normalize_frequencies!(statistics)

@test sum(statistics.frequencies) == 1022
@test sum(statistics.normalized_frequencies) ≈ 1.0
@test statistics.normalized_frequencies[5] > statistics.normalized_frequencies[15]

move_window!(statistics)

@test sum(statistics.frequencies) ≈ 500.0

normalize_frequencies!(statistics)

@test sum(statistics.normalized_frequencies[1:5]) >
    sum(statistics.normalized_frequencies[10:15])

for i in 1:500
    update_frequencies!(statistics; size=rand(MersenneTwister(i), 10:15))
end

move_window!(statistics)

@test sum(statistics.frequencies) ≈ 500.0

normalize_frequencies!(statistics)

@test sum(statistics.normalized_frequencies[1:5]) <
    sum(statistics.normalized_frequencies[10:15])
