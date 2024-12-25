@testitem "Parametric TemplateExpressions - Creation & Parameter Counts" begin
    using SymbolicRegression: TemplateStructure, TemplateExpression, ComposableExpression
    using SymbolicRegression: Node, Options

    # A structure that expects 1 subexpression + param vector of length 2
    struct1 = TemplateStructure{(:f,)}(((; f), (x,), p) -> f(x) + sum(p); num_parameters=2)

    # By default (no explicit num_features), we get (f=1,) for a single-argument subexpression
    @test struct1.num_features == (f=1,)
    @test struct1.num_parameters == 2

    # Create a subexpression, specifying operators
    subex = ComposableExpression(Node{Float64}(; feature=1); operators=Options().operators)

    # Provide correct parameters
    expr_correct = TemplateExpression(
        (; f=subex);
        structure=struct1,
        operators=Options().operators,
        parameters=[1.0, 2.0],  # length 2
    )
    @test expr_correct isa TemplateExpression
end

@testitem "Parametric TemplateExpressions - Error Conditions" begin
    using SymbolicRegression: TemplateStructure, TemplateExpression, ComposableExpression
    using SymbolicRegression: Node, Options

    struct_bad = TemplateStructure{(:f,)}(
        ((; f), (x,), p) -> f(x) + sum(p); num_parameters=2
    )

    # Missing param vector => error
    @test_throws AssertionError TemplateExpression(
        (;
            f=ComposableExpression(
                Node{Float64}(; feature=1); operators=Options().operators
            )
        );
        structure=struct_bad,
        operators=Options().operators,
        variable_names=["x"],
        parameters=nothing,  # library expects length=2
    )

    # Wrong param vector length => error
    @test_throws AssertionError TemplateExpression(
        (;
            f=ComposableExpression(
                Node{Float64}(; feature=1); operators=Options().operators
            )
        );
        structure=struct_bad,
        operators=Options().operators,
        variable_names=["x"],
        parameters=[1.0],  # length=1, should be=2
    )
end

@testitem "Parametric TemplateExpressions - Basic Evaluation" begin
    using SymbolicRegression: TemplateStructure, TemplateExpression, ComposableExpression
    using SymbolicRegression: Node, Options

    # structure => f(x) + sum(params), with 2 parameters
    struct_eval = TemplateStructure{(:f,)}(
        ((; f), (x,), p) -> f(x) + sum(p); num_parameters=2
    )

    expr_eval = TemplateExpression(
        (;
            f=ComposableExpression(
                Node{Float64}(; feature=1); operators=Options().operators
            )
        );
        structure=struct_eval,
        operators=Options().operators,
        variable_names=["x"],
        parameters=[1.0, 2.0],
    )

    # We'll evaluate on a 1×2 matrix: 1 feature, 2 data points => shape: (1, 2)
    # x = [5.0, 6.0], so the expression should yield [ (5 + 3), (6 + 3) ] => [8, 9]
    X = [5.0 6.0]
    out = expr_eval(X)
    @test out ≈ [8.0, 9.0]
end

@testitem "Parametric TemplateExpressions - Mutation of Parameters" begin
    using SymbolicRegression: TemplateStructure, TemplateExpression, ComposableExpression
    using SymbolicRegression: Node, Options, get_metadata
    using SymbolicRegression.MutationFunctionsModule: mutate_constant
    using Random: MersenneTwister

    struct_mut = TemplateStructure{(:f,)}(
        ((; f), (x,), p) -> f(x) + sum(p); num_parameters=2
    )
    expr_mut = TemplateExpression(
        (;
            f=ComposableExpression(
                Node{Float64}(; feature=1); operators=Options().operators
            )
        );
        structure=struct_mut,
        operators=Options().operators,
        variable_names=["x"],
        parameters=[1.0, 2.0],
    )

    rng = MersenneTwister(0)
    old_params = copy(get_metadata(expr_mut).parameters._data)
    local mutated_expr = copy(expr_mut)
    local param_changed = false

    # Force enough trials to see if param vector changes:
    for _ in 1:50
        mutated_expr = mutate_constant(mutated_expr, 1.0, Options(), rng)
        new_params = get_metadata(mutated_expr).parameters._data
        if new_params != old_params
            param_changed = true
            break
        end
    end
    @test param_changed == true
end

@testitem "Parametric TemplateExpressions - Mini Search Example" begin
    using SymbolicRegression: TemplateStructure, TemplateExpression, ComposableExpression
    using SymbolicRegression: Node, SRRegressor, Dataset, Options
    using Random: MersenneTwister
    using MLJBase: machine, fit!, report, matrix

    # structure => f(x) + p[1], single param
    struct_search = TemplateStructure{(:f,)}(
        ((; f), (x,), p) -> f(x) + p[1]; num_parameters=1
    )

    rng = MersenneTwister(0)
    # We'll create 1 feature, 4 data points => shape: (1,4)
    # X[1,:] = [1,2,3,4], and y = 2*x + 3 => [5,7,9,11]
    X = (; x=[1.0, 2.0, 3.0, 4.0])
    y = [2 * xi + 3 for xi in X.x]  # => [5,7,9,11]

    model = SRRegressor(;
        niterations=20,
        binary_operators=(+, *, -),
        unary_operators=(),
        expression_type=TemplateExpression,
        expression_options=(; structure=struct_search),
    )

    mach = machine(model, X, y)
    fit!(mach)

    r = report(mach)
    best_expr = r.equations[r.best_idx]

    # Evaluate the best expression on the same X
    # => hopefully near [5, 7, 9, 11]
    pred = best_expr(matrix(X; transpose=true))
    @test length(pred) == 4
    @test pred !== nothing
end
