@testitem "Constant optimization with custom types (Issue #568)" begin
    using DynamicExpressions: AbstractExpression, OperatorEnum
    using DynamicExpressions.NodeModule: Node
    import DynamicExpressions:
        copy,
        extract_gradient,
        get_contents,
        get_metadata,
        get_operators,
        get_scalar_constants,
        get_tree,
        get_variable_names,
        set_scalar_constants!
    using Optim: Optim
    using Random: default_rng
    using SymbolicRegression: Dataset, Options, PopMember
    using SymbolicRegression.ConstantOptimizationModule: _optimize_constants_inner

    # Issue #568:
    # The constant-optimization restart loop used the PopMember type parameter `T`
    # (which can be non-scalar, e.g. `T <: AbstractVector`) when generating noise:
    #     randn(rng, T, size(x0)...)   # BUG
    #
    # But x0 is a vector of *scalar* constants, so noise must be drawn from
    # `eltype(x0)` instead.

    # Pick a non-scalar T that definitely does NOT support randn(::Type{T}, ...)
    const T = Vector{Float64}

    # Minimal AbstractExpression implementation.
    #
    # Note: DynamicExpressions' AbstractExpression has a fairly rich interface.
    # We implement the required methods in the simplest possible way, but keep
    # this type *local* to the test so we don't affect other tests.
    mutable struct DummyExpr{T,N,M} <: AbstractExpression{T,N}
        tree::N
        metadata::M
        constants::Vector{Float64}
    end
    get_tree(ex::DummyExpr) = ex.tree
    get_metadata(ex::DummyExpr) = ex.metadata
    get_contents(ex::DummyExpr) = (tree=ex.tree,)
    copy(ex::DummyExpr; break_sharing::Val=Val(false)) = ex
    get_variable_names(::DummyExpr, variable_names=nothing) = ["x1"]
    get_operators(::DummyExpr, operators=nothing) = something(
        operators, OperatorEnum(1 => (), 2 => ())
    )
    get_scalar_constants(ex::DummyExpr) = (copy(ex.constants), nothing)
    function set_scalar_constants!(ex::DummyExpr{T}, constants, _refs) where {T}
        ex.constants .= constants
        return nothing
    end
    extract_gradient(gradient, ::DummyExpr) = gradient

    x0 = [1.0, 2.0]
    tree = DummyExpr{T,Node{Float64,2},Nothing}(
        Node{Float64,2}(; feature=1), nothing, copy(x0)
    )

    # Use a real Dataset object (so the improved-cost branch is exercised).
    rng = default_rng()
    X = randn(rng, 2, 16)
    y = randn(rng, 16)
    dataset = Dataset(X, y)

    options = Options(;
        binary_operators=(+,),
        unary_operators=(),
        deterministic=true,
        optimizer_nrestarts=2,
        autodiff_backend=nothing,
        parsimony=0.0,
    )

    # Ensure cost calculation doesn't depend on computing tree complexity.
    member = PopMember(tree, 0.0, 0.0, options, 1; deterministic=true)

    refs = nothing

    target = [0.3, -0.7]
    function f(x; regularization=false)
        return sum(abs2, x .- target)
    end

    fg! = nothing
    algorithm = Optim.BFGS()
    optimizer_options = Optim.Options(; iterations=50)

    new_member, _ = _optimize_constants_inner(
        f, fg!, x0, refs, dataset, member, options, algorithm, optimizer_options, rng
    )

    @test maximum(abs.(new_member.tree.constants .- target)) < 1e-3
end
