using SymbolicRegression
using SymbolicRegression:
    plus,
    sub,
    mult,
    square,
    cube,
    safe_pow,
    div,
    safe_log,
    safe_log2,
    safe_log10,
    safe_sqrt,
    safe_acosh,
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
    @test abs(safe_log(val) - log(val)) < 1e-6
    @test isnan(safe_log(-val))
    @test abs(safe_log2(val) - log2(val)) < 1e-6
    @test isnan(safe_log2(-val))
    @test abs(safe_log10(val) - log10(val)) < 1e-6
    @test isnan(safe_log10(-val))
    @test abs(safe_acosh(val2) - acosh(val2)) < 1e-6
    @test isnan(safe_acosh(-val2))
    @test neg(-val) == val
    @test safe_sqrt(val) == sqrt(val)
    @test isnan(safe_sqrt(-val))
    @test mult(val, val2) == val * val2
    @test plus(val, val2) == val + val2
    @test sub(val, val2) == val - val2
    @test square(val) == val * val
    @test cube(val) == val * val * val
    @test isnan(safe_pow(T(0.0), -T(1.0)))
    @test isnan(safe_pow(-val, val2))
    @test all(isnan.([safe_pow(-val, -val2), safe_pow(T(0.0), -val2)]))
    @test abs(safe_pow(val, val2) - val^val2) < 1e-6
    @test abs(safe_pow(val, -val2) - val^(-val2)) < 1e-6
    @test !isnan(safe_pow(T(-1.0), T(2.0)))
    @test isnan(safe_pow(T(-1.0), T(2.1)))
    @test isnan(safe_log(zero(T)))
    @test isnan(safe_log2(zero(T)))
    @test isnan(safe_log10(zero(T)))
    @test div(val, val2) == val / val2
    @test greater(val, val2) == T(0.0)
    @test greater(val2, val) == T(1.0)
    @test relu(-val) == T(0.0)
    @test relu(val) == val
    @test logical_or(val, val2) == T(1.0)
    @test logical_or(T(0.0), val2) == T(1.0)
    @test logical_and(T(0.0), val2) == T(0.0)
end
