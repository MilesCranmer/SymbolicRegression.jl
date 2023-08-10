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

# Test built-in operators pass validation:
types_to_test = [Float16, Float32, Float64, BigFloat]
options = Options(;
    binary_operators=[plus, sub, mult, div, ^, greater, logical_or, logical_and],
    unary_operators=[square, cube, log, log2, log10, sqrt, acosh, neg, relu],
)
for T in types_to_test
    @test_nowarn SymbolicRegression.assert_operators_well_defined(T, options)
end

# Reduced set for complex numbers
options = Options(;
    binary_operators=[plus, sub, mult, div, ^],
    unary_operators=[square, cube, log, log2, log10, sqrt, acosh, neg],
)
types_to_test = [ComplexF16, ComplexF32, ComplexF64]
for T in types_to_test
    @test_nowarn SymbolicRegression.assert_operators_well_defined(T, options)
end

# Some of these should fail:
options = Options(; binary_operators=[greater])
@test_throws ErrorException SymbolicRegression.assert_operators_well_defined(
    ComplexF64, options
)
VERSION >= v"1.8" &&
    @test_throws "complex plane" SymbolicRegression.assert_operators_well_defined(
        ComplexF64, options
    )

# Operators which return the wrong type should fail:
my_bad_op(x) = 1.0f0
options = Options(; binary_operators=[], unary_operators=[my_bad_op])
@test_throws ErrorException SymbolicRegression.assert_operators_well_defined(
    Float64, options
)
VERSION >= v"1.8" &&
    @test_throws "returned an output of type" SymbolicRegression.assert_operators_well_defined(
        Float64, options
    )
@test_nowarn SymbolicRegression.assert_operators_well_defined(Float32, options)
