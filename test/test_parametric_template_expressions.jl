@testitem "creation & parameter counts" tags = [:part1] begin
    using SymbolicRegression

    # A structure that expects 1 subexpression + param vector of length 2
    struct1 = TemplateStructure{(:f,),(:p,)}(
        ((; f), (; p), (x,)) -> f(x) + sum(p); num_parameters=(; p=2)
    )

    @test struct1.num_features == (; f=1)
    @test struct1.num_parameters == (; p=2)

    subex = ComposableExpression(Node{Float64}(; feature=1); operators=Options().operators)

    expr_correct = TemplateExpression(
        (; f=subex);
        structure=struct1,
        operators=Options().operators,
        parameters=(; p=[1.0, 2.0]),
    )
    @test expr_correct isa TemplateExpression
end

@testitem "error conditions" tags = [:part2] begin
    using SymbolicRegression

    struct_bad = TemplateStructure{(:f,),(:p,)}(
        ((; f), (; p), (x,)) -> f(x) + sum(p); num_parameters=(; p=2)
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
    @test_throws "Expected `parameters.p` to have length 2, got 1" TemplateExpression(
        (;
            f=ComposableExpression(
                Node{Float64}(; feature=1); operators=Options().operators
            )
        );
        structure=struct_bad,
        operators=Options().operators,
        variable_names=["x"],
        parameters=(; p=[1.0]),
    )

    # Now, for structure *not* having parameters, but using parameters:
    structure = TemplateStructure{(:f,)}(((; f), (x,)) -> f(x))
    @test_throws "Expected `parameters` to not be specified for `structure.num_parameters=NamedTuple()`" TemplateExpression(
        (;
            f=ComposableExpression(
                Node{Float64}(; feature=1); operators=Options().operators
            )
        );
        structure=structure,
        operators=Options().operators,
        variable_names=["x"],
        parameters=(; p=[1.0]),
    )
end

@testitem "check_combiner_applicability errors" tags = [:part3] begin
    using SymbolicRegression

    bad_combiner1 = ((; f), x) -> f(x[1])
    @test_throws (
        "Your template structure's `combine` function must accept\n" *
        "\t1. A `NamedTuple` of `ComposableExpression`s (or `ArgumentRecorder`s)\n" *
        "\t2. A `NamedTuple` of `ParamVector`s\n" *
        "\t3. A tuple of `ValidVector`s"
    ) TemplateStructure{(:f,),(:p,)}(bad_combiner1; num_parameters=(; p=1))

    # Test error when combiner doesn't accept parameters when it should
    bad_combiner2 = ((; f), (; p), (x,)) -> f(x)
    @test_throws (
        "Your template structure's `combine` function must accept\n" *
        "\t1. A `NamedTuple` of `ComposableExpression`s (or `ArgumentRecorder`s)\n" *
        "\t2. A tuple of `ValidVector`s"
    ) TemplateStructure{(:f,)}(bad_combiner2)
end

@testitem "basic evaluation" tags = [:part1] begin
    using SymbolicRegression

    # structure => f(x) + sum(params), with 2 parameters
    struct_eval = TemplateStructure{(:f,),(:p,)}(
        ((; f), (; p), (x,)) -> f(x) + sum(p); num_parameters=(; p=2)
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
        parameters=(; p=[1.0, 2.0]),
    )

    # We'll evaluate on a 1×2 matrix: 1 feature, 2 data points => shape: (1, 2)
    # x = [5.0, 6.0], so the expression should yield [ (5 + 3), (6 + 3) ] => [8, 9]
    X = [5.0 6.0]
    out = expr_eval(X)
    @test out ≈ [8.0, 9.0]
end

@testitem "indexed evaluation" tags = [:part2] begin
    using SymbolicRegression
    using Random: MersenneTwister
    using MLJBase: matrix

    # Here, we assert that we can index the parameters,
    # and this creates another ValidVector
    function fnc_struct_indexed((; f, g), (; p), (x, y, i))
        p1 = p[i]
        p2 = p[i + 3]
        @test p1 isa ValidVector
        @test p2 isa ValidVector
        return f(x) * p1 - g(y) * p2
    end
    struct_indexed = TemplateStructure{(:f, :g),(:p,)}(
        fnc_struct_indexed; num_parameters=(; p=6)
    )

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
        (; f, g); structure=struct_indexed, operators, parameters=(; p=params)
    )
    @test expr_indexed(X) ≈ y_truth
