@testitem "TemplateExpressionSpec supports custom inner expression types" begin
    using DynamicExpressions:
        DynamicExpressions,
        AbstractExpressionNode,
        AbstractOperatorEnum,
        EvalContext,
        Metadata,
        Node,
        OperatorEnum,
        get_contents,
        get_metadata
    using Random: AbstractRNG, MersenneTwister
    using SymbolicRegression
    using SymbolicRegression: AbstractComposableExpression
    using SymbolicRegression.ExpressionsModule.ExpressionBuilderModule: create_expression
    using SymbolicRegression.EvolutionModule.MutationFunctionsModule: crossover_trees

    struct WrappedExpression{T,N<:AbstractExpressionNode{T},D} <:
           AbstractComposableExpression{T,N}
        tree::N
        metadata::Metadata{D}
    end

    function WrappedExpression(
        tree::AbstractExpressionNode{T};
        operators::Union{AbstractOperatorEnum,Nothing}=nothing,
        variable_names::Union{AbstractVector{<:AbstractString},Nothing}=nothing,
        eval_context::Union{EvalContext,Nothing}=nothing,
        tag::Symbol=:wrapped,
        local_parameter::Vector{T}=T[0],
    ) where {T}
        return WrappedExpression(
            tree,
            Metadata((; operators, variable_names, eval_context, tag, local_parameter)),
        )
    end

    DynamicExpressions.constructorof(::Type{<:WrappedExpression}) = WrappedExpression
    local_parameter(ex::WrappedExpression) = only(get_metadata(ex).local_parameter)
    function Base.copy(ex::WrappedExpression)
        metadata = get_metadata(ex)
        variable_names = metadata.variable_names
        eval_context = metadata.eval_context
        copied_eval_context = isnothing(eval_context) ? nothing : copy(eval_context)
        return WrappedExpression(
            copy(get_contents(ex));
            operators=metadata.operators,
            variable_names,
            eval_context=copied_eval_context,
            tag=metadata.tag,
            local_parameter=copy(metadata.local_parameter),
        )
    end
    crossover_calls = Ref(0)
    function SymbolicRegression.EvolutionModule.MutationFunctionsModule.crossover_trees(
        ex1::WrappedExpression{T}, ex2::WrappedExpression{T}, rng::AbstractRNG
    ) where {T}
        crossover_calls[] += 1
        tree1, tree2 = crossover_trees(get_contents(ex1), get_contents(ex2), rng)
        return (
            DynamicExpressions.with_contents(ex1, tree1),
            DynamicExpressions.with_contents(ex2, tree2),
        )
    end

    operators = OperatorEnum(; unary_operators=(cos,), binary_operators=(+,))
    structure = TemplateStructure{(:f,)}(((; f), (x,)) -> f(x); num_features=(; f=1))
    spec = TemplateExpressionSpec(;
        structure,
        inner_expression_type=WrappedExpression,
        inner_expression_options=(; tag=:custom_inner),
    )

    parsed = parse_expression((; f="#1 + 1.0"); expression_spec=spec, operators)
    parsed_inner = first(values(get_contents(parsed)))
    @test parsed_inner isa WrappedExpression
    @test get_metadata(parsed_inner).tag == :custom_inner
    parameter_structure = TemplateStructure{(:f,),(:p,)}(
        ((; f), (; p), (x,)) -> f(x) + p[1]; num_features=(; f=1), num_parameters=(; p=1)
    )
    parameter_spec = TemplateExpressionSpec(;
        structure=parameter_structure,
        inner_expression_type=WrappedExpression,
        inner_expression_options=(; tag=:custom_inner),
    )
    parsed_with_parameters = parse_expression(
        (; f="#1", p=[2.0]); expression_spec=parameter_spec, operators
    )
    @test get_metadata(parsed_with_parameters).parameters.p == [2.0]
    @test get_metadata(parsed_with_parameters.trees.f).tag == :custom_inner
    copied_inner = copy(parsed_inner)
    @test copied_inner isa WrappedExpression
    @test typeof(copied_inner) === typeof(parsed_inner)
    @test get_metadata(copied_inner).tag == :custom_inner
    @test get_contents(copied_inner) !== get_contents(parsed_inner)
    get_metadata(parsed_inner).local_parameter[1] = 3.0
    get_metadata(copied_inner).local_parameter[1] = 9.0
    @test local_parameter(parsed_inner) == 3.0

    copied = copy(parsed)
    @test typeof(copied) === typeof(parsed)
    copied_template_inner = first(values(get_contents(copied)))
    @test copied_template_inner isa WrappedExpression
    @test typeof(copied_template_inner) === typeof(parsed_inner)
    @test get_metadata(copied_template_inner).tag == :custom_inner
    @test get_contents(copied_template_inner) !== get_contents(parsed_inner)

    parent1 = parse_expression((; f="1.0"); expression_spec=spec, operators)
    parent2 = parse_expression((; f="2.0"); expression_spec=spec, operators)
    parent_inners = map(parent -> first(values(get_contents(parent))), (parent1, parent2))
    get_metadata(parent_inners[1]).local_parameter[1] = 11.0
    get_metadata(parent_inners[2]).local_parameter[1] = 22.0
    crossover_calls[] = 0
    child1, child2 = crossover_trees(parent1, parent2, MersenneTwister(0))
    child_inners = map(child -> first(values(get_contents(child))), (child1, child2))
    @test typeof(child1) === typeof(parent1)
    @test typeof(child2) === typeof(parent2)
    @test crossover_calls[] == 1
    @test all(inner -> inner isa WrappedExpression, child_inners)
    @test map(typeof, child_inners) == map(typeof, parent_inners)
    @test all(inner -> get_metadata(inner).tag == :custom_inner, child_inners)
    @test map(local_parameter, child_inners) == (11.0, 22.0)
    @test get_metadata(child_inners[1]).local_parameter !==
        get_metadata(parent_inners[1]).local_parameter
    @test get_metadata(child_inners[2]).local_parameter !==
        get_metadata(parent_inners[2]).local_parameter
    @test get_contents(child_inners[1]).val == 2.0
    @test get_contents(child_inners[2]).val == 1.0
    for child_inner in child_inners, parent_inner in parent_inners
        @test get_contents(child_inner) !== get_contents(parent_inner)
    end
    @test get_contents(child_inners[1]) !== get_contents(child_inners[2])
    get_metadata(child_inners[1]).local_parameter[1] = 111.0
    get_metadata(child_inners[2]).local_parameter[1] = 222.0
    @test map(local_parameter, parent_inners) == (11.0, 22.0)

    two_structure = TemplateStructure{(:f, :g)}(
        ((; f, g), (x,)) -> f(x) + g(x); num_features=(; f=1, g=1)
    )
    two_spec = TemplateExpressionSpec(;
        structure=two_structure,
        inner_expression_type=WrappedExpression,
        inner_expression_options=(; tag=:custom_inner),
    )
    two_parent1 = parse_expression(
        (; f="1.0", g="3.0"); expression_spec=two_spec, operators
    )
    two_parent2 = parse_expression(
        (; f="2.0", g="4.0"); expression_spec=two_spec, operators
    )
    two_parents = (two_parent1, two_parent2)
    for (parent_index, parent) in enumerate(two_parents)
        for (inner_index, inner) in enumerate(values(get_contents(parent)))
            get_metadata(inner).local_parameter[1] = 10 * parent_index + inner_index
        end
    end
    crossover_calls[] = 0
    two_child1, two_child2 = crossover_trees(two_parent1, two_parent2, MersenneTwister(3))
    two_children = (two_child1, two_child2)
    @test crossover_calls[] == 1
    for child in two_children
        for child_inner in values(get_contents(child))
            for parent in two_parents, parent_inner in values(get_contents(parent))
                @test get_metadata(child_inner).local_parameter !==
                    get_metadata(parent_inner).local_parameter
            end
        end
    end
    for inner1 in values(get_contents(two_child1))
        for inner2 in values(get_contents(two_child2))
            @test get_metadata(inner1).local_parameter !==
                get_metadata(inner2).local_parameter
        end
    end

    dataset = Dataset(randn(Float32, 1, 8), randn(Float32, 8))
    options = Options(; operators, expression_spec=spec, tournament_selection_n=5)
    created = create_expression(Node{Float32}(; val=0.0f0), options, dataset)
    created_inner = first(values(get_contents(created)))
    @test created_inner isa WrappedExpression
    @test get_metadata(created_inner).tag == :custom_inner
