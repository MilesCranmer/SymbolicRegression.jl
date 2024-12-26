@testitem "creation & parameter counts" begin
    using SymbolicRegression

    # A structure that expects 1 subexpression + param vector of length 2
    struct1 = TemplateStructure{(:f,)}(((; f), (x,), p) -> f(x) + sum(p); num_parameters=2)

    @test struct1.num_features == (; f=1)
    @test struct1.num_parameters == 2

    subex = ComposableExpression(Node{Float64}(; feature=1); operators=Options().operators)

    expr_correct = TemplateExpression(
        (; f=subex); structure=struct1, operators=Options().operators, parameters=[1.0, 2.0]
    )
    @test expr_correct isa TemplateExpression
end

@testitem "error conditions" begin
    using SymbolicRegression

    struct_bad = TemplateStructure{(:f,)}(
        ((; f), (x,), p) -> f(x) + sum(p); num_parameters=2
    )

    variable_names = ["x"]

    # Error for missing parameters
    @test_throws "Expected `parameters` to be provided" TemplateExpression(
        (;
            f=ComposableExpression(
                Node{Float64}(; feature=1); operators=Options().operators, variable_names
            )
        );
        structure=struct_bad,
        operators=Options().operators,
        variable_names,
    )

    # Error for wrong parameter vector length
    @test_throws "Expected `parameters` to have length 2, got 1" TemplateExpression(
        (;
            f=ComposableExpression(
                Node{Float64}(; feature=1); operators=Options().operators
            )
        );
        structure=struct_bad,
        operators=Options().operators,
        variable_names=["x"],
        parameters=[1.0],
    )

    # Now, for structure *not* having parameters, but using parameters:
    structure = TemplateStructure{(:f,)}(((; f), (x,)) -> f(x))
    @test_throws "Expected `parameters` to be `nothing` for `structure.num_parameters=nothing`" TemplateExpression(
        (;
            f=ComposableExpression(
                Node{Float64}(; feature=1); operators=Options().operators
            )
        );
        structure=structure,
        operators=Options().operators,
        variable_names=["x"],
        parameters=[1.0],
    )
end

@testitem "basic evaluation" begin
    using SymbolicRegression

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

@testitem "indexed evaluation" begin
    using SymbolicRegression
    using Random: MersenneTwister
    using MLJBase: matrix

    # Here, we assert that we can index the parameters,
    # and this creates another ValidVector
    function fnc_struct_indexed((; f, g), (x, y, i), params)
        p1 = params[i]
        p2 = params[i + 3]
        @test p1 isa ValidVector
        @test p2 isa ValidVector
        return f(x) * p1 - g(y) * p2
    end
    struct_indexed = TemplateStructure{(:f, :g)}(fnc_struct_indexed; num_parameters=6)

    operators =
        Options(; binary_operators=[*, +, -, /], unary_operators=[cos, exp]).operators
    x1, x2, x3 = map(i -> ComposableExpression(Node{Float64}(; feature=i); operators), 1:3)
    f = cos(x1 * 3.1 - 0.5)
    g = exp(1.0 - x1 * x1)
    # ^Note: because `g` is passed y, this is equivalent to exp(1.0 - y * y)!
    rng = MersenneTwister(0)
    x = rand(rng, 10)
    y = rand(rng, 10)
    i = rand(rng, 1:3, 10)
    params = rand(rng, 6)
    y_truth = [
        (cos(x[j] * 3.1 - 0.5) * params[i[j]] - exp(1.0 - y[j] * y[j]) * params[i[j] + 3])
        for j in 1:10
    ]
    X = matrix((; x, y, i); transpose=true)
    expr_indexed = TemplateExpression(
        (; f, g); structure=struct_indexed, operators, parameters=params
    )
    @test expr_indexed(X) ≈ y_truth
end

@testitem "parameters get mutated" begin
    using SymbolicRegression
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
    options = Options()
    old_params = copy(get_metadata(expr_mut).parameters._data)
    local mutated_expr = copy(expr_mut)
    local param_changed = false

    # Force enough trials to see if param vector changes:
    for _ in 1:50
        mutated_expr = mutate_constant(mutated_expr, 1.0, options, rng)
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
