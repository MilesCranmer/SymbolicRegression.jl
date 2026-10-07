@testitem "template parameters route through the value interface" begin
    using SymbolicRegression
    using SymbolicRegression: ParamVector
    using SymbolicRegression.EvolutionModule.MutationFunctionsModule: mutate_constant
    using SymbolicRegression.ExpressionsModule.TemplateExpressionModule:
        _initialize_template_parameters
    using DynamicExpressions: DynamicExpressions as DE, get_metadata
    using Random: AbstractRNG, MersenneTwister

    struct Vec2
        x::Float64
        y::Float64
    end

    SymbolicRegression.init_value(::Type{Vec2}) = Vec2(0.0, 0.0)
    function SymbolicRegression.sample_value(rng::AbstractRNG, ::Type{Vec2}, _)
        return Vec2(randn(rng), randn(rng))
    end
    function SymbolicRegression.mutate_value(
        ::AbstractRNG, value::Vec2, _, ::ConstantMutation
    )
        return Vec2(value.x + 1, value.y)
    end
    DE.get_number_type(::Type{Vec2}) = Float64
    DE.count_scalar_constants(::Vec2) = 2
    function DE.pack_scalar_constants!(
        buffer::AbstractVector{<:Number}, idx::Int64, value::Vec2
    )
        buffer[idx] = value.x
        buffer[idx + 1] = value.y
        return idx + 2
    end
    function DE.unpack_scalar_constants(
        buffer::AbstractVector{<:Number}, idx::Int64, ::Vec2
    )
        return (idx + 2, Vec2(buffer[idx], buffer[idx + 1]))
    end

    structure = TemplateStructure{(:f,),(:p,)}(
        ((; f), (; p), (x,)) -> f(x); num_parameters=(; p=3)
    )
    options = Options(;
        binary_operators=(+,), expression_spec=TemplateExpressionSpec(; structure)
    )

    # Initialization samples with `sample_value` rather than `randn`:
    parameters = _initialize_template_parameters(
        MersenneTwister(0), Vec2, (; p=3), nothing, options
    )
    expected_rng = MersenneTwister(0)
    expected = [SymbolicRegression.sample_value(expected_rng, Vec2, options) for _ in 1:3]
    @test parameters.p isa ParamVector{Vec2}
    @test parameters.p._data == expected

    initial = [Vec2(1.0, 2.0), Vec2(3.0, 4.0), Vec2(5.0, 6.0)]
    ex = TemplateExpression(
        (; f=ComposableExpression(Node{Vec2}(; feature=1); options.operators));
        structure,
        options.operators,
        parameters=(; p=copy(initial)),
    )

    # Mutation goes through `mutate_value` rather than a numeric factor:
    mutated = mutate_constant(
        copy(ex), 1.0, options, ConstantMutation(), MersenneTwister(0)
    )
    mutated_data = get_metadata(mutated).parameters.p._data
    increments = [new.x - old.x for (new, old) in zip(mutated_data, initial)]
    @test all(in((0.0, 1.0)), increments)
    @test sum(increments) >= 1
    @test all(new.y == old.y for (new, old) in zip(mutated_data, initial))

    # Parameters are packed and unpacked as scalar constants:
    @test DE.count_scalar_constants(ex) == 6
    flat, refs = DE.get_scalar_constants(ex)
    @test flat == [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]
    @test eltype(flat) === Float64

    DE.set_scalar_constants!(ex, [10.0, 20.0, 30.0, 40.0, 50.0, 60.0], refs)
    @test get_metadata(ex).parameters.p._data ==
        [Vec2(10.0, 20.0), Vec2(30.0, 40.0), Vec2(50.0, 60.0)]
end
@testitem "template parser splits and validates flat parameter entries" begin
    using SymbolicRegression
    using DynamicExpressions: get_metadata

    structure = TemplateStructure{(:f,),(:p, :q)}(
        ((; f), (; p, q), (x,)) -> f(x) + p[1] + q[1];
        num_features=(; f=1),
        num_parameters=(; p=2, q=1),
    )
    operators = OperatorEnum(; binary_operators=(+,), unary_operators=())
    spec = TemplateExpressionSpec(; structure)

    expression_only = parse_expression((; f="#1"); expression_spec=spec, operators)
    @test get_metadata(expression_only).parameters.p == [0.0, 0.0]
    @test get_metadata(expression_only).parameters.q == [0.0]

    partial = parse_expression((; q=[3], f="#1"); expression_spec=spec, operators)
    @test get_metadata(partial).parameters.p == [0.0, 0.0]
    @test get_metadata(partial).parameters.q == [3.0]
    @test keys(get_metadata(partial).parameters) == (:p, :q)

    explicit = parse_expression(
        (; f="#1"); expression_spec=spec, operators, parameters=(; p=[1, 2],)
    )
    @test get_metadata(explicit).parameters.p == [1.0, 2.0]
    @test get_metadata(explicit).parameters.q == [0.0]

    @test_throws ArgumentError parse_expression(
        (; f="#1", unknown=[1.0]); expression_spec=spec, operators
    )
    @test_throws DimensionMismatch parse_expression(
        (; f="#1", p=[1.0]); expression_spec=spec, operators
    )
    @test_throws ArgumentError parse_expression(
        (; f="#1", p=1.0); expression_spec=spec, operators
    )
    @test_throws ArgumentError parse_expression(
        (; f="#1", p=[1.0, 2.0]); expression_spec=spec, operators, parameters=(; q=[3.0],)
    )
end

@testitem "template parser accepts custom value parameter vectors" begin
    using SymbolicRegression
    using DynamicExpressions: get_metadata

    struct GuessVec2
        x::Float64
        y::Float64
    end
    SymbolicRegression.init_value(::Type{GuessVec2}) = GuessVec2(0.0, 0.0)

    structure = TemplateStructure{(:f,),(:p,)}(
        ((; f), (; p), (x,)) -> f(x); num_features=(; f=1), num_parameters=(; p=2)
    )
    operators = OperatorEnum(; binary_operators=(), unary_operators=())
    options = Options(; operators, expression_spec=TemplateExpressionSpec(; structure))
    supplied = [GuessVec2(1.0, 2.0), GuessVec2(3.0, 4.0)]
    parsed = parse_expression(
        (; f="#1", p=supplied);
        options.expression_options,
        expression_type=TemplateExpression,
        node_type=Node{GuessVec2},
        operators,
    )

    @test get_metadata(parsed).parameters.p._data == supplied
    @test get_metadata(parsed).parameters.p._data !== supplied
end