end

@testitem "TemplateExpressionSpec initializes template parameters" begin
    using Random: AbstractRNG
    using DynamicExpressions: Node, OperatorEnum, get_metadata
    using SymbolicRegression
    using SymbolicRegression: ParamVector
    using SymbolicRegression.ExpressionsModule.ExpressionBuilderModule:
        create_expression, strip_metadata

    operators = OperatorEnum(; binary_operators=(+,))
    structure = TemplateStructure{(:f,),(:weights, :bias)}(
        ((; f), (; weights, bias), (x,)) -> f(x) + weights[1] + bias[1];
        num_features=(; f=1),
        num_parameters=(; weights=2, bias=1),
    )
    initializer_calls = Ref(0)
    parameter_initializer = function (rng, T, num_parameters)
        @test rng isa AbstractRNG
        @test T === Float32
        @test num_parameters == (; weights=2, bias=1)
        initializer_calls[] += 1
        return (; bias=T[-1], weights=T[2, 3])
    end
    spec = TemplateExpressionSpec(; structure, parameter_initializer)
    @test spec.parameter_initializer === parameter_initializer
    dataset = Dataset(randn(Float32, 1, 8), randn(Float32, 8))
    options = Options(; operators, expression_spec=spec, tournament_selection_n=5)

    created = create_expression(Node{Float32}(; val=0.0f0), options, dataset)
    created_parameters = get_metadata(created).parameters
    @test initializer_calls[] == 1
    @test created_parameters.weights isa ParamVector{Float32}
    @test created_parameters.bias isa ParamVector{Float32}
    @test collect(created_parameters.weights) == Float32[2, 3]
    @test collect(created_parameters.bias) == Float32[-1]

    copied = strip_metadata(created, options, dataset)
    copied_parameters = get_metadata(copied).parameters
    @test initializer_calls[] == 1
    @test copied_parameters == created_parameters
    @test copied_parameters.weights !== created_parameters.weights
    @test copied_parameters.bias !== created_parameters.bias

    default_spec = TemplateExpressionSpec(structure)
    @test default_spec.parameter_initializer === nothing
    default_options = Options(;
        operators, expression_spec=default_spec, tournament_selection_n=5
    )
    default_created = create_expression(
        Node{Float32}(; val=0.0f0), default_options, dataset
    )
    default_parameters = get_metadata(default_created).parameters
    @test default_parameters.weights isa ParamVector{Float32}
    @test default_parameters.bias isa ParamVector{Float32}
    @test length(default_parameters.weights) == 2
    @test length(default_parameters.bias) == 1
