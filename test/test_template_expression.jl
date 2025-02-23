@testitem "Test ParamVector setindex!" tags = [:part1] begin
    using SymbolicRegression: ParamVector

    pv = ParamVector([1.0, 2.0])
    @test_throws "ParamVector should be treated as read-only" pv[1] = 3.0
end

@testitem "Test deprecated num_features warning" tags = [:part1] begin
    using SymbolicRegression
    using Test: @test_warn

    structure = TemplateStructure{(:f,)}(
        ((; f), (x,)) -> f(x),
        (; f=1);  # Deprecated way
    )
    @test structure.num_features == (; f=1)
end

@testitem "Test invalid combiner functions" tags = [:part1] begin
    using SymbolicRegression

    # Test error for invalid combiner function (no params)
    @test_throws(
        "Your template structure's `combine` function must accept\n\t1. A `NamedTuple` of `ComposableExpression`s",
        TemplateStructure{(:f,)}(((; f),) -> f())  # Missing second argument
    )

    # Test error for invalid combiner function (with params)
    @test_throws(
        "Your template structure's `combine` function must accept\n\t1. A `NamedTuple` of `ComposableExpression`s",
        TemplateStructure{(:f,),(:p,)}(
            ((; f),) -> f();  # Missing params and data arguments
            num_parameters=(p=1,),
        )
    )
end

@testitem "Test get_variable_names" tags = [:part1] begin
    using SymbolicRegression
    using SymbolicRegression: Node
    using DynamicExpressions: OperatorEnum, get_variable_names

    operators = Options().operators
    variable_names = ["x1", "x2"]
    x1 = ComposableExpression(Node{Float64}(; feature=1); operators)
    structure = TemplateStructure{(:f,)}(((; f), (x,)) -> f(x))
    expr = TemplateExpression((; f=x1); structure, operators, variable_names)

    @test get_variable_names(expr, nothing) == variable_names
    @test get_variable_names(expr, ["z1", "z2"]) == ["z1", "z2"]
end

@testitem "Test parameter handling in scalar constants" tags = [:part2] begin
    using SymbolicRegression
    using SymbolicRegression: Node
    using DynamicExpressions: get_metadata, get_scalar_constants, set_scalar_constants!

    operators = Options().operators
    variable_names = ["x1", "x2"]
    x1 = ComposableExpression(Node{Float64}(; feature=1); operators, variable_names)

    structure_with_params = TemplateStructure{(:f,),(:p,)}(
        ((; f), (; p), (x,)) -> f(x) + p[1]; num_parameters=(p=2,)
    )
    expr_with_params = TemplateExpression(
        (; f=x1); structure=structure_with_params, operators, parameters=(p=[1.0, 2.0],)
    )

    # Test get_scalar_constants and set_scalar_constants!
    constants, refs = get_scalar_constants(expr_with_params)
    new_constants = copy(constants)
    new_constants[(end - 1):end] .= [3.0, 4.0]  # Modify parameter values
    set_scalar_constants!(expr_with_params, new_constants, refs)
    @test get_metadata(expr_with_params).parameters.p._data == [3.0, 4.0]
end

@testitem "Test get_tree with parameters error" tags = [:part2] begin
    using SymbolicRegression
    using SymbolicRegression: Node
    using DynamicExpressions: get_tree

    operators = Options().operators
    variable_names = ["x1", "x2"]
    x1 = ComposableExpression(Node{Float64}(; feature=1); operators, variable_names)

    structure_with_params = TemplateStructure{(:f,),(:p,)}(
        ((; f), (; p), (x,)) -> f(x) + p[1]; num_parameters=(p=2,)
    )
    expr_with_params = TemplateExpression(
        (; f=x1); structure=structure_with_params, operators, parameters=(p=[1.0, 2.0],)
    )

    @test_throws(
        "`get_tree` is not implemented for TemplateExpression with parameters",
        get_tree(expr_with_params)
    )
end

