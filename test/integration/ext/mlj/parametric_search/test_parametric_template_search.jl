@testitem "search with parametric template expressions" tags = [:part1] begin
    #! format: off
    #literate_begin file="src/examples/template_parametric_expression.md"
    #=
    # Parametrized Template Expressions

    Template expressions in SymbolicRegression.jl can include parametric forms - expressions with tunable constants
    that are optimized during the search. This can even include class-specific parameters that vary by category.

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
        populations = 8,
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
    `(d, n)` where `n` is the number of samples and `d` is the dimension of the features).
    =#

    #literate_end
    #! format: on

    fit!(mach)

    num_exprs = length(report(mach).equations)
    @test sum(abs2, predict(mach, (data=X, idx=num_exprs)) .- y) / n < 1e-5
end