end

@testitem "parameters get mutated" tags = [:part3] begin
    using SymbolicRegression
    using SymbolicRegression.MutationFunctionsModule: mutate_constant
    using Random: MersenneTwister

    struct_mut = TemplateStructure{(:f,),(:p,)}(
        ((; f), (; p), (x,)) -> f(x) + sum(p); num_parameters=(; p=2)
    )
    expr = TemplateExpression(
        (;
            f=ComposableExpression(
                Node{Float64}(; feature=1); operators=Options().operators
            )
        );
        structure=struct_mut,
        operators=Options().operators,
        variable_names=["x"],
        parameters=(; p=[1.0, 2.0]),
    )

    rng = MersenneTwister(0)
    options = Options()
    old_params = copy(get_metadata(expr).parameters.p._data)
    let param_changed = false
        # Force enough trials to see if param vector changes:
        for _ in 1:50
            mutated_expr = mutate_constant(copy(expr), 1.0, options, rng)
            new_params = get_metadata(mutated_expr).parameters.p._data
            if new_params != old_params
                param_changed = true
            end
        end
        @test param_changed == true
    end
end

@testitem "search with parametric template expressions" tags = [:part1] begin
    #! format: off
    #literate_begin file="src/examples/template_parametric_expression.md"
    #=
    # Parametrized Template Expressions

    Template expressions in SymbolicRegression.jl can include parametric forms - expressions with tunable constants
    that are optimized during the search. This can even include learn class-specific parameters that vary by category,
    analogous to `ParametricExpression`s.

    In this tutorial, we'll demonstrate how to use parametric template expressions to learn a model where:

    - Some constants are shared across all data points
    - Other constants vary by class
    - The structure combines known forms (like cosine) with unknown sub-expressions

    =#

    using SymbolicRegression
    using Random: MersenneTwister, randn, rand
    using MLJBase: machine, fit!, predict, report

    #=
    ## The Model Structure

    We'll work with a model that combines:
    - A cosine term with class-specific phase shifts
    - A polynomial term
    - Global scaling parameters

    Specifically, let's say that our true model has the form:

    ```math
    y = A \cos(f(x_2) + \Delta_c) + g(x_1) - B
    ```

    where:
    - ``A`` is a global amplitude (same for all classes)
    - ``\Delta_c`` is a phase shift that depends on the class label
    - ``f(x_2)`` is some function of ``x_2`` (in our case, just ``x_2``)
    - ``g(x_1)`` is some function of ``x_1`` (in our case, ``x_1^2``)
    - ``B`` is a global offset

    We'll generate synthetic data where:
    - ``A = 2.0`` (amplitude)
    - ``\Delta_1 = 0.1`` (phase shift for class 1)
    - ``\Delta_2 = 1.5`` (phase shift for class 2)
    - ``B = 2.0`` (offset)
    =#

    ## Set random seed for reproducibility
    rng = MersenneTwister(0)

    ## Number of data points
    n = 200

    ## Generate random features
    x1 = randn(rng, n)            # feature 1
    x2 = randn(rng, n)            # feature 2
    class = rand(rng, 1:2, n)     # class labels 1 or 2

    ## Define the true parameters
    Δ_phase = [0.1, 1.5]   # phase shift for class 1 and 2
    A = 2.0                # amplitude
    B = 2.0                # offset

    ## Add some noise
    eps = randn(rng, n) * 1e-5

    ## Generate targets using the true underlying function
    y = [
        A * cos(x2[i] + Δ_phase[class[i]]) + x1[i]^2 - B
        for i in 1:n
    ]
    y .+= eps

    #=
    ## Defining the Template

    Now we'll use the `@template_spec` macro to encode this structure, which will create
    a `TemplateExpressionSpec` object.
    =#

    ## Define the template structure with sub-expressions f and g
    template = @template_spec(
        expressions=(f, g),
        parameters=(p1=2, p2=2)
    ) do x1, x2, class
        return p1[1] * cos(f(x2) + p2[class]) + g(x1) - p1[2]
    end

    #=
    Let's break down this template:
    - We declared two sub-expressions: `f` and `g` that we want to learn
        - By calling `f(x2)` and `g(x1)`, the forward pass will constrain both expressions
            to only include a single input argument.
    - We declared two parameter vectors: `p1` (length 2) and `p2` (length 2)
    - The template combines these components as:
        - `p1[1]` is the amplitude (global parameter)
        - `cos(f(x2) + p2[class])` adds a class-specific phase shift via `p2[class]`
        - `g(x1)` represents (we hope) the quadratic term
        - `p1[2]` is the global offset

    Now we'll set up an SRRegressor with our template:
    =#

    model = SRRegressor(
        binary_operators = (+, -, *, /),
        niterations = 300,
        maxsize = 20,
        expression_spec = template,
        early_stop_condition = (loss, complexity) -> loss < 1e-5 && complexity < 10,  #src
    )

    ## Package data up for MLJ
    X = (; x1, x2, class)
    mach = machine(model, X, y)

    #=
    At this point, you would run:
    ```julia
    fit!(mach)
    ```

    which will evolve expressions following our template structure. The final result is accessible with:
    ```julia
    report(mach)
    ```
    which returns a named tuple of the fitted results, including the `.equations` field containing
    the `TemplateExpression` objects that dominated the Pareto front.

    ## Interpreting Results

    After training, you can inspect the expressions found:
    ```julia
    r = report(mach)
    best_expr = r.equations[r.best_idx]
    ```

    You can also extract the individual sub-expressions (stored as `ComposableExpression` objects):
    ```julia
    inner_exprs = get_contents(best_expr)
    metadata = get_metadata(best_expr)
    ```

    The learned expression should closely match our true generating function:
    - `f(x2)` should be approximately `x2`  (note it will show up as `x1` in the raw contents, but this simply is a relative indexing of its arguments!)
    - `g(x1)` should be approximately `x1^2`
    - The parameters should be close to their true values:
        - `p1[1] ≈ 2.0` (amplitude)
        - `p1[2] ≈ 2.0` (offset)
        - `p2[1] ≈ 0.1 mod 2π` (phase shift for class 1)
        - `p2[2] ≈ 1.5 mod 2π` (phase shift for class 2)

    You can use the learned expression to make predictions using either `predict(mach, X)`,
    or by calling `best_expr(X_raw)` directly (note that `X_raw` needs to be a matrix of shape
    `(n, d)` where `n` is the number of samples and `d` is the dimension of the features).
    =#

    #literate_end
    #! format: on

    fit!(mach)

    num_exprs = length(report(mach).equations)
    @test sum(abs2, predict(mach, (data=X, idx=num_exprs)) .- y) / n < 1e-5
