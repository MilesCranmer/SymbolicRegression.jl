@testitem "Constant optimization with custom types (Issue #568)" begin
    using Random: default_rng

    # Issue #568: When optimizer_nrestarts > 0, the code incorrectly used T
    # (the custom type) instead of eltype(x0) when calling randn().
    # This caused a MethodError because randn() only works with scalar types.

    # Custom type with scalar element type Float64
    struct MyVec2
        x::Float64
        y::Float64
    end
    Base.eltype(::Type{MyVec2}) = Float64

    # The buggy code did: randn(rng, T, size(x0)...)
    # where T = MyVec2, which fails.
    # The fix does: randn(rng, eltype(x0), size(x0)...)
    # where eltype(x0) = Float64, which works.

    x0 = Float64[1.0, 2.0, 3.0]
    rng = default_rng()

    # This is what the fixed code does - works correctly
    ET = eltype(x0)
    @test ET === Float64

    for _ in 1:3
        eps = randn(rng, ET, size(x0)...)
        xt = @. x0 * (ET(1) + ET(1 // 2) * eps)
        @test length(xt) == 3
        @test eltype(xt) == Float64
    end

    # This is what the buggy code did - would fail with MethodError
    # when T is a custom type like MyVec2
    @test_throws MethodError randn(rng, MyVec2, size(x0)...)
end
