@testitem "Basic utility of the TemplateExpression" tags = [:part3] begin
    using SymbolicRegression
    using SymbolicRegression: SymbolicRegression as SR
    using SymbolicRegression.CheckConstraintsModule: check_constraints
    using DynamicExpressions: OperatorEnum

    options = Options(; binary_operators=(+, *, /, -), unary_operators=(sin, cos))
    operators = options.operators
    variable_names = ["x1", "x2", "x3"]
    x1, x2, x3 =
        (i -> Expression(Node(Float64; feature=i); operators, variable_names)).(1:3)

    # For combining expressions to a single expression:
    structure = TemplateStructure(;
        combine=e -> sin(e.f) + e.g * e.g,
        combine_vectors=e -> (@. sin(e.f) + e.g^2),
        combine_strings=e -> "sin($(e.f)) + $(e.g)^2",
        variable_constraints=(; f=[1, 2], g=[3]),
    )

    @test structure isa TemplateStructure{(:f, :g)}

    st_expr = TemplateExpression((; f=x1, g=cos(x3)); structure, operators, variable_names)
    @test string_tree(st_expr) == "sin(x1) + cos(x3)^2"
    operators = OperatorEnum(; binary_operators=(+, *, /, -), unary_operators=(cos, sin))

    # Changing the operators will change how the expression is interpreted for
    # parts that are already evaluated:
    @test string_tree(st_expr, operators) == "sin(x1) + sin(x3)^2"

    # We can evaluate with this too:
    cX = [1.0 2.0; 3.0 4.0; 5.0 6.0]
    out = st_expr(cX)
    @test out ≈ [sin(1.0) + cos(5.0)^2, sin(2.0) + cos(6.0)^2]

    # And also check the contents:
    @test check_constraints(st_expr, options, 100)

    # We can see that violating the constraints will cause a violation:
    new_expr = with_contents(st_expr, (; f=x3, g=cos(x3)))
    @test !check_constraints(new_expr, options, 100)
    new_expr = with_contents(st_expr, (; f=x2, g=cos(x3)))
    @test check_constraints(new_expr, options, 100)
    new_expr = with_contents(st_expr, (; f=x2, g=cos(x1)))
    @test !check_constraints(new_expr, options, 100)

    # Checks the size of each individual expression:
    new_expr = with_contents(st_expr, (; f=x2, g=cos(x3)))

    @test compute_complexity(new_expr, options) == 3
    @test check_constraints(new_expr, options, 3)
    @test !check_constraints(new_expr, options, 2)
end
@testitem "Expression interface" tags = [:part3] begin
    using SymbolicRegression
    using DynamicExpressions: OperatorEnum
    using DynamicExpressions.InterfacesModule: Interfaces, ExpressionInterface

    operators = OperatorEnum(; binary_operators=(+, *, /, -), unary_operators=(sin, cos))
    variable_names = (i -> "x$i").(1:3)
    x1, x2, x3 =
        (i -> Expression(Node(Float64; feature=i); operators, variable_names)).(1:3)

    # For combining expressions to a single expression:
    structure = TemplateStructure{(:f, :g)}(;
        combine=e -> sin(e.f) + e.g * e.g,
        combine_strings=e -> "sin($(e.f)) + $(e.g)^2",
        combine_vectors=e -> (@. sin(e.f) + e.g^2),
        variable_constraints=(; f=[1, 2], g=[3]),
    )
    st_expr = TemplateExpression((; f=x1, g=x3); structure, operators, variable_names)
    @test Interfaces.test(ExpressionInterface, TemplateExpression, [st_expr])
end
@testitem "Utilising TemplateExpression to build vector expressions" tags = [:part3] begin
    using SymbolicRegression
    using Random: rand

    # Define the structure function, which returns a tuple:
    structure = TemplateStructure{(:f, :g1, :g2, :g3)}(;
        combine_strings=e -> "( $(e.f) + $(e.g1), $(e.f) + $(e.g2), $(e.f) + $(e.g3) )",
        combine_vectors=e ->
            map((f, g1, g2, g3) -> (f + g1, f + g2, f + g3), e.f, e.g1, e.g2, e.g3),
    )

    # Set up operators and variable names
    options = Options(; binary_operators=(+, *, /, -), unary_operators=(sin, cos))
    variable_names = (i -> "x$i").(1:3)

    # Create expressions
    x1, x2, x3 =
        (i -> Expression(Node(Float64; feature=i); options.operators, variable_names)).(1:3)

    # Test with vector inputs:
    nt_vector = NamedTuple{(:f, :g1, :g2, :g3)}((1:3, 4:6, 7:9, 10:12))
    @test structure(nt_vector) == [(5, 8, 11), (7, 10, 13), (9, 12, 15)]

    # And string inputs:
    nt_string = NamedTuple{(:f, :g1, :g2, :g3)}(("x1", "x2", "x3", "x2"))
    @test structure(nt_string) == "( x1 + x2, x1 + x3, x1 + x2 )"

    # Now, using TemplateExpression:
    st_expr = TemplateExpression(
        (; f=x1, g1=x2, g2=x3, g3=x2); structure, options.operators, variable_names
    )
    @test string_tree(st_expr) == "( x1 + x2, x1 + x3, x1 + x2 )"

    # We can directly call it:
    cX = [1.0 2.0; 3.0 4.0; 5.0 6.0]
    out = st_expr(cX)
    @test out == [(1 + 3, 1 + 5, 1 + 3), (2 + 4, 2 + 6, 2 + 4)]
