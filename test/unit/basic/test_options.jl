@testitem "Test options" begin
    using SymbolicRegression
    using Optim: Optim

    # testing types
    op = Options(; optimizer_options=(iterations=16, f_calls_limit=100, x_abstol=1e-16))
    @test isa(op.optimizer_options, Optim.Options)

    op = Options(;
        optimizer_options=Dict(:iterations => 32, :g_calls_limit => 50, :f_reltol => 1e-16)
    )
    @test isa(op.optimizer_options, Optim.Options)

    optim_op = Optim.Options(; iterations=16)
    op = Options(; optimizer_options=optim_op)
    @test isa(op.optimizer_options, Optim.Options)

    # testing loss_scale parameter
    op_log = Options(; loss_scale=:log)
    @test op_log.loss_scale == :log

    op_linear = Options(; loss_scale=:linear)
    @test op_linear.loss_scale == :linear

    # test that invalid loss_scale values are caught
    @test_throws AssertionError Options(; loss_scale=:invalid)
    @test_throws AssertionError Options(; loss_scale=:cubic)
end

@testitem "Test versioned default profile selection" begin
    using SymbolicRegression
    using SymbolicRegression.ConfigModule.OptionsModule: default_options

    v1_defaults = default_options(v"1.0.0")
    v2_defaults = default_options(v"2.0.0-alpha")
    current_defaults = default_options()

    @test keys(v1_defaults) == keys(v2_defaults) == keys(current_defaults)
    for field in keys(v1_defaults)
        v1_value = getproperty(v1_defaults, field)
        v2_value = getproperty(v2_defaults, field)
        current_value = getproperty(current_defaults, field)
        if field == :mutation_weights
            v1_value = convert(Vector, v1_value)
            v2_value = convert(Vector, v2_value)
            current_value = convert(Vector, current_value)
        end

        @test isequal(current_value, v2_value)
        if field == :crossover_probability
            @test v1_value == 0.0259
            @test v2_value == 0.20
        elseif field == :batching
            @test v1_value === false
            @test v2_value === :auto
        elseif field == :batch_size
            @test v1_value == 50
            @test v2_value === nothing
        else
            @test isequal(v1_value, v2_value)
        end
    end

    @test Options().crossover_probability == 0.20
    @test Options(; defaults=v"1.0.0").crossover_probability == 0.0259
    @test Options(; defaults=v"2.0.0-alpha").adaptive_parsimony_scaling == 1040.0
end

@testitem "Test automatic batching options" begin
    using SymbolicRegression
    using SymbolicRegression.InterfacesModule.DatasetModule: batch
    using SymbolicRegression.ConfigModule.OptionsStructModule:
        batching_required, get_batch_size, use_batching

    struct UnbatchableDataset <: Dataset{Float64,Float64}
        n::Int
    end

    options = Options()
    dataset_1000 = Dataset(zeros(1, 1000), zeros(1000))
    dataset_1001 = Dataset(zeros(1, 1001), zeros(1001))
    @test options.batching === :auto
    @test options.batch_size === nothing
    @test !use_batching(options, dataset_1000)
    @test use_batching(options, dataset_1001)
    @test map(n -> get_batch_size(options, n), (1000, 1001, 4999, 5000, 49999, 50000)) ==
        (1000, 128, 128, 256, 256, 512)
    @test @inferred(use_batching(options, dataset_1001))
    @test @inferred(get_batch_size(options, 5000)) == 256
    @test !(@inferred(batching_required(options, dataset_1000)))

    custom_dataset = UnbatchableDataset(1001)
    @test !use_batching(options, custom_dataset)
    @test !batching_required(options, custom_dataset)

    forced = Options(; batching=true)
    @test use_batching(forced, dataset_1000)
    @test get_batch_size(forced, 1000) == 1000
    @test !batching_required(forced, dataset_1000)
    @test batching_required(forced, custom_dataset)
    @test_throws MethodError batch(custom_dataset, get_batch_size(forced, custom_dataset.n))

    disabled = Options(; batching=false, batch_size=64)
    @test !use_batching(disabled, dataset_1001)
    @test get_batch_size(disabled, 50000) == 64

    explicit_size = Options(; batching=true, batch_size=2000)
    @test get_batch_size(explicit_size, 1000) == 1000
    @test get_batch_size(explicit_size, 5000) == 2000
    @test !batching_required(explicit_size, dataset_1000)
    @test Options(; batch_size=Int32(64)).batch_size === 64

    @test_throws ArgumentError Options(; batching=:sometimes)
    @test_throws ArgumentError Options(; batch_size=0)
end

@testitem "Test backsolve options" begin
    using SymbolicRegression
    using SymbolicRegression.EvolutionModule.BacksolveModule: configured_backsolve

    # Backsolve configuration lives on BacksolveMutation.
    default_backsolve = first(
        p.first for p in Options().mutations if p.first isa BacksolveMutation
    )
    @test default_backsolve == BacksolveMutation()

    custom = Options(;
        default_mutations=(), mutations=[BacksolveMutation(; max_terms=4) => 1.0]
    )
    @test length(custom.mutations) == 1
    @test custom.mutations[1].first.max_terms == 4

    with_override = Options(; mutations=(BacksolveMutation(; max_terms=5) => 1.0,))
    @test length(with_override.mutations) == length(default_mutations())
    @test first(with_override.mutations) == (BacksolveMutation(; max_terms=5) => 1.0)
    @test count(p -> p.first isa BacksolveMutation, with_override.mutations) == 1
    @test configured_backsolve(with_override).max_terms == 5
    @test_throws ArgumentError configured_backsolve(Options(; default_mutations=()))

    @test isempty(Options(; default_mutations=()).mutations)
    @test default_mutations() == SymbolicRegression.default_mutations()

    @test_throws ArgumentError Options(;
        mutation_weights=MutationWeights(), default_mutations=()
    )
