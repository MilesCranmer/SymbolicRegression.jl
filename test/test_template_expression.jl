@testitem "Basic utility of the TemplateExpression" tags = [:part3] begin
    using SymbolicRegression
    using SymbolicRegression: SymbolicRegression as SR
    using SymbolicRegression.CheckConstraintsModule: check_constraints
    using DynamicExpressions: OperatorEnum

    options = Options(; binary_operators=(+, *, /, -), unary_operators=(sin, cos))
    operators = options.operators
    variable_names = (i -> "x$i").(1:3)
    x1, x2, x3 =
        (i -> Expression(Node(Float64; feature=i); operators, variable_names)).(1:3)

    # For combining expressions to a single expression:
    my_structure(nt::NamedTuple{<:Any,<:Tuple{Vararg{<:AbstractString}}}) =
        "sin($(nt.f)) + $(nt.g)^2"
    my_structure(nt::NamedTuple{<:Any,<:Tuple{Vararg{<:AbstractVector}}}) =
        @. sin(nt.f) + nt.g^2
    my_structure(nt::NamedTuple{<:Any,<:Tuple{Vararg{<:Expression}}}) =
        sin(nt.f) + nt.g * nt.g

    variable_mapping = (; f=[1, 2], g=[3])
    st_expr = TemplateExpression(
        (; f=x1, g=cos(x3));
        structure=my_structure,
        operators,
        variable_names,
        variable_mapping,
    )
    @test string_tree(st_expr) == "sin(x1) + cos(x3)^2"
    operators = OperatorEnum(; binary_operators=(+, *, /, -), unary_operators=(cos, sin))

    # Changing the operators will change how the expression is interpreted for
    # parts that are already evaluated:
    @test string_tree(st_expr, operators) == "sin(x1) + sin(x3)^2"

    # We can evaluate with this too:
    cX = [1.0 2.0; 3.0 4.0; 5.0 6.0]
    out, completed = st_expr(cX)
    @test completed
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
    my_structure(nt::NamedTuple{<:Any,<:Tuple{Vararg{<:AbstractString}}}) =
        "sin($(nt.f)) + $(nt.g)^2"
    my_structure(nt::NamedTuple{<:Any,<:Tuple{Vararg{<:AbstractVector}}}) =
        @. sin(nt.f) + nt.g^2
    my_structure(nt::NamedTuple{<:Any,<:Tuple{Vararg{<:Expression}}}) =
        sin(nt.f) + nt.g * nt.g

    variable_mapping = (; f=[1, 2], g=[3])
    st_expr = TemplateExpression(
        (; f=x1, g=x3); structure=my_structure, operators, variable_names, variable_mapping
    )
    @test Interfaces.test(ExpressionInterface, TemplateExpression, [st_expr])
