@testitem "Constant optimization with custom types (Issue #568)" begin
    using DynamicExpressions: Expression, OperatorEnum, get_tree
    using DynamicExpressions.NodeModule: Node
    import DynamicExpressions.ValueInterfaceModule:
        count_scalar_constants,
        get_number_type,
        pack_scalar_constants!,
        unpack_scalar_constants
    using Optim: Optim
    using Random: default_rng
    using SymbolicRegression: Dataset, Options, PopMember
    using SymbolicRegression.EvolutionModule.ConstantOptimizationModule: _optimize_constants

    # Issue #568:
    # The constant-optimization restart loop used the PopMember type parameter `T`
    # (which can be non-scalar) when generating noise:
    #     randn(rng, T, size(x0)...)   # BUG
    #
    # But x0 is a vector of scalar constants, so noise must be drawn from eltype(x0).
    #
    # This test uses:
    # - a real Dataset{T} where each feature/target is itself a small vector-like object,
    # - a real DynamicExpressions.Expression{T} with a constant of type T,
    # - a real optimization run via `_optimize_constants`.

    # A small vector-like custom type (stands in for "T is a vector"):
    struct Vec2
        x::Float64
        y::Float64
    end

    # Implement the DynamicExpressions ValueInterface so scalar constants can be packed/unpacked.
    get_number_type(::Type{Vec2}) = Float64
    count_scalar_constants(::Vec2) = 2
    function pack_scalar_constants!(nvals::AbstractVector{<:Number}, idx::Int, v::Vec2)
        nvals[idx] = v.x
        nvals[idx + 1] = v.y
        return idx + 2
    end
    function unpack_scalar_constants(nvals::AbstractVector{<:Number}, idx::Int, v::Vec2)
        return idx + 2, Vec2(nvals[idx], nvals[idx + 1])
    end

    rng = default_rng()

    n = 16
    X = fill(Vec2(0.0, 0.0), 1, n)
    target = Vec2(0.3, -0.7)
    y = fill(target, n)
    dataset = Dataset(X, y, Float64)

    operators = OperatorEnum(1 => (), 2 => ())

    # Constant expression of type Vec2; its scalar constants are [x, y].
    ex = Expression(Node(Vec2; val=Vec2(1.0, 2.0)); operators, variable_names=["x1"])

    # Loss depends on the constant Vec2 value and the (Vec2) targets.
    function loss(ex::Expression{Vec2}, dataset::Dataset{Vec2,Float64}, _options)
        c = get_tree(ex).val::Vec2
        s = 0.0
        @inbounds for yi in dataset.y
            dx = c.x - yi.x
            dy = c.y - yi.y
            s += dx * dx + dy * dy
        end
        return s / dataset.n
    end

    options = Options(;
        binary_operators=(+,),
        unary_operators=(),
        deterministic=true,
        optimizer_nrestarts=2,
        autodiff_backend=nothing,
        parsimony=0.0,
        loss_function_expression=loss,
    )

    member = PopMember(dataset, ex, options; deterministic=true)

    algorithm = Optim.BFGS()
    optimizer_options = Optim.Options(; iterations=200)

    new_member, _ = _optimize_constants(
        dataset, member, options, algorithm, optimizer_options, rng
    )

    c = get_tree(new_member.tree).val::Vec2
    @test abs(c.x - target.x) < 1e-3
    @test abs(c.y - target.y) < 1e-3
end

@testitem "Constant mutation for discrete custom values" begin
    using DynamicExpressions: Expression, GenericOperatorEnum, get_tree
    using DynamicExpressions.NodeModule: Node
    import DynamicExpressions.ValueInterfaceModule: count_scalar_constants
    using Random: AbstractRNG
    using SymbolicRegression
    using SymbolicRegression: Dataset, TraceType
    using SymbolicRegression.EvolutionModule.MutateModule: next_generation

    struct DiscreteValue
        value::Int
    end

    combine(a::DiscreteValue, b::DiscreteValue) = DiscreteValue(a.value + b.value)
    count_scalar_constants(::DiscreteValue) = 0

    seen_mutation = Ref{Union{Nothing,ConstantMutation}}(nothing)
    function SymbolicRegression.mutate_value(
        ::AbstractRNG, value::DiscreteValue, _, mutation::ConstantMutation
    )
        seen_mutation[] = mutation
        return DiscreteValue(value.value + 1)
    end

    mutation = ConstantMutation(; perturbation_factor=0.2, probability_negate=0.3)
    options = Options(;
        binary_operators=(combine,),
        unary_operators=(),
        operator_enum_constructor=GenericOperatorEnum,
        elementwise_loss=(prediction, target) -> Float64(prediction.value != target.value),
        default_mutations=(),
        mutations=(mutation => 1.0,),
        default_plugins=(),
        deterministic=true,
    )
    dataset = Dataset(fill(DiscreteValue(1), 1, 4), fill(DiscreteValue(3), 4), Float64)
    tree = Node{DiscreteValue}(;
        op=1,
        children=(
            Node{DiscreteValue}(; feature=1), Node{DiscreteValue}(; val=DiscreteValue(1))
        ),
    )
    expression = Expression(tree; operators=options.operators, variable_names=["x"])
    member = PopMember(dataset, expression, options; deterministic=true)
    plugin_states = SymbolicRegression.init_plugin_states(options, dataset)

    new_member, _, _ = next_generation(
        dataset, member, options.maxsize, options; tmp_trace=TraceType(), plugin_states
    )

    @test seen_mutation[] == mutation
    @test only(
        node.val for node in get_tree(new_member.tree) if node.degree == 0 && node.constant
    ) == DiscreteValue(2)
end