@testitem "Test interface for TemplateExpression" tags = [:part2] begin
    using SymbolicRegression
    using SymbolicRegression: TemplateExpression
    using DynamicExpressions.InterfacesModule: Interfaces, ExpressionInterface
    using DynamicExpressions: OperatorEnum

    operators = OperatorEnum(; binary_operators=(+, *, /, -), unary_operators=(sin, cos))
    variable_names = (i -> "x$i").(1:3)
    x1 = ComposableExpression(Node(Float64; feature=1); operators, variable_names)
    x2 = ComposableExpression(Node(Float64; feature=2); operators, variable_names)

    structure = TemplateStructure{(:f, :g)}(
        ((; f, g), (x1, x2)) -> f(f(f(x1))) - f(g(x2, x1))
    )
    @test structure.num_features == (; f=1, g=2)

    expr = TemplateExpression((; f=x1, g=x2 * x2); structure, operators, variable_names)

    @test String(string_tree(expr)) == "f = #1; g = #2 * #2"
    @test String(string_tree(expr; pretty=true)) == "╭ f = #1\n╰ g = #2 * #2"
    @test string_tree(get_tree(expr), operators) == "x1 - (x1 * x1)"
    @test Interfaces.test(ExpressionInterface, TemplateExpression, [expr])
end

@testitem "Printing and evaluation of TemplateExpression" tags = [:part2] begin
    using SymbolicRegression

    structure = TemplateStructure{(:f, :g)}(
        ((; f, g), (x1, x2, x3)) -> sin(f(x1, x2)) + g(x3)^2
    )
    operators = Options().operators
    variable_names = ["x1", "x2", "x3"]

    x1, x2, x3 = [
        ComposableExpression(Node{Float64}(; feature=i); operators, variable_names) for
        i in 1:3
    ]
    f = x1 * x2
    g = x1
    expr = TemplateExpression((; f, g); structure, operators, variable_names)

    # Default printing strategy:
    @test String(string_tree(expr)) == "f = #1 * #2; g = #1"

    x1_val = randn(5)
    x2_val = randn(5)

    # The feature indicates the index passed as argument:
    @test x1(x1_val) ≈ x1_val
    @test x2(x1_val, x2_val) ≈ x2_val
    @test x1(x2_val) ≈ x2_val

    # Composing expressions and then calling:
    @test String(string_tree((x1 * x2)(x3, x3))) == "x3 * x3"

    # Can evaluate with `sin` even though it's not in the allowed operators!
    X = randn(3, 5)
    x1_val = X[1, :]
    x2_val = X[2, :]
    x3_val = X[3, :]
    @test expr(X) ≈ @. sin(x1_val * x2_val) + x3_val^2

    # This is even though `g` is defined on `x1` only:
    @test g(x3_val) ≈ x3_val
end

@testitem "Test nothing return and type inference for TemplateExpression" tags = [:part2] begin
    using SymbolicRegression
    using Test: @inferred

    # Create a template expression that divides by x1
    structure = TemplateStructure{(:f,)}(((; f), (x1, x2)) -> 1.0 + f(x1) / x1)
    operators = Options(; binary_operators=(+, -, *, /)).operators
    variable_names = ["x1", "x2"]

    x1 = ComposableExpression(Node{Float64}(; feature=1); operators, variable_names)
    x2 = ComposableExpression(Node{Float64}(; feature=2); operators, variable_names)
    expr = TemplateExpression((; f=x1); structure, operators, variable_names)

    # Test division by zero returns nothing
    X = [0.0 1.0]'
    @test expr(X) === nothing

    # Test type inference
    X_good = [1.0 2.0]'
    @test @inferred(Union{Nothing,Vector{Float64}}, expr(X_good)) ≈ [2.0]

    # Test type inference with ValidVector input
    x1_val = ValidVector([1.0], true)
    x2_val = ValidVector([2.0], true)
    @test @inferred(ValidVector{Vector{Float64}}, x1(x1_val, x2_val)).x ≈ [1.0]

    x2_val_false = ValidVector([2.0], false)
    @test @inferred(x1(x1_val, x2_val_false)).valid == false
end

@testitem "Test compatibility with power laws" tags = [:part3] begin
    using SymbolicRegression
    using DynamicExpressions: OperatorEnum

    operators = OperatorEnum(; binary_operators=(+, -, *, /, ^))
    variable_names = ["x1", "x2"]
    x1 = ComposableExpression(Node{Float64}(; feature=1); operators, variable_names)
    x2 = ComposableExpression(Node{Float64}(; feature=2); operators, variable_names)

    structure = TemplateStructure{(:f,)}(((; f), (x1, x2)) -> f(x1)^f(x2))
    expr = TemplateExpression((; f=x1); structure, operators, variable_names)

    # There shouldn't be an error when we evaluate with invalid
    # expressions, even though the source of the NaN comes from the structure
    # function itself:
    X = -rand(2, 32)
    @test expr(X) === nothing
