@testitem "template expression parameter mutation" tags = [:part3] begin
    using SymbolicRegression
    using SymbolicRegression.MutationFunctionsModule: mutate_constant
    using Random: MersenneTwister
    using DynamicExpressions: get_metadata

    # Create a template structure with parameters
    struct_with_params = TemplateStructure{(:f, :g),(:p1, :p2)}(
        ((; f, g), (; p1, p2), (x1, x2, x3)) -> f(x1, x2) * p1[1] + g(x3) * p2[1];
        num_parameters=(; p1=2, p2=3),  # p1 has 2 params, p2 has 3 params
    )

    # Set up options with the template spec
    options = Options(;
        binary_operators=(+, *, /, -),
        unary_operators=(sin, cos),
        expression_spec=TemplateExpressionSpec(; structure=struct_with_params),
    )
    operators = options.operators
    variable_names = ["x1", "x2", "x3"]

    # Create base expressions
    x1 = ComposableExpression(Node{Float64}(; feature=1); operators, variable_names)
    x2 = ComposableExpression(Node{Float64}(; feature=2); operators, variable_names)

    # Create template expression with parameters
    expr = TemplateExpression(
        (; f=x1, g=x2);
        structure=struct_with_params,
        operators=operators,
        parameters=(; p1=[1.0, 2.0], p2=[3.0, 4.0, 5.0]),
    )

    # Test mutation
    rng = MersenneTwister(0)
    temperature = 1.0

    # Store original parameter values
    original_p1 = copy(get_metadata(expr).parameters.p1._data)
    original_p2 = copy(get_metadata(expr).parameters.p2._data)

    # Test multiple mutations to ensure both parameter vectors can be mutated
    param_changed = [false, false]
    for _ in 1:50  # Run enough times to ensure we hit both parameter vectors
        mutated_expr = mutate_constant(copy(expr), temperature, options, rng)
        new_p1 = get_metadata(mutated_expr).parameters.p1._data
        new_p2 = get_metadata(mutated_expr).parameters.p2._data

        if !all(new_p1 .≈ original_p1)
            param_changed[1] = true
        end
        if !all(new_p2 .≈ original_p2)
            param_changed[2] = true
        end
        if all(param_changed)
            break
        end
    end

    # Verify both parameter vectors were mutated at some point
    @test all(param_changed)

    # Test single mutation to verify mutation behavior
    mutated_expr = mutate_constant(copy(expr), temperature, options, rng)

    # Get the mutated parameters
    new_p1 = get_metadata(mutated_expr).parameters.p1._data
    new_p2 = get_metadata(mutated_expr).parameters.p2._data

    # Verify exactly one parameter was changed
    @test any(new_p1 .!= original_p1) ⊻ any(new_p2 .!= original_p2)
end