end

@testitem "TemplateExpressionSpec validates initialized template parameters" begin
    using DynamicExpressions: Node, OperatorEnum
    using SymbolicRegression
    using SymbolicRegression.ExpressionsModule.ExpressionBuilderModule: create_expression

    operators = OperatorEnum(; binary_operators=(+,))
    structure = TemplateStructure{(:f,),(:weights, :bias)}(
        ((; f), (; weights, bias), (x,)) -> f(x) + weights[1] + bias[1];
        num_features=(; f=1),
        num_parameters=(; weights=2, bias=1),
    )
    dataset = Dataset(randn(Float32, 1, 8), randn(Float32, 8))

    wrong_keys = TemplateExpressionSpec(;
        structure, parameter_initializer=(_, T, _) -> (; weights=T[2, 3], offset=T[-1])
    )
    wrong_keys_options = Options(;
        operators, expression_spec=wrong_keys, tournament_selection_n=5
    )
    @test_throws ArgumentError create_expression(
        Node{Float32}(; val=0.0f0), wrong_keys_options, dataset
    )

    wrong_length = TemplateExpressionSpec(;
        structure, parameter_initializer=(_, T, _) -> (; weights=T[2], bias=T[-1])
    )
    wrong_length_options = Options(;
        operators, expression_spec=wrong_length, tournament_selection_n=5
    )
    @test_throws DimensionMismatch create_expression(
        Node{Float32}(; val=0.0f0), wrong_length_options, dataset
    )
end