end
@testitem "TemplateExpression getters" tags = [:part3] begin
    using SymbolicRegression
    using DynamicExpressions: get_operators, get_variable_names

    operators =
        Options(; binary_operators=(+, *, /, -), unary_operators=(sin, cos)).operators
    variable_names = (i -> "x$i").(1:3)
    x1, x2, x3 =
        (i -> Expression(Node(Float64; feature=i); operators, variable_names)).(1:3)

    structure = TemplateStructure(;
        combine=e -> e.f, variable_constraints=(; f=[1, 2], g1=[3], g2=[3], g3=[3])
    )

    st_expr = TemplateExpression(
        (; f=x1, g1=x3, g2=x3, g3=x3); structure, operators, variable_names
    )

    @test st_expr isa TemplateExpression
    @test get_operators(st_expr) == operators
    @test get_variable_names(st_expr) == variable_names
    @test get_metadata(st_expr).structure == structure
end
@testitem "Integration Test with fit! and Performance Check" tags = [:part3] begin
    include("../examples/template_expression.jl")
end
@testitem "TemplateExpression with only combine function" tags = [:part3] begin
    using SymbolicRegression
    using SymbolicRegression.TemplateExpressionModule:
        can_combine_vectors, can_combine, get_function_keys
    using SymbolicRegression.InterfaceDynamicExpressionsModule: expected_array_type
    using DynamicExpressions: constructorof

    # Set up basic operators and variables
    options = Options(; binary_operators=(+, *, /, -), unary_operators=(sin, cos))
    operators = options.operators
    variable_names = ["x1", "x2", "x3"]
    x1, x2, x3 =
        (i -> Expression(Node(Float64; feature=i); operators, variable_names)).(1:3)

    # Create a TemplateStructure with only combine (no combine_vectors)
    structure = TemplateStructure(;
        combine=e -> sin(e.f) + e.g * e.g,  # Only define combine
        variable_constraints=(; f=[1, 2], g=[3]),
    )

    # Create the TemplateExpression
    st_expr = TemplateExpression((; f=x1, g=cos(x3)); structure, operators, variable_names)

    @test constructorof(typeof(st_expr)) === TemplateExpression
    @test get_function_keys(st_expr) == (:f, :g)

    # Test evaluation
    cX = [1.0 2.0; 3.0 4.0; 5.0 6.0]
    out = st_expr(cX)
    out_2, complete = eval_tree_array(st_expr, cX)

    # The expression should evaluate by first combining to a single expression,
    # then evaluating that expression
    expected = sin.(cX[1, :]) .+ cos.(cX[3, :]) .^ 2
    @test out ≈ expected

    @test complete
    @test out_2 ≈ expected

    # Verify that can_combine_vectors is false but can_combine is true
    @test !can_combine_vectors(st_expr)
    @test can_combine(st_expr)

    @test expected_array_type(cX, typeof(st_expr)) === Any

    @test string_tree(st_expr) == "sin(x1) + (cos(x3) * cos(x3))"
end
@testitem "TemplateExpression with data in combine_vectors" tags = [:part3] begin
    using SymbolicRegression

    options = Options(; binary_operators=(+, *, /, -), unary_operators=(sin, cos, exp))
    operators = options.operators
    variable_names = ["x1", "x2", "x3"]
    x1, x2, x3 =
        (i -> Expression(Node(Float64; feature=i); operators, variable_names)).(1:3)
    f = exp(2.5 * x3)
    g = x1
    structure = TemplateStructure(;
        combine_vectors=(e, X) -> e.f .+ X[2, :], variable_constraints=(; f=[3], g=[1])
    )
    st_expr = TemplateExpression((; f, g); structure, operators, variable_names)
    X = randn(3, 100)
    @test st_expr(X) ≈ @. exp(2.5 * X[3, :]) + X[2, :]
end
@testitem "TemplateStructure constructors" tags = [:part3] begin
    using SymbolicRegression

    operators = Options(; binary_operators=(+, *, /, -)).operators
    variable_names = ["x1", "x2"]

    # Create simple expressions with constant values
    f = Expression(Node(Float64; val=1.0); operators, variable_names)
    g = Expression(Node(Float64; val=2.0); operators, variable_names)

    # Test TemplateStructure{K}(combine; kws...)
    st1 = TemplateStructure{(:f, :g)}(e -> e.f + e.g)
    @test st1.combine((; f, g)) == f + g

    # Test TemplateStructure(combine; kws...)
    st2 = TemplateStructure(e -> e.f + e.g; variable_constraints=(; f=[1], g=[2]))
    @test st2.combine((; f, g)) == f + g

    # Test error when no K or variable_constraints provided
    @test_throws ArgumentError TemplateStructure(e -> e.f + e.g)
    @test_throws ArgumentError(
        "If `variable_constraints` is not provided, " *
        "you must initialize `TemplateStructure` with " *
        "`TemplateStructure{K}(...)`, for tuple of symbols `K`.",
    ) TemplateStructure(e -> e.f + e.g)
end