end

@testitem "Mutation collections mirror plugin override semantics" begin
    using SymbolicRegression

    struct ProbeMutation <: AbstractMutation
        value::Int
    end

    disabled = Options(; mutations=[ConstantMutation() => 0.0])
    @test first(disabled.mutations) == (ConstantMutation() => 0.0)
    @test count(p -> p.first isa ConstantMutation, disabled.mutations) == 1
    @test length(disabled.mutations) == length(default_mutations())

    added = Options(; mutations=[ProbeMutation(1) => 0.5])
    @test first(added.mutations) == (ProbeMutation(1) => 0.5)
    @test length(added.mutations) == length(default_mutations()) + 1

    no_defaults = Options(; default_mutations=(), mutations=[ProbeMutation(2) => 1.0])
    @test no_defaults.mutations == [ProbeMutation(2) => 1.0]

    custom_defaults = Options(;
        mutations=[ProbeMutation(3) => 0.25],
        default_mutations=[ProbeMutation(4) => 0.75, ConstantMutation() => 1.0],
    )
    @test custom_defaults.mutations == [ProbeMutation(3) => 0.25, ConstantMutation() => 1.0]
end

@testitem "Test operators parameter conflicts" begin
    using SymbolicRegression
    using DynamicExpressions: OperatorEnum

    # Test that when operators is provided, we can't also provide individual sets
    operators = OperatorEnum(1 => (sin, cos), 2 => (+, *, -))
    @test_throws AssertionError Options(; operators, binary_operators=(+, *))
    @test_throws AssertionError Options(; operators, unary_operators=(sin,))

    # Test that when operators is provided, operator_enum_constructor should be nothing
    @test_throws AssertionError Options(; operators, operator_enum_constructor=OperatorEnum)

    # Test that providing operators alone works fine (should not throw)
    @test_nowarn Options(; operators)
end

@testitem "Test operators stored globally" begin
    using SymbolicRegression
    using DynamicExpressions.OperatorEnumConstructionModule: LATEST_OPERATORS

    operators = OperatorEnum(1 => [sin, cos], 2 => [+, -, *], 3 => [fma], 5 => [max])
    options = Options(; operators)

    @test LATEST_OPERATORS[] == operators
end

@testitem "Test with_max_degree_from_context" begin
    using SymbolicRegression

    operators = OperatorEnum(1 => (sin, cos), 2 => (+, *, -))
    @test Options(; node_type=GraphNode, operators).node_type <: GraphNode{<:Any,2}
    @test Options(; node_type=Node, operators).node_type <: Node{<:Any,2}

    operators = OperatorEnum(1 => (sin, cos), 2 => ())
    @test Options(; node_type=Node{<:Any,1}, operators).node_type <: Node{<:Any,1}

    @test Options().node_type <: Node{<:Any,2}

    operators = OperatorEnum(1 => (sin, cos), 2 => (+, *, -), 3 => (fma, max))
    options = Options(; operators)
    @test options.node_type <: Node{<:Any,3}
    @test options.op_constraints ==
        ([-1, -1], [(-1, -1), (-1, -1), (-1, -1)], [(-1, -1, -1), (-1, -1, -1)])
    @test options.nops == (2, 3, 2)
end

@testitem "Test operator appears in multiple degrees error" begin
    using SymbolicRegression

    operators = OperatorEnum(1 => (+, sin), 2 => (+, *))  # + appears in both degrees

    @test_throws(
        "Operator + appears in multiple degrees. You can't use nested constraints.",
        Options(; operators, nested_constraints=[(+) => [(+) => 0]])
    )

    @test_throws(
        "Operator + appears in multiple degrees. You can't use constraints.",
        Options(; operators, constraints=[(+) => -1])
    )
end

@testitem "Test build_constraints with pre-processed vector format" begin
    using SymbolicRegression
    using SymbolicRegression.ConfigModule.OptionsModule: build_constraints
    using DynamicExpressions: OperatorEnum

    operators = OperatorEnum(1 => (sin, cos), 2 => (+, *, -), 5 => (max,))

    constraints_processed = (
        [-1, -1], [(-1, -1), (-1, -1), (-1, -1)], nothing, nothing, [(-1, -1, -1, -1, -1)]
    )

    result = build_constraints(;
        constraints=constraints_processed, operators_by_degree=operators.ops
    )

    # Verify the result matches expected format (fills empty slots with default values)
    @test result == (
        [-1, -1],
        [(-1, -1), (-1, -1), (-1, -1)],
        NTuple{3,Int}[],
        NTuple{4,Int}[],
        [(-1, -1, -1, -1, -1)],
    )
end
