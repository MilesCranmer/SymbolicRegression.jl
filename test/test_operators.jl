using SymbolicRegression
using SymbolicRegression:
    plus,
    sub,
    mult,
    square,
    cube,
    div,
    log_abs,
    log2_abs,
    log10_abs,
    sqrt_abs,
    acosh_abs,
    neg,
    greater,
    greater,
    relu,
    logical_or,
    logical_and,
    gamma
include("test_params.jl")

# Generic operator tests
types_to_test = [Float16, Float32, Float64, BigFloat]
for T in types_to_test
    val = T(0.5)
    val2 = T(3.2)
    @test sqrt_abs(val) == sqrt_abs(-val)
    @test abs(log_abs(-val) - log(val)) < 1e-6
    @test abs(log2_abs(-val) - log2(val)) < 1e-6
    @test abs(log10_abs(-val) - log10(val)) < 1e-6
    @test neg(-val) == val
    @test sqrt_abs(val) == sqrt(val)
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
