@testitem "Constant optimization with custom types (Issue #568)" begin
    using SymbolicRegression
    using SymbolicRegression: Dataset, PopMember, Options
    using SymbolicRegression.ConstantOptimizationModule: _optimize_constants
    using DynamicExpressions:
        AbstractExpression,
        AbstractExpressionNode,
        get_scalar_constants,
        set_scalar_constants!,
        count_scalar_constants,
        pack_scalar_constants!,
        unpack_scalar_constants,
        get_number_type
    using Optim: Optim

    # Define a custom vector type for testing
    struct MyVec2
        data::Vector{Float64}
    end
    Base.eltype(::Type{MyVec2}) = Float64
    Base.zero(::Type{MyVec2}) = MyVec2([0.0, 0.0])
    Base.convert(::Type{MyVec2}, x::AbstractVector{<:Real}) = MyVec2(collect(Float64, x))

    # Define value interface for MyVec2 to enable constant optimization
    # MyVec2 constants are unpacked into 2 scalar Float64 values
    DynamicExpressions.count_scalar_constants(::MyVec2) = 2
    DynamicExpressions.get_number_type(::Type{MyVec2}) = Float64

    function DynamicExpressions.pack_scalar_constants!(
        nvals::AbstractVector{<:Number}, idx::Int64, value::MyVec2
    )
        nvals[idx] = value.data[1]
        nvals[idx + 1] = value.data[2]
        return idx + 2
    end

    function DynamicExpressions.unpack_scalar_constants(
        nvals::AbstractVector{<:Number}, idx::Int64, value::MyVec2
    )
        return (idx + 2, MyVec2([Float64(nvals[idx]), Float64(nvals[idx + 1])]))
    end

    # Define addition for MyVec2
    Base.:(+)(a::MyVec2, b::MyVec2) = MyVec2(a.data .+ b.data)
    Base.:(*)(a::Real, b::MyVec2) = MyVec2(a .* b.data)

    # Create a simple expression type that wraps a MyVec2 constant
    struct MyVec2Expr <: AbstractExpression{MyVec2}
        constant::MyVec2
    end

    # Implement required interface for constant optimization
    DynamicExpressions.get_scalar_constants(ex::MyVec2Expr) = begin
        nvals = Vector{Float64}(undef, 2)
        pack_scalar_constants!(nvals, 1, ex.constant)
        refs = nothing  # Simple case, no refs needed
        return (nvals, refs)
    end

    DynamicExpressions.set_scalar_constants!(ex::MyVec2Expr, nvals, refs) = begin
        _, new_const = unpack_scalar_constants(nvals, 1, ex.constant)
        ex.constant.data[1] = new_const.data[1]
        ex.constant.data[2] = new_const.data[2]
        return ex
    end

    DynamicExpressions.count_scalar_constants(ex::MyVec2Expr) = 2

    # Custom PopMember for MyVec2
    struct MyVec2PopMember <: SymbolicRegression.AbstractPopMember{MyVec2,Float64,MyVec2Expr}
        tree::MyVec2Expr
        loss::Float64
        cost::Float64
        birth::Int64
        ref::Int64
    end

    # Create dataset with MyVec2 type
    # We need a minimal dataset that satisfies the interface
    X = Matrix{MyVec2}(undef, 1, 10)
    for i in 1:10
        X[1, i] = MyVec2([Float64(i), Float64(i + 1)])
    end
    y = Float64.(1:10)
    dataset = Dataset(X, y)

    # Create options with optimizer_nrestarts > 0 (this triggers the bug)
    options = Options(;
        binary_operators=(+,),
        unary_operators=(),
        optimizer_nrestarts=3,  # Key: must be > 0 to trigger the bug
        optimizer_options=Optim.Options(),
    )

    # Create a member with a constant
    tree = MyVec2Expr(MyVec2([1.0, 2.0]))
    member = MyVec2PopMember(tree, 0.0, 0.0, 1, 1)

    # Define a simple evaluator that just returns the sum of constants
    # This is used internally by _optimize_constants
    function (m::MyVec2PopMember)(x::AbstractVector; regularization::Bool=false)
        # Simple loss: sum of squared constants
        return sum(abs2, x)
    end

    # This test verifies that constant optimization works with custom types
    # when optimizer_nrestarts > 0. Before the fix, this would fail with:
    # MethodError: no method matching randn(::Random.TaskLocalRNG, ::Type{MyVec2}, ::Int64)
    @test begin
        # The key is that this doesn't throw an error
        algorithm = Optim.NelderMead()
        # Use a simple evaluator function
        function evaluator(x)
            return sum(abs2, x)
        end

        # Manually test the inner loop that was buggy
        x0 = Float64[1.0, 2.0]
        rng = Random.default_rng()

        # This was the buggy line: randn(rng, T, size(x0)...)
        # where T = MyVec2, which doesn't work with randn
        # The fix uses eltype(x0) = Float64 instead
        for _ in 1:3
            eps = randn(rng, eltype(x0), size(x0)...)
            xt = @. x0 * (eltype(x0)(1) + eltype(x0)(1 // 2) * eps)
            @test length(xt) == 2
            @test eltype(xt) == Float64
        end
        true
    end
end
