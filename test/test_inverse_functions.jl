@testitem "Approximate Inverse Functions (Unary)" tags = [:part3] begin
    using SymbolicRegression
    using SymbolicRegression.InverseFunctionsModule: approx_inverse
    using Random: MersenneTwister

    include("test_params.jl")

    #! format: off
    unary_ops = [
        sin, safe_asin, cos, safe_acos, tan, atan, sinh, asinh,
        cosh, tanh, atanh_clip, square, safe_sqrt,
        cube, cbrt, exp, safe_log, safe_log2, exp2,
        safe_log10, exp10, safe_log1p,
        neg, inv, relu, abs
    ]
    #! format: on

    for T in [ComplexF64, Float64]
        rng = MersenneTwister(0)
        x = rand(rng, T, 64)
        for f in unary_ops
            T == ComplexF64 && f in (cbrt, cube, abs) && continue  # Missing/Unavailable
            x̂ = map(ComposedFunction(approx_inverse(f), f), x)
            @test x̂ ≈ x || (@info f; false)
        end

        x_above_1 = x .+ 1
        for f in [safe_acosh]
            x̂ = map(ComposedFunction(approx_inverse(f), f), x_above_1)
            @test x̂ ≈ x_above_1 || (@info f; false)
        end
    end
end

@testitem "Approximate Inverse Functions (Binary)" tags = [:part3] begin
    using SymbolicRegression
    using SymbolicRegression.InverseFunctionsModule: approx_inverse
    using Random: MersenneTwister

    rng = MersenneTwister(0)

    binary_ops = [+, -, *, /, safe_pow, safe_log]

    for T in [ComplexF64, Float64]
        x = rand(rng, T, 64)
        constants = map(T, [0.5, 1.5, 2.5])
        for f in binary_ops, c in constants
            if f == safe_pow && abs(c) > 1.0
                continue  # Due to branch cuts, can't compare effectively
            end

            f_fix1 = Base.Fix1(f, c)
            x̂ = map(ComposedFunction(approx_inverse(f_fix1), f_fix1), x)
            @test x̂ ≈ x || (@info f_fix1 x̂ x; false)

            f_fix2 = Base.Fix2(f, c)
            x̂ = map(ComposedFunction(approx_inverse(f_fix2), f_fix2), x)
            @test x̂ ≈ x || (@info f_fix2 x̂ x; false)
        end
    end
end