end

@testitem "Preallocated copying with parameters" tags = [:part2] begin
    using SymbolicRegression
    using Random: MersenneTwister
    using DynamicExpressions:
        allocate_container, copy_into!, get_contents, get_metadata, get_scalar_constants

    struct_sum_params = TemplateStructure{(:f,),(:p,)}(
        ((; f), (; p), (x,)) -> f(x) + sum(p); num_parameters=(; p=2)
    )

    # Subexpression: single feature #1
    subex = ComposableExpression(
        Node{Float64}(; feature=1); operators=Options().operators, variable_names=["x"]
    )

    expr = TemplateExpression(
        (; f=subex,);
        structure=struct_sum_params,
        operators=Options().operators,
        variable_names=["x"],
        parameters=(; p=[10.0, 20.0]),  # distinct param values
    )

    # We'll mutate the original's parameters to check preallocated copying
    preallocated_expr = allocate_container(expr)
    get_metadata(expr).parameters.p._data .= [100.0, 200.0]

    # Now copy over
    new_expr = copy_into!(preallocated_expr, expr)

    @test get_metadata(new_expr).parameters.p._data == [100.0, 200.0]

    # Evaluate with shape [1, 1]
    X1 = reshape([1.0], 1, 1)
    # => subex(1.0)=1 => sum(params)=300 => total=[301]
    @test expr(X1) == [1.0 + 300.0]

    X2 = reshape([2.0], 1, 1)
    @test new_expr(X2) == [2.0 + 300.0]
