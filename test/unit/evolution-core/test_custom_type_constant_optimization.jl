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
    using SymbolicRegression: Options, PopMember
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
    struct DummyExpr{T,N,M} <: AbstractExpression{T,N}
        tree::N
        metadata::M
    end
    get_tree(ex::DummyExpr) = ex.tree
    get_metadata(ex::DummyExpr) = ex.metadata
    get_contents(ex::DummyExpr) = (tree=ex.tree,)
    copy(ex::DummyExpr; break_sharing::Val=Val(false)) = ex
    get_variable_names(::DummyExpr, variable_names=nothing) = ["x1"]
    get_operators(::DummyExpr, operators=nothing) = something(
        operators, OperatorEnum(1 => (), 2 => ())
    )
    get_scalar_constants(::DummyExpr) = (Float64[], nothing)
    set_scalar_constants!(::DummyExpr{T}, _constants, _refs) where {T} = nothing
    extract_gradient(gradient, ::DummyExpr) = gradient

    tree = DummyExpr{T,Node{Float64,2},Nothing}(Node{Float64,2}(; feature=1), nothing)

    # Dummy dataset only needs dataset_fraction.
    struct DummyDataset end
    import SymbolicRegression.CoreModule: dataset_fraction
    dataset_fraction(::DummyDataset) = 1.0

    options = Options(;
        binary_operators=(+,), unary_operators=(), deterministic=true, optimizer_nrestarts=2
    )

    member = PopMember(tree, 0.0, 0.0, options; deterministic=true)

    x0 = [1.0, 2.0, 3.0]
    refs = nothing

    # Keep f constant so we don't take the branch that needs real dataset fields.
    f(_x; regularization=false) = 1.0
    fg! = nothing

    rng = default_rng()
    algorithm = Optim.Newton()
    optimizer_options = Optim.Options(; iterations=1)

    _optimize_constants_inner(
        f, fg!, x0, refs, DummyDataset(), member, options, algorithm, optimizer_options, rng
    )

    @test true
end
