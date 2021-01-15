include("operators.jl")

const una_constraints = [-1, -1]
const bin_constraints = [(-1, -1), (-1, -1), (-1, -1)]
const binops = [div, plus, mult]
const unaops = [sin, cos]
const ns=10;
const parsimony = 0.000100f0
const alpha = 0.100000f0
const maxsize = 20
const maxdepth = 20
const fast_cycle = false
const migration = true
const hofMigration = true
const fractionReplacedHof = 0.1f0
const shouldOptimizeConstants = true
const hofFile = "hall_of_fame_2021-01-14_231428.677.csv"
const nprocs = 4
const npopulations = 4
const nrestarts = 3
const perturbationFactor = 1.000000f0
const annealing = true
const weighted = false
const batching = true
const batchSize = 50
const useVarMap = false
const mutationWeights = [
    10.000000,
    1.000000,
    1.000000,
    3.000000,
    3.000000,
    0.010000,
    1.000000,
    1.000000
]
const warmupMaxsize = 1
const limitPowComplexity = false
const useFrequency = true

@inline function BINOP!(x::Array{Float32, 1}, y::Array{Float32, 1}, i::Int, clen::Int)
    if i === 1
        @inbounds @simd for j=1:clen
            x[j] = div(x[j], y[j])
        end
    elseif i === 2
        @inbounds @simd for j=1:clen
            x[j] = plus(x[j], y[j])
        end
    elseif i === 3
        @inbounds @simd for j=1:clen
            x[j] = mult(x[j], y[j])
        end
    end
end
@inline function UNAOP!(x::Array{Float32, 1}, i::Int, clen::Int)
    if i === 1
        @inbounds @simd for j=1:clen
            x[j] = sin(x[j])
        end
    elseif i === 2
        @inbounds @simd for j=1:clen
            x[j] = cos(x[j])
        end
    end
end
