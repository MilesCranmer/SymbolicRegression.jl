using SymbolicRegression
using SymbolicRegression:
    plus,
    sub,
    mult,
    square,
    cube,
    div,
    log_nan,
    log2_nan,
    log10_nan,
    sqrt_nan,
    acosh_nan,
    neg,
    greater,
    greater,
    relu,
    logical_or,
    logical_and,
    gamma
using Test
include("test_params.jl")

# Generic operator tests
types_to_test = [Float16, Float32, Float64, BigFloat]
for T in types_to_test
    val = T(0.5)
    val2 = T(3.2)
    @test abs(log_nan(val) - log(val)) < 1e-6
    @test isnan(log_nan(-val))
    @test abs(log2_nan(val) - log2(val)) < 1e-6
    @test isnan(log2_nan(-val))
    @test abs(log10_nan(val) - log10(val)) < 1e-6
    @test isnan(log10_nan(-val))
    @test abs(acosh_nan(val2) - acosh(val2)) < 1e-6
    @test isnan(acosh_nan(-val2))
    @test neg(-val) == val
    @test sqrt_nan(val) == sqrt(val)
    @test isnan(sqrt_nan(-val))
    @test mult(val, val2) == val * val2
    @test plus(val, val2) == val + val2
    @test sub(val, val2) == val - val2
    @test square(val) == val * val
    @test cube(val) == val * val * val
    @test div(val, val2) == val / val2
    @test greater(val, val2) == T(0.0)
    @test greater(val2, val) == T(1.0)
    @test relu(-val) == T(0.0)
    @test relu(val) == val
    @test logical_or(val, val2) == T(1.0)
    @test logical_or(T(0.0), val2) == T(1.0)
    @test logical_and(T(0.0), val2) == T(0.0)
end
