@testitem "Basic @template_spec macro functionality" tags = [:part1, :template_macro] begin
    using SymbolicRegression
    using DynamicExpressions: OperatorEnum, Node

    # Test basic parameter/expression handling
    expr_spec = @template_spec(
        parameters = (p1=10, p2=10, p3=1), expressions = (f, g)
    ) do x1, x2, class
        return p1[class] * x1^2 + f(x1, x2, p2[class]) - g(p3[1] * x1)
    end

    # Verify spec structure
    @test expr_spec.structure isa TemplateStructure{(:f, :g),(:p1, :p2, :p3)}

    # Test expression construction through spec
    operators = OperatorEnum(; binary_operators=(+, *, /, -), unary_operators=(sin, cos))
    variable_names = ["x1", "x2", "class"]
    x1 = ComposableExpression(Node{Float64}(; feature=1); operators, variable_names)

    expr = TemplateExpression(
        (; f=x1, g=x1);
        expr_spec.structure,
        operators,
        variable_names,
        parameters=(p1=zeros(10), p2=zeros(10), p3=zeros(1)),
    )

    # Validate structure
    @test expr isa TemplateExpression
    @test keys(get_contents(expr)) == (:f, :g)
    @test get_metadata(expr).parameters.p1 == zeros(10)

    # Test evaluation
    X = [1.0 2.0 1.0]'
    result = expr(X)
    @test result isa Vector{Float64}
end

@testitem "Template macro error handling" tags = [:part1, :template_macro] begin
    using SymbolicRegression
    using SymbolicRegression.TemplateExpressionMacroModule: template_spec

    # Test missing expressions
    @test_throws(
        ArgumentError("expressions must be specified"),
        template_spec(:((x,) -> f(x)), :(parameters = (p1=1,)))
    )

    # Test invalid parameters format
    @test_throws(
        "parameters must be a tuple of parameter name-size pairs like `(p1=10, p2=10, p3=1)`",
        template_spec(:((x,) -> f(x)), :(parameters = 1), :(expressions = (f,)))
    )

    @test_throws(
        "parameters must be a tuple of parameter name-size pairs like `(p1=10, p2=10, p3=1)`",
        template_spec(:((x,) -> f(x)), :(parameters = (1, 2)), :(expressions = (f,)))
    )

    # Test invalid expressions format
    @test_throws(
        "expressions must be a tuple of the form `(f, g, ...)`",
        template_spec(:((x,) -> f(x)), :(parameters = (p1=1,)), :(expressions = f))
    )

    # Test invalid function format
    @test_throws(
        ArgumentError("Expected a do block"),
        template_spec(:(f(x)), :(parameters = (p1=1,)), :(expressions = (f,)))
    )

    @test_throws(
        ArgumentError("Expected a tuple of arguments for the function arguments"),
        template_spec(:(x -> f(x)), :(parameters = (p1=1,)), :(expressions = (f,)))
    )

    # Test missing expressions (but having parameters)
    @test_throws(
        ArgumentError("expressions must be specified"),
        template_spec(:((x,) -> f(x)), :(parameters = (p1=1,)))
    )

    # Test invalid expressions format without parameters
    @test_throws(
        "expressions must be a tuple of the form `(f, g, ...)`",
        template_spec(:((x,) -> f(x)), :(expressions = f))
    )
end

@testitem "Template macro with complex structure" tags = [:part3, :template_macro] begin
    using SymbolicRegression
    using DynamicExpressions: OperatorEnum, Node
    using Test

    # Multi-output template with parameter reuse
    template = @template_spec(
        parameters = (coeff=5,), expressions = (base, modifier)
    ) do x, y, class
        base_val = base(x, coeff[class])
        modified = modifier(y, coeff[class])
        return coeff[class] * x * base_val + modified
    end

    # Verify structure
    @test template.structure isa TemplateStructure{(:base, :modifier),(:coeff,)}
    @test template.structure.num_parameters == (coeff=5,)

    # Test multi-output evaluation
    operators = OperatorEnum(; binary_operators=[+, *], unary_operators=[sin])
    x = ComposableExpression(
        Node{Float64}(; feature=1); operators, variable_names=["t", "x", "y"]
    )
    expr = TemplateExpression(
        (; base=x, modifier=x);
        structure=template.structure,
        operators,
        variable_names=["t", "x", "y"],
        parameters=(coeff=ones(5),),
    )

    X = [2.0 3.0 4.0]'
    result = expr(X)
    @test result[1] ≈ 7.0
end

@testitem "Template macro without parameters" tags = [:part1, :template_macro] begin
    using SymbolicRegression
    using DynamicExpressions: OperatorEnum, Node

    # Test template without parameters
    expr_spec = @template_spec(expressions = (f, g)) do x1, x2
        return x1^2 + f(x1, x2) - g(x1)
    end

    # Verify spec structure
    @test expr_spec.structure isa TemplateStructure{(:f, :g),()}

    # Test expression construction through spec
    operators = OperatorEnum(; binary_operators=(+, *, /, -), unary_operators=(sin, cos))
    variable_names = ["x1", "x2"]
    x1 = ComposableExpression(Node{Float64}(; feature=1); operators, variable_names)

    expr = TemplateExpression(
        (; f=x1, g=x1); expr_spec.structure, operators, variable_names
    )

    # Validate structure
    @test expr isa TemplateExpression
    @test keys(get_contents(expr)) == (:f, :g)
    @test !hasfield(typeof(get_metadata(expr)), :parameters)

    # Test evaluation
    X = [1.0 2.0]'
    result = expr(X)
    @test result isa Vector{Float64}
end

@testitem "Template macro additional error handling" tags = [:part1, :template_macro] begin
    using SymbolicRegression
    using SymbolicRegression.TemplateExpressionMacroModule: template_spec

    # Test setting parameters keyword twice
    @test_throws(
        "cannot set `parameters` keyword twice",
        template_spec(
            :((x,) -> f(x)),
            :(parameters = (p1=1,)),
            :(parameters = (p2=1,)),
            :(expressions = (f,)),
        )
    )

    # Test setting expressions keyword twice
    @test_throws(
        "cannot set `expressions` keyword twice",
        template_spec(:((x,) -> f(x)), :(expressions = (f,)), :(expressions = (g,)))
    )

    # Test unrecognized keyword
    @test_throws(
        "unrecognized keyword invalid_keyword",
        template_spec(:((x,) -> f(x)), :(invalid_keyword = 1), :(expressions = (f,)))
    )

    # Test positional args after first
    @test_throws(
        "no positional args accepted after the first",
        template_spec(:((x,) -> f(x)), :(expressions = (f,)), :extra_arg)
    )
end
