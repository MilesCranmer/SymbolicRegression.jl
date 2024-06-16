using SymbolicRegression
using SymbolicRegression.UtilsModule:
    findmin_fast, argmin_fast, bottomk_fast, is_anonymous_function
using Random

function simple_bottomk(x, k)
    idx = sortperm(x)[1:k]
    return x[idx], idx
end

array_options = [
    (n=n, seed=seed, T=T) for n in (1, 5, 20, 50, 100, 1000), seed in 1:10,
    T in (Float32, Float64, Int)
]

@testset "argmin_fast" begin
    for opt in array_options
        x = rand(MersenneTwister(opt.seed), opt.T, opt.n) .* 2 .- 1
        @test findmin_fast(x) == findmin(x)
        @test argmin_fast(x) == argmin(x)
    end
end
@testset "bottomk_fast" begin
    for opt in array_options, k in (1, 2, 3, 5, 10, 20, 50, 100)
        k > opt.n && continue
        x = rand(MersenneTwister(opt.seed), opt.T, opt.n) .* 2 .- 1
        @test bottomk_fast(x, k) == simple_bottomk(x, k)
    end
end