end
@testitem "Utilising TemplateExpression to build vector expressions" tags = [:part3] begin
    using SymbolicRegression
    using Random: rand

    # Define the structure function, which returns a tuple:
    function my_structure(nt::NamedTuple{<:Any,<:Tuple{Vararg{<:AbstractString}}})
        return "( $(nt.f) + $(nt.g1), $(nt.f) + $(nt.g2), $(nt.f) + $(nt.g3) )"
    end
    function my_structure(nt::NamedTuple{<:Any,<:Tuple{Vararg{<:AbstractVector}}})
        return map(
            i -> (nt.f[i] + nt.g1[i], nt.f[i] + nt.g2[i], nt.f[i] + nt.g3[i]),
            eachindex(nt.f),
        )
    end

    # Set up operators and variable names
    options = Options(; binary_operators=(+, *, /, -), unary_operators=(sin, cos))
    variable_names = (i -> "x$i").(1:3)

    # Create expressions
    x1, x2, x3 =
        (i -> Expression(Node(Float64; feature=i); options.operators, variable_names)).(1:3)

    # Test with vector inputs:
    nt_vector = NamedTuple{(:f, :g1, :g2, :g3)}((1:3, 4:6, 7:9, 10:12))
    @test my_structure(nt_vector) == [(5, 8, 11), (7, 10, 13), (9, 12, 15)]

    # And string inputs:
    nt_string = NamedTuple{(:f, :g1, :g2, :g3)}(("x1", "x2", "x3", "x2"))
    @test my_structure(nt_string) == "( x1 + x2, x1 + x3, x1 + x2 )"

    # Now, using TemplateExpression:
    variable_mapping = (; f=[1, 2], g1=[3], g2=[3], g3=[3])
    st_expr = TemplateExpression(
        (; f=x1, g1=x2, g2=x3, g3=x2);
        structure=my_structure,
        options.operators,
        variable_names,
        variable_mapping,
    )
    @test string_tree(st_expr) == "( x1 + x2, x1 + x3, x1 + x2 )"

    # We can directly call it:
    cX = [1.0 2.0; 3.0 4.0; 5.0 6.0]
    out, completed = st_expr(cX)
    @test completed
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

    my_structure(nt) = nt.f

    variable_mapping = (; f=[1, 2], g1=[3], g2=[3], g3=[3])

    st_expr = TemplateExpression(
        (; f=x1, g1=x3, g2=x3, g3=x3);
        structure=my_structure,
        operators,
        variable_names,
        variable_mapping,
    )

    @test st_expr isa TemplateExpression
    @test get_operators(st_expr) == operators
    @test get_variable_names(st_expr) == variable_names
    @test get_metadata(st_expr).structure == my_structure
end
@testitem "Integration Test with fit! and Performance Check" tags = [:part3] begin
    using SymbolicRegression
    using Random: rand
    using MLJBase: machine, fit!, report

    options = Options(; binary_operators=(+, *, /, -), unary_operators=(sin, cos))
    operators = options.operators
    variable_names = (i -> "x$i").(1:3)
    x1, x2, x3 =
        (i -> Expression(Node(Float64; feature=i); operators, variable_names)).(1:3)

    variable_mapping = (; f=[1, 2], g1=[3], g2=[3])

    function my_structure(nt::NamedTuple{<:Any,<:Tuple{Vararg{<:AbstractString}}})
        return "( $(nt.f) + $(nt.g1), $(nt.f) + $(nt.g2) )"
    end
    function my_structure(nt::NamedTuple{<:Any,<:Tuple{Vararg{<:AbstractVector}}})
        return map(i -> (nt.f[i] + nt.g1[i], nt.f[i] + nt.g2[i]), eachindex(nt.f))
    end

    st_expr = TemplateExpression(
        (; f=x1, g1=x3, g2=x3);
        structure=my_structure,
        operators,
        variable_names,
        variable_mapping,
    )

    model = SRRegressor(;
        binary_operators=(+, *),
        unary_operators=(sin,),
        maxsize=15,
        expression_type=TemplateExpression,
        expression_options=(; structure=my_structure, variable_mapping),
        elementwise_loss=((x1, x2), (y1, y2)) -> (y1 - x1)^2 + (y2 - x2)^2,
        early_stop_condition=(loss, complexity) -> loss < 1e-5 && complexity <= 7,
    )

    X = rand(100, 3) .* 10
    y = [(sin(X[i, 1]) + X[i, 3]^2, sin(X[i, 1]) + X[i, 3]) for i in eachindex(axes(X, 1))]

    dataset = Dataset(X', y)

    mach = machine(model, X, y)
    fit!(mach)

    # Check the performance of the model
    r = report(mach)
    idx = r.best_idx
    best_loss = r.losses[idx]

    @test best_loss < 1e-5

    # Check the expression is split up correctly:
    best_expr = r.equations[idx]
    best_f = get_contents(best_expr).f
    best_g1 = get_contents(best_expr).g1
    best_g2 = get_contents(best_expr).g2

    @test best_f(X') ≈ (@. sin(X[:, 1]))
    @test best_g1(X') ≈ (@. X[:, 3] * X[:, 3])
    @test best_g2(X') ≈ (@. X[:, 3])
end