end

@testitem "Zero-parameter edge case" tags = [:part3] begin
    using SymbolicRegression

    struct_zero_params = TemplateStructure{(:f,)}(
        ((; f), (x,)) -> f(x); num_parameters=nothing
    )
    x = ComposableExpression(Node{Float64}(; feature=1); operators=Options().operators)
    expr_zero = TemplateExpression(
        (; f=x,);
        structure=struct_zero_params,
        operators=Options().operators,
        parameters=nothing,
    )
    @test get_metadata(expr_zero).parameters === NamedTuple()

    # Evaluate => just f(x)
    X_ones = reshape([10.0], 1, 1)

    @test expr_zero(X_ones) == [10.0]
end

@testitem "Non-Float64 parameter types" tags = [:part1] begin
    using SymbolicRegression

    struct32 = TemplateStructure{(:f,),(:p,)}(
        ((; f), (; p), (x,)) -> f(x) + sum(p); num_parameters=(; p=2)
    )
    # Subex as ComplexF32
    subex_f32 = ComposableExpression(
        Node{ComplexF32}(; feature=1); operators=Options().operators, variable_names=["x"]
    )
    subex_f32 = 2.0 * subex_f32
    param32 = ComplexF32[10.0 + 0im, 20.0 + 0im]

    expr_f32 = TemplateExpression(
        (; f=subex_f32,);
        structure=struct32,
        operators=Options().operators,
        variable_names=["x"],
        parameters=(; p=param32),
    )
    @test eltype(get_metadata(expr_f32).parameters.p._data) == ComplexF32

    Xtest = reshape(ComplexF32[2.0 + 0im], 1, 1)
    @test expr_f32(Xtest) == [ComplexF32(34.0 + 0im)]
    @test expr_f32(Xtest) isa Vector{ComplexF32}
end

@testitem "multi-parameter expressions" tags = [:part2] begin
    using SymbolicRegression
    using SymbolicRegression.MutationFunctionsModule: mutate_constant
    using DynamicExpressions:
        allocate_container, copy_into!, get_metadata, get_scalar_constants
    using Random: MersenneTwister
    using MLJBase: matrix

    function multi_param_combine((; f, g), (; p1, p2), (x, y))
        return p1[1] * f(x)^2 + p1[2] * f(x) + p1[3] + p2[1] * g(y)^2 + p2[2] * g(y)
    end
    struct_multi = TemplateStructure{(:f, :g),(:p1, :p2)}(
        multi_param_combine; num_parameters=(; p1=3, p2=2)
    )

    @test struct_multi.num_features == (; f=1, g=1)
    @test struct_multi.num_parameters == (; p1=3, p2=2)

    operators = Options().operators
    x1 = ComposableExpression(Node{Float64}(; feature=1); operators)
    x2 = ComposableExpression(Node{Float64}(; feature=1); operators)

    expr_multi = TemplateExpression(
        (; f=x1, g=x2 + 0.0);
        structure=struct_multi,
        operators=operators,
        parameters=(; p1=[1.0, 2.0, 3.0], p2=[-1.0, -2.0]),
    )
    # Ensure scalar constants are correctly inferred:
    @test get_scalar_constants(expr_multi)[1] == [0.0, 1.0, 2.0, 3.0, -1.0, -2.0]

    # Test evaluation
    X = [2.0 3.0; 4.0 5.0]  # 2×2 matrix: 2 features, 2 data points
    out = expr_multi(X)
    # For first data point:
    # f(x)=2, g(y)=4 => 1*2^2 + 2*2 + 3 + (-1)*4^2 + (-2)*4 = 4 + 4 + 3 + -16 + -8 = -13
    # For second data point:
    # f(x)=3, g(y)=5 => 1*3^2 + 2*3 + 3 + (-1)*5^2 + (-2)*5 = 9 + 6 + 3 + -25 + -10 = -17
    @test out ≈ [-13.0, -17.0]

    # Test mutation
    rng = MersenneTwister(0)
    options = Options()
    old_p1 = copy(get_metadata(expr_multi).parameters.p1._data)
    old_p2 = copy(get_metadata(expr_multi).parameters.p2._data)
    let param_changed = [false, false]
        # Force enough trials to see if param vectors change:
        for _ in 1:50
            mutated_expr = mutate_constant(copy(expr_multi), 1.0, options, rng)
            new_p1 = get_metadata(mutated_expr).parameters.p1._data
            new_p2 = get_metadata(mutated_expr).parameters.p2._data
            if new_p1 != old_p1
                param_changed[1] = true
            end
            if new_p2 != old_p2
                param_changed[2] = true
            end
        end
        @test param_changed == [true, true]
    end

    # Test preallocated copying
    preallocated_expr = allocate_container(expr_multi)
    get_metadata(expr_multi).parameters.p1._data .= [10.0, 20.0, 30.0]
    get_metadata(expr_multi).parameters.p2._data .= [-10.0, -20.0]

    # Now copy over
    new_expr = copy_into!(preallocated_expr, expr_multi)

    @test get_metadata(new_expr).parameters.p1._data == [10.0, 20.0, 30.0]
    @test get_metadata(new_expr).parameters.p2._data == [-10.0, -20.0]