end

@testitem "Test constraints checking in TemplateExpression" tags = [:part2] begin
    using SymbolicRegression
    using SymbolicRegression: CheckConstraintsModule as CC

    # Create a template expression with nested exponentials
    options = Options(;
        binary_operators=(+, -, *, /),
        unary_operators=(exp,),
        nested_constraints=[exp => [exp => 1]], # Only allow one nested exp
    )
    operators = options.operators
    variable_names = ["x1", "x2"]

    # Create a valid inner expression
    x1 = ComposableExpression(Node{Float64}(; feature=1); operators, variable_names)
    valid_expr = exp(x1)  # One exp is ok

    # Create an invalid inner expression with too many nested exp
    invalid_expr = exp(exp(exp(x1)))
    # Three nested exp's violates constraint

    @test CC.check_constraints(valid_expr, options, 20)
    @test !CC.check_constraints(invalid_expr, options, 20)
end

@testitem "Test feature constraints in TemplateExpression" tags = [:part1] begin
    using SymbolicRegression
    using DynamicExpressions: Node

    operators = Options(; binary_operators=(+, -, *, /)).operators
    variable_names = ["x1", "x2", "x3"]

    # Create a structure where f only gets access to x1, x2
    # and g only gets access to x3
    structure = TemplateStructure{(:f, :g)}(((; f, g), (x1, x2, x3)) -> f(x1, x2) + g(x3))

    x1 = ComposableExpression(Node{Float64}(; feature=1); operators, variable_names)
    x2 = ComposableExpression(Node{Float64}(; feature=2); operators, variable_names)
    x3 = ComposableExpression(Node{Float64}(; feature=3); operators, variable_names)

    # Test valid case - each function only uses allowed features
    valid_f = x1 + x2
    valid_g = x1
    valid_template = TemplateExpression(
        (; f=valid_f, g=valid_g); structure, operators, variable_names
    )
    @test valid_template([1.0 2.0 3.0]') ≈ [6.0]  # (1 + 2) + 3

    # Test invalid case - f tries to use x3 which it shouldn't have access to
    invalid_f = x1 + x3
    invalid_template = TemplateExpression(
        (; f=invalid_f, g=valid_g); structure, operators, variable_names
    )
    @test invalid_template([1.0 2.0 3.0]') === nothing

    # Test invalid case - g tries to use x2 which it shouldn't have access to
    invalid_g = x2
    invalid_template2 = TemplateExpression(
        (; f=valid_f, g=invalid_g); structure, operators, variable_names
    )
    @test invalid_template2([1.0 2.0 3.0]') === nothing
end

@testitem "Test invalid structure" tags = [:part3] begin
    using SymbolicRegression

    operators = Options(; binary_operators=(+, -, *, /)).operators
    variable_names = ["x1", "x2", "x3"]

    x1 = ComposableExpression(Node{Float64}(; feature=1); operators, variable_names)
    x2 = ComposableExpression(Node{Float64}(; feature=2); operators, variable_names)
    x3 = ComposableExpression(Node{Float64}(; feature=3); operators, variable_names)

    @test_throws ArgumentError TemplateStructure{(:f,)}(
        ((; f), (x1, x2)) -> f(x1) + f(x1, x2)
    )
    @test_throws "Inconsistent number of arguments passed to f" TemplateStructure{(:f,)}(
        ((; f), (x1, x2)) -> f(x1) + f(x1, x2)
    )

    @test_throws ArgumentError TemplateStructure{(:f, :g)}(((; f, g), (x1, x2)) -> f(x1))
    @test_throws "Failed to infer number of features used by (:g,)" TemplateStructure{(
        :f, :g
    )}(
        ((; f, g), (x1, x2)) -> f(x1)
    )
end

@testitem "Test argument-less template structure" tags = [:part2] begin
    using SymbolicRegression
    using DynamicExpressions: OperatorEnum

    operators = OperatorEnum(; binary_operators=(+, *, /, -), unary_operators=(sin, cos))
    variable_names = ["x1", "x2"]
    x1 = ComposableExpression(Node{Float64}(; feature=1); operators, variable_names)
    x2 = ComposableExpression(Node{Float64}(; feature=2); operators, variable_names)
    c1 = ComposableExpression(Node{Float64}(; val=3.0); operators, variable_names)

    # We can evaluate an expression with no arguments:
    @test c1() == 3.0
    @test typeof(c1()) === Float64

    # Create a structure where f takes no arguments and g takes two
    structure = TemplateStructure{(:f, :g)}(((; f, g), (x1, x2)) -> f() + g(x1, x2))

    @test structure.num_features == (; f=0, g=2)

    X = [1.0 2.0]'
    expr = TemplateExpression((; f=c1, g=x1 + x2); structure, operators, variable_names)
    @test expr(X) ≈ [6.0]  # 3 + (1 + 2)
end

@testitem "Test TemplateExpression with differential operator" tags = [:part3] begin
    using SymbolicRegression
    using SymbolicRegression: D
    using DynamicExpressions: OperatorEnum

    operators = OperatorEnum(; binary_operators=(+, -, *, /), unary_operators=(sin, cos))
    variable_names = ["x1", "x2"]
    x1 = ComposableExpression(Node{Float64}(; feature=1); operators, variable_names)
    x2 = ComposableExpression(Node{Float64}(; feature=2); operators, variable_names)
    x3 = ComposableExpression(Node{Float64}(; feature=3); operators, variable_names)

    structure = TemplateStructure{(:f, :g)}(
        ((; f, g), (x1, x2, x3)) -> f(x1) + D(g, 1)(x2, x3)
    )
    expr = TemplateExpression(
        (; f=x1, g=cos(x1 - x2) + 2.5 * x1); structure, operators, variable_names
    )
    # Truth: x1 - sin(x2 - x3) + 2.5
    X = stack(([1.0, 2.0], [3.0, 4.0], [5.0, 6.0]); dims=1)
    @test expr(X) ≈ [1.0, 2.0] .- sin.([3.0, 4.0] .- [5.0, 6.0]) .+ 2.5
end

@testitem "Test literal_pow with ValidVector" tags = [:part2] begin
    using SymbolicRegression: ValidVector

    # Test with valid data
    x = ValidVector([2.0, 3.0, 4.0], true)

    # Test literal_pow with different powers
    @test (x^2).x ≈ [4.0, 9.0, 16.0]
    @test (x^3).x ≈ [8.0, 27.0, 64.0]

    # And explicitly
    @test Base.literal_pow(^, x, Val(2)).x ≈ [4.0, 9.0, 16.0]
    @test Base.literal_pow(^, x, Val(3)).x ≈ [8.0, 27.0, 64.0]

    # Test with invalid data
    invalid_x = ValidVector([2.0, 3.0, 4.0], false)
    @test (invalid_x^2).valid == false
    @test Base.literal_pow(^, invalid_x, Val(2)).valid == false
end

@testitem "Test nan behavior with argument-less expressions" tags = [:part2] begin
    using SymbolicRegression
    using DynamicExpressions: OperatorEnum, Node

    operators = OperatorEnum(; binary_operators=(+, *, /, -), unary_operators=(sin, cos))
    variable_names = ["x1", "x2"]

    # Test with floating point
    c1 = ComposableExpression(Node{Float64}(; val=3.0); operators, variable_names)
    invalid_const = (c1 / c1 - 1) / (c1 / c1 - 1)  # Creates 0/0
    @test isnan(invalid_const())
    @test typeof(invalid_const()) === Float64

    # Test with integer constant
    c2 = ComposableExpression(Node{Int}(; val=0); operators, variable_names)
    @test c2() == 0
    @test typeof(c2()) === Int
end

@testitem "Test higher-order derivatives of safe_log with DynamicDiff" tags = [:part3] begin
    using SymbolicRegression
    using SymbolicRegression: D, safe_log, ValidVector
    using DynamicExpressions: OperatorEnum
    using ForwardDiff: DimensionMismatch

    operators = OperatorEnum(; binary_operators=(+, -, *, /), unary_operators=(safe_log,))
    variable_names = ["x"]
    x = ComposableExpression(Node{Float64}(; feature=1); operators, variable_names)

    # Test first and second derivatives of log(x)
    structure = TemplateStructure{(:f,)}(
        ((; f), (x,)) ->
            ValidVector([(f(x).x[1], D(f, 1)(x).x[1], D(D(f, 1), 1)(x).x[1])], true),
    )
    expr = TemplateExpression((; f=log(x)); structure, operators, variable_names)

    # Test at x = 2.0 where log(x) is well-defined
    X = [2.0]'
    result = only(expr(X))
    @test result !== nothing
    @test result[1] == log(2.0)  # function value
    @test result[2] == 1 / 2.0     # first derivative
    @test result[3] == -1 / 4.0    # second derivative

    # We handle invalid ranges gracefully:
    X_invalid = [-1.0]'
    result = only(expr(X_invalid))
    @test result !== nothing
    @test isnan(result[1])
    @test result[2] == 0.0
    @test result[3] == 0.0

    # Eventually we want to support complex numbers:
    X_complex = [-1.0 - 1.0im]'
    @test_throws DimensionMismatch expr(X_complex)
end

@testitem "Test eval_options with turbo mode" tags = [:part3] begin
    using SymbolicRegression
    using DynamicExpressions: OperatorEnum, EvalOptions
    using LoopVectorization: LoopVectorization

    operators = OperatorEnum(; binary_operators=(+, *, /, -), unary_operators=(sin, cos))
    variable_names = ["x1", "x2"]
    eval_options = EvalOptions(; turbo=true)

    # Create expressions with turbo mode enabled
    x1 = ComposableExpression(
        Node{Float64}(; feature=1); operators, variable_names, eval_options
    )
    f = x1 + x1
    g = x1
    structure = TemplateStructure{(:f, :g)}(((; f, g), (x1, x2)) -> f(x1) * g(x2)^2)
    expr = TemplateExpression((; f=x1 + x1, g=x1); structure, operators, variable_names)

    n = 32
    X = randn(2, n)
    result = expr(X)
    @test result ≈ @. (X[1, :] + X[1, :]) * (X[2, :] * X[2, :])
    # n.b., we can't actually test whether turbo is used here,
    # this is basically just a smoke test
end

@testitem "loss_function_expression with expressions and templates" tags = [:part3] begin
    using SymbolicRegression
    using SymbolicRegression: AbstractOptions
    using SymbolicRegression.LossFunctionsModule: eval_loss

    # Define realistic loss functions for testing
    function tree_loss(
        tree::AbstractExpressionNode, dataset::Dataset, options::AbstractOptions
    )
        output, completed = eval_tree_array(tree, dataset.X, options)
        !completed && return Inf
        return sum(abs2, output .- dataset.y) / length(dataset.y)
    end

    function expr_loss(ex::AbstractExpression, dataset::Dataset, options::AbstractOptions)
        output, completed = eval_tree_array(ex, dataset.X, options)
        !completed && return Inf
        return sum(abs2, output .- dataset.y) / length(dataset.y)
    end

    function expr_loss_batched(
        ex::AbstractExpression, dataset::Dataset, options::AbstractOptions, idx
    )
        if idx === nothing
            return expr_loss(ex, dataset, options)
        end
        output, completed = eval_tree_array(ex, dataset.X[:, idx], options)
        !completed && return Inf
        return sum(abs2, output .- dataset.y[idx]) / length(idx)
    end

    # Test they can't be used together
    @test_throws "You cannot specify more than one" Options(;
        binary_operators=[+, *], loss_function=tree_loss, loss_function_expression=expr_loss
    )

    # Test regular expression loss
    options = Options(; binary_operators=[+, *], loss_function_expression=expr_loss)

    # Create a simple dataset where y = 2x₁ + x₂²
    X = Float32[1.0 2.0 3.0; 2.0 3.0 4.0; 0.0 0.0 0.0]  # 3x3 array
    y = Float32[2.0 * X[1, i] + X[2, i]^2 for i in 1:3]  # y = 2x₁ + x₂²
    d = Dataset(X, y)

    # Create an expression that should give a constant 1.0
    ex = Expression(Node{Float32}(; val=1.0); operators=options.operators)
    expected_loss = sum(abs2, ones(Float32, 3) .- y) / 3  # MSE for constant 1.0
    @test eval_loss(ex, d, options) ≈ expected_loss

    # Create an expression that matches the true function: 2x₁ + x₂²
    ex = Expression(
        2.0f0 * Node{Float32}(; feature=1) +
        Node{Float32}(; feature=2) * Node{Float32}(; feature=2);
        operators=options.operators,
    )
    @test expr_loss(ex, d, options) < 1e-10

    # Test that it errors with a tree instead of expression
    @test_throws AssertionError eval_loss(Node{Float32}(; val=1.0), d, options)

    # Test batched version
    options = Options(;
        binary_operators=[+, *],
        loss_function_expression=expr_loss_batched,
        batching=true,
        batch_size=5,
    )

    @test eval_loss(ex, d, options) < 1e-10

    # Test with subset of data:
    idx = [1, 2]
    @test eval_loss(ex, d, options; idx=idx) < 1e-10

    # Test with template expressions
    template = @template_spec(expressions = (f,), parameters = (p=2,)) do x
        f(x) + sum(p)
    end

    # Create template expression with parameters
    options = Options(;
        binary_operators=[+, *],
        expression_spec=template,
        loss_function_expression=expr_loss,
    )
    x = ComposableExpression(Node{Float32}(; feature=1); operators=options.operators)
    template_ex = TemplateExpression(
        (; f=x);
        structure=template.structure,
        operators=options.operators,
        parameters=(; p=[1.0f0, 2.0f0]),
    )

    # Test template expression works with loss_function_expression
    # Template evaluates to: x₁ + (1.0 + 2.0)
    # Expected output: [4.0, 5.0, 6.0]
    expected_template_loss = sum(abs2, [4.0f0, 5.0f0, 6.0f0] .- y) / 3
    loss = eval_loss(template_ex, d, options)
    @test loss ≈ expected_template_loss

    # Test batched version with template expression
    options = Options(;
        binary_operators=[+, *],
        expression_spec=template,
        loss_function_expression=expr_loss_batched,
        batching=true,
        batch_size=5,
    )
    # Test with subset of data:
    idx = [1, 2]
    expected_batch_loss = sum(abs2, [4.0f0, 5.0f0] .- y[idx]) / 2

    loss_batch = eval_loss(template_ex, d, options; idx=idx)
    @test loss_batch ≈ expected_batch_loss
end

@testitem "New batching syntax" tags = [:part3] begin
    using SymbolicRegression
    using SymbolicRegression: Dataset, batch
    using SymbolicRegression: SubDataset, eval_loss

    function expr_loss(ex::AbstractExpression, dataset::Dataset, options::Options)
        @test dataset isa SubDataset
        output, completed = eval_tree_array(ex, dataset.X, options)
        !completed && return Inf
        return sum(abs2, output .- dataset.y) / length(dataset.y)
    end

    template = @template_spec(expressions = (f,), parameters = (p=2,)) do x
        f(x) + sum(p)
    end

    options = Options(;
        binary_operators=[+, *],
        expression_spec=template,
        loss_function_expression=expr_loss,
        batching=true,
        batch_size=2,
    )

    x = ComposableExpression(Node{Float32}(; feature=1); operators=options.operators)

    X = Float32[1.0 2.0 3.0; 2.0 3.0 4.0; 0.0 0.0 0.0]  # 3x3 array
    y = Float32[2.0 * X[1, i] + X[2, i]^2 for i in 1:3]  # y = 2x₁ + x₂²
    d = Dataset(X, y)
    batched_d = batch(d, [1, 2])
    # For indices 1,2:
    # x₁ values are [1.0, 2.0]
    # x₂ values are [2.0, 3.0]
    # y = 2x₁ + x₂² gives [6.0, 13.0]
    template_ex = TemplateExpression(
        (; f=x);
        structure=template.structure,
        operators=options.operators,
        parameters=(; p=[1.0f0, 2.0f0]),
    )
    # Our expression is f(x) + sum(p) where f(x)=x and p=[1,2]
    # So output is [4.0, 5.0] for the two points
    # Loss is mean squared error
    expected_batch_loss = sum(abs2, [4.0f0, 5.0f0] .- [6.0f0, 13.0f0]) / 2
    loss_batch = eval_loss(template_ex, batched_d, options)
    @test loss_batch ≈ expected_batch_loss
end

@testitem "warning for loss_function with TemplateExpression" begin
    using SymbolicRegression

    @test_warn(
        "You are using `loss_function` with",
        Options(;
            binary_operators=[+, *],
            loss_function=Returns(1.0),
            expression_type=TemplateExpression,
        )
    )
end