end

@testitem "printing" tags = [:part3] begin
    using SymbolicRegression

    struct1 = TemplateStructure{(:f,),(:p,)}(
        ((; f), (; p), (x,)) -> f(x) + sum(p); num_parameters=(; p=2)
    )
    operators = Options().operators
    x1 = ComposableExpression(Node{Float64}(; feature=1); operators)
    expr = TemplateExpression(
        (; f=x1); structure=struct1, operators, parameters=(; p=[1.0, 2.0])
    )
    # Parameters get printed too!
    @test string(expr) == "f = #1; p = [1.0, 2.0]"

    # But, if we have more than 4 params, there will be a ...:
    structure = TemplateStructure{(:f,),(:p1, :p2)}(
        ((; f), (; p1, p2), (x,)) -> f(x) + sum(p1) + sum(p2);
        num_parameters=(; p1=10, p2=1),
    )
    expr = TemplateExpression(
        (; f=x1); structure=structure, operators, parameters=(; p1=ones(10), p2=[2.0])
    )
    @test string(expr) ==
        "f = #1; p1 = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]; p2 = [2.0]"
end

@testitem "indexed multi-parameter expressions" tags = [:part1] begin
    using SymbolicRegression
    using Random: MersenneTwister
    using MLJBase: matrix

    operators = Options().operators
    x1, x2, x3 = map(i -> ComposableExpression(Node{Float64}(; feature=i); operators), 1:3)

    f = x1 * x2 + x3 * 1.5

    struct_indexed = TemplateStructure{(:f,),(:p1, :p2, :p3)}(
        function ((; f), (; p1, p2, p3), (x, y, i1, i2))
            return f(x, p1[i1], p2[i2]) + p3[1] * y
        end;
        num_parameters=(; p1=8, p2=3, p3=1),
    )
    parameters = (; p1=rand(8), p2=rand(3), p3=rand(1))
    expr = TemplateExpression(
        (; f);
        structure=struct_indexed,
        operators=operators,
        parameters=NamedTuple{(:p1, :p2, :p3)}(map(copy, values(parameters))),
    )

    x = rand(32)
    y = rand(32)
    i1 = rand(1:8, 32)
    i2 = rand(1:3, 32)

    X = matrix((; x, y, i1, i2); transpose=true)
    true_f(x1, x2, x3) = x1 * x2 + x3 * 1.5
    @test expr(X) ≈ [
        true_f(x[i], parameters.p1[i1[i]], parameters.p2[i2[i]]) + parameters.p3[1] * y[i]
        for i in 1:32
    ]
end
