# Toy Examples with Code

```julia
using SymbolicRegression
using MLJ
```

## 1. Simple search

Here's a simple example where we
find the expression `2 cos(x4) + x1^2 - 2`.

```julia
X = 2randn(1000, 5)
y = @. 2*cos(X[:, 4]) + X[:, 1]^2 - 2

model = SRRegressor(
    binary_operators=[+, -, *, /],
    unary_operators=[cos],
    niterations=30
)
mach = machine(model, X, y)
fit!(mach)
```

Let's look at the returned table:

```julia
r = report(mach)
r
```

We can get the selected best tradeoff expression with:

```julia
r.equations[r.best_idx]
```

## 2. Custom operator

Here, we define a custom operator and use it to find an expression:

```julia
X = 2randn(1000, 5)
y = @. 1/X[:, 1]

my_inv(x) = 1/x

model = SRRegressor(
    binary_operators=[+, *],
    unary_operators=[my_inv],
)
mach = machine(model, X, y)
fit!(mach)
r = report(mach)
println(r.equations[r.best_idx])
```

## 3. Multiple outputs

Here, we do the same thing, but with multiple expressions at once,
each requiring a different feature. This means that we need to use
`MultitargetSRRegressor` instead of `SRRegressor`:

```julia
X = 2rand(1000, 5) .+ 0.1
y = @. 1/X[:, 1:3]

my_inv(x) = 1/x

model = MultitargetSRRegressor(; binary_operators=[+, *], unary_operators=[my_inv])
mach = machine(model, X, y)
fit!(mach)
```

The report gives us lists of expressions instead:

```julia
r = report(mach)
for i in 1:3
    println("y[$(i)] = ", r.equations[i][r.best_idx[i]])
end
```

## 4. Plotting an expression

For now, let's consider the expressions for output 1 from the previous example:
We can get a SymbolicUtils version with:

```julia
using SymbolicUtils

eqn = node_to_symbolic(r.equations[1][r.best_idx[1]])
```

We can get the LaTeX version with `Latexify`:

```julia
using Latexify

latexify(string(eqn))
```

We can also plot the prediction against the truth:

```julia
using Plots

ypred = predict(mach, X)
scatter(y[1, :], ypred[1, :], xlabel="Truth", ylabel="Prediction")
```

## 5. Other types

SymbolicRegression.jl can handle most numeric types you wish to use.
For example, passing a `Float32` array will result in the search using
32-bit precision everywhere in the codebase:

```julia
X = 2randn(Float32, 1000, 5)
y = @. 2*cos(X[:, 4]) + X[:, 1]^2 - 2

model = SRRegressor(binary_operators=[+, -, *, /], unary_operators=[cos], niterations=30)
mach = machine(model, X, y)
fit!(mach)
```

we can see that the output types are `Float32`:

```julia
r = report(mach)
best = r.equations[r.best_idx]
println(typeof(best))
# Expression{Float32,Node{Float32},...}
```

We can also use `Complex` numbers (ignore the warning
from MLJ):

```julia
cos_re(x::Complex{T}) where {T} = cos(abs(x)) + 0im

X = 15 .* rand(ComplexF64, 1000, 5) .- 7.5
y = @. 2*cos_re((2+1im) * X[:, 4]) + 0.1 * X[:, 1]^2 - 2

model = SRRegressor(
    binary_operators=[+, -, *, /],
    unary_operators=[cos_re],
    maxsize=30,
    niterations=100
)
mach = machine(model, X, y)
fit!(mach)
```

## 6. Dimensional constraints

One other feature we can exploit is dimensional analysis.
Say that we know the physical units of each feature and output,
and we want to find an expression that is dimensionally consistent.

We can do this as follows, using `DynamicQuantities` to assign units.
First, let's make some data on Newton's law of gravitation:

```julia
using DynamicQuantities
using SymbolicRegression

M = (rand(100) .+ 0.1) .* Constants.M_sun
m = 100 .* (rand(100) .+ 0.1) .* u"kg"
r = (rand(100) .+ 0.1) .* Constants.R_earth

G = Constants.G

F = @. (G * M * m / r^2)
```

(Note that the `u` macro from `DynamicQuantities` will automatically convert to SI units. To avoid this,
use the `us` macro.)

Now, let's ready the data for MLJ:

```julia
X = (; M=M, m=m, r=r)
y = F
```

Since this data has such a large dynamic range, let's also create a custom loss function
that looks at the error in log-space:

```julia
function loss_fnc(prediction, target)
    # Useful loss for large dynamic range
    scatter_loss = abs(log((abs(prediction)+1e-20) / (abs(target)+1e-20)))
    sign_loss = 10 * (sign(prediction) - sign(target))^2
    return scatter_loss + sign_loss
end
```

Now let's define and fit our model:

```julia
model = SRRegressor(
    binary_operators=[+, -, *, /],
    unary_operators=[square],
    elementwise_loss=loss_fnc,
    complexity_of_constants=2,
    maxsize=25,
    niterations=100,
    populations=50,
    dimensional_constraint_penalty=10^5,
)
mach = machine(model, X, y)
fit!(mach)
```

You can observe that all expressions with a loss under
our penalty are dimensionally consistent! (The `"[?]"` indicates free units in a constant,
which can cancel out other units in the expression.) For example,

```julia
"y[m s⁻² kg] = (M[kg] * 2.6353e-22[?])"
```

would indicate that the expression is dimensionally consistent, with
a constant `"2.6353e-22[m s⁻²]"`.

Note that you can also search for dimensionless units by settings
`dimensionless_constants_only` to `true`.

## 7. Working with Expressions

Expressions in `SymbolicRegression.jl` are represented using the `Expression{T,Node{T},...}` type, which provides a more robust way to combine structure, operators, and constraints. Here's an example:

```julia
using SymbolicRegression

# Define options with operators and structure
options = Options(
    binary_operators=[+, -, *],
    unary_operators=[cos],
)

operators = options.operators
variable_names = ["x1", "x2"]
x1 = Expression(
    Node{Float64}(feature=1),
    operators=operators,
    variable_names=variable_names,
)
x2 = Expression(
    Node{Float64}(feature=2),
    operators=operators,
    variable_names=variable_names,
)

# Construct and evaluate expression
expr = x1 * cos(x2 - 3.2)
X = rand(Float64, 2, 100)
output = expr(X)
```

This `Expression` type, contains the operators used in the expression.
These are what are returned by the search. The raw `Node` type (which is
what used to be output directly) is accessible with

```julia
get_contents(expr)
```

## 8. Template Expressions

Template expressions allow you to define structured expressions where different parts can be constrained to use specific variables.
In this example, we'll create expressions that constrain the functional form in highly specific ways.
(_For more complex examples, see ["Searching with template expressions"](examples/template_expression.md)_ and ["Parameterized Template Expressions"](examples/template_parametric_expression.md)\_)

First, let's set up our basic configuration:

```julia
using SymbolicRegression
using Random: rand, MersenneTwister
using MLJBase: machine, fit!, report
```

The key part is defining our template structure. This determines how different parts of the expression combine:

```julia
expression_spec = @template_spec(expressions=(f, g)) do x1, x2, x3
    f(x1, x2) + g(x2) - g(x3)
end
```

With this structure, we are telling the algorithm that it can learn
any symbolic expressions `f` and `g`, with `f` a function of two inputs,
and `g` a function of one input. The result of

```math
f(x_1, x_2) + g(x_2) - g(x_3)
```

will be compared with the target `y`.

Let's generate some example data:

```julia
n = 100
rng = MersenneTwister(0)
x1 = 10rand(rng, n)
x2 = 10rand(rng, n)
x3 = 10rand(rng, n)
X = (; x1, x2, x3)
y = [
    2 * cos(x1[i] + 3.2) + x2[i]^2 - 0.8 * x3[i]^2
    for i in eachindex(x1)
]
```

Now, remember our structure: for the model to learn this,
it would need to correctly disentangle the contribution
of `f` and `g`!

Now we can set up and train our model by passing the structure in to `expression_spec`:

```julia
model = SRRegressor(;
    binary_operators=(+, -, *, /),
    unary_operators=(cos,),
    niterations=500,
    maxsize=25,
    expression_spec=expression_spec,
)

mach = machine(model, X, y)
fit!(mach)
```

If all goes well, you should see a printout with the following expression:

```text
y = ╭ f = ((#2 * 0.2) * #2) + (cos(#1 + 0.058407) * -2)
    ╰ g = #1 * (#1 * 0.8)
```

This is what we were looking for! We can see that under
$f(x_1, x_2) + g(x_2) - g(x_3)$, this correctly expands to
$2 \cos(x_1 + 3.2) + x_2^2 - 0.8 x_3^2$.

We can also access the individual parts of the template expression
directly from the report:

```julia
r = report(mach)
best_expr = r.equations[r.best_idx]

# Access individual parts of the template expression
println("f: ", get_contents(best_expr).f)
println("g: ", get_contents(best_expr).g)
```

The `TemplateExpression` combines these under the structure
so we can directly and efficiently evaluate this:

```julia
best_expr(randn(3, 20))
```

The above code demonstrates how template expressions can be used to:

- Define structured expressions with multiple components
- Constrains which variables can be used in each component
- Create expressions that can output multiple values

You can even output custom structs - see the more detailed [Template Expression example](examples/template_expression.md)!

Be sure to also check out the [Parametric Template Expressions example](examples/template_parametric_expression.md).

## 9. Logging with TensorBoard

You can track the progress of symbolic regression searches using TensorBoard or other logging backends. Here's an example using `TensorBoardLogger` and wrapping it with [`SRLogger`](@ref):

```julia
using SymbolicRegression
using TensorBoardLogger
using MLJ

logger = SRLogger(TBLogger("logs/sr_run"))

# Create and fit model with logger
model = SRRegressor(
    binary_operators=[+, -, *],
    maxsize=40,
    niterations=100,
    logger=logger
)

X = (a=rand(500), b=rand(500))
y = @. 2 * cos(X.a * 23.5) - X.b^2

mach = machine(model, X, y)
fit!(mach)
```

You can then view the logs with:

```bash
tensorboard --logdir logs
```

The TensorBoard interface will show
the loss curves over time (at each complexity), as well
as the Pareto frontier volume which can be used as an overall metric
of the search performance.

## 10. Using Differential Operators

`SymbolicRegression.jl` supports differential operators via [`DynamicDiff.jl`](https://github.com/MilesCranmer/DynamicDiff.jl), allowing you to include derivatives directly within template expressions.
Here is an example where we discover the integral of $\frac{1}{x^2 \sqrt{x^2 - 1}}$ in the range $x > 1$.

First, let's generate some data for the integrand:

```julia
using SymbolicRegression
using Random

rng = MersenneTwister(42)
x = 1 .+ rand(rng, 1000) * 9  # Sampling points in the range [1, 10]
y = @. 1 / (x^2 * sqrt(x^2 - 1))  # Values of the integrand
```

Now, define the template for the derivative operator:

```julia
using SymbolicRegression: D

expression_spec = @template_spec(expressions=(f,)) do x
    D(f, 1)(x)
end
```

We can now set up the model to find the symbolic expression for the integral:

```julia
using MLJ

model = SRRegressor(
    binary_operators=(+, -, *, /),
    unary_operators=(sqrt,),
    maxsize=20,
    expression_spec=expression_spec,
)

X = (; x=x)
mach = machine(model, X, y)
fit!(mach)
```

The learned expression will represent $f(x)$, the indefinite integral of the given function. The derivative of $f(x)$ should match the target $\frac{1}{x^2 \sqrt{x^2 - 1}}$.

You can access the best expression from the report:

```julia
r = report(mach)
best_expr = r.equations[r.best_idx]

println("Learned expression: ", best_expr)
```

If successful, the result should simplify to something like $\frac{\sqrt{x^2 - 1}}{x}$, which is the integral of the target function.

## 11. Seeding search with initial guesses

You can also provide initial guesses for the search.
In this example, let's look for the following function:

```math
\sin(x_1 x_2 + 0.1) + \cos(x_3) x_4 + \frac{x_5}{x_6^2 + 1}
```

```julia
using SymbolicRegression, MLJ

X = randn(Float32, 6, 2048)
y = @. sin(X[1, :] * X[2, :] + 0.1f0) + cos(X[3, :]) * X[4, :] + X[5, :] / (X[6, :] * X[6, :] + 1)
```

This expression is quite complex. Now, say that we know most of
the structure, but want to further optimize it. We can provide
a guess for the search:

```julia
model = SRRegressor(
    binary_operators=[+, -, *, /],
    unary_operators=[sin, cos],
    maxsize=35,
    niterations=35,
    guesses=["sin(x1 * x2) + cos(x3) * x4 + x5 / (x6 * x6 + 0.9)", #= can provide additional guesses here =#],
    batching=true,
    batch_size=32,
)

mach = machine(model, X', y)
fit!(mach)
```

If everything goes well, it should optimize the `0.9` to `1.0`,
and also discover the `+ 0.1` term inside the sinusoid, whereas
this might have been difficult to discover as fast from the normal search.

You can also provide multiple guesses. For a template expression,
your guesses should be an array of named tuples, such as
`(; f="cos(#1) + 0.1", g="sin(#2) - 0.9")`.

## 12. Higher-arity operators

You can use operators with more than 2 arguments by passing an `OperatorEnum` explicitly.
This operator allows you to declare arbitrary arities by passing them in a `arity => (op1, op2, ...)` format.

Here's an example using a ternary conditional operator:

```julia
using SymbolicRegression, MLJ

scalar_ifelse(a, b, c) = a > 0 ? b : c

X = randn(3, 100)
y = [X[1, i] > 0 ? 2*X[2, i] : X[3, i] for i in 1:100]

model = SRRegressor(
    operators=OperatorEnum(
        1 => (),
        2 => (+, -, *, /),
        3 => (scalar_ifelse,)
    ),
    niterations=35,
)
mach = machine(model, X', y)
fit!(mach)
```

This sort of piecewise logic might be difficult to express with only binary operators.

## 13. Additional features

For the many other features available in SymbolicRegression.jl,
check out the API page for `Options`. You might also find it useful
to browse the documentation for the Python frontend
[PySR](http://astroautomata.com/PySR), which has additional documentation.
In particular, the [tuning page](http://astroautomata.com/PySR/tuning)
is useful for improving search performance.

---

# Advanced Examples for Contributors

The following examples demonstrate sophisticated usage patterns and architectural concepts that are particularly valuable for contributors who want to understand how different parts of the library work together. These examples showcase advanced features, performance optimizations, debugging techniques, and integration patterns found in real-world usage.

## 14. Multi-Stage Search Strategies

Complex problems often benefit from multi-stage approaches where you progressively refine the search. This example shows how to chain multiple searches with different parameter sets and seed each stage with results from the previous one.

```julia
using SymbolicRegression, MLJ

# Generate complex data that benefits from staged search
X = randn(Float32, 6, 2048)
y = @. sin(X[1, :] * X[2, :] + 0.1f0) + cos(X[3, :]) * X[4, :] + X[5, :] / (X[6, :] * X[6, :] + 1)

# Stage 1: Quick exploration with simple operators to find structure
println("Stage 1: Structural discovery...")
model1 = SRRegressor(
    binary_operators=[+, -, *],
    maxsize=15,
    niterations=50,
    populations=20,
    ncyclesperiteration=100,
    # Focus on finding basic structure quickly
    complexity_of_constants=1,
    parsimony=0.01f0,
)

mach1 = machine(model1, X', y)
fit!(mach1)
r1 = report(mach1)

# Extract promising expressions as guesses for next stage
top_expressions = String[]
for i in 1:min(3, length(r1.equations))
    push!(top_expressions, string(r1.equations[i]))
end

# Stage 2: Detailed refinement with more operators and the best guesses
println("Stage 2: Expression refinement...")
model2 = SRRegressor(
    binary_operators=[+, -, *, /],
    unary_operators=[sin, cos],
    maxsize=35,
    niterations=100,
    populations=30,
    # Use results from stage 1 as starting points
    guesses=top_expressions,
    # Fine-tune search parameters
    complexity_of_constants=2,
    parsimony=0.005f0,
    adaptive_parsimony_scaling=20.0,
)

mach2 = machine(model2, X', y)
fit!(mach2)
r2 = report(mach2)

println("Best expression from multi-stage search:")
println(r2.equations[r2.best_idx])
```

## 15. Custom Loss Functions for Scientific Applications

This example demonstrates how to implement domain-specific loss functions that encode scientific knowledge, such as correlation-based losses, weighted residuals for heteroskedastic data, and loss functions that handle measurement uncertainties.

```julia
using SymbolicRegression, MLJ, Statistics

# Generate scientific data with heteroskedastic errors
n = 1000
x1 = 10 .* rand(n)
x2 = 5 .* rand(n)
true_y = @. 2 * log(x1 + 1) + sqrt(x2)
# Heteroskedastic noise: error grows with signal magnitude
errors = @. 0.1 * sqrt(true_y) * randn()
y = true_y .+ errors
weights = @. 1.0 / (0.1 * sqrt(true_y))^2  # Inverse variance weighting

X = (x1=x1, x2=x2)

# Custom loss function that emphasizes correlation over absolute fit
function correlation_loss(predictions, targets, weights=nothing)
    # Remove any NaN or infinite values
    valid_mask = isfinite.(predictions) .& isfinite.(targets)
    if sum(valid_mask) < 3
        return Inf32
    end

    pred_clean = predictions[valid_mask]
    target_clean = targets[valid_mask]

    # Compute weighted correlation coefficient
    if weights !== nothing
        w_clean = weights[valid_mask]
        corr_coef = cor(pred_clean, target_clean, w_clean)
    else
        corr_coef = cor(pred_clean, target_clean)
    end

    # Loss is negative correlation (we want to maximize correlation)
    return Float32(1.0 - abs(corr_coef))
end

# Scientific loss that combines correlation and weighted MSE
function scientific_loss(predictions, targets, weights)
    mse_component = mean(weights .* (predictions .- targets).^2)
    corr_component = correlation_loss(predictions, targets, weights)

    # Combine both components with scientific reasoning:
    # High correlation ensures right functional form,
    # Low MSE ensures quantitative accuracy
    return Float32(0.3 * corr_component + 0.7 * mse_component)
end

model = SRRegressor(
    binary_operators=[+, -, *, /],
    unary_operators=[log, sqrt, exp],
    maxsize=20,
    niterations=100,
    # Use custom loss function
    full_objective=(tree, dataset) -> scientific_loss(
        tree(dataset.X), dataset.y, dataset.weights
    ),
    # Handle the weights properly
    weights=weights,
)

mach = machine(model, X, y)
fit!(mach)
r = report(mach)

println("Expression found with scientific loss:")
println(r.equations[r.best_idx])
```

## 16. Advanced Template Expressions for Multi-Physics Systems

This example demonstrates how to use template expressions to model complex multi-physics systems where different phenomena operate on different variables and scales, similar to the particle physics example but with more sophisticated constraint systems.

```julia
using SymbolicRegression, MLJ

# Simulate a coupled system: thermal + mechanical + electrical
n = 500
# Environmental conditions
time = sort(10 .* rand(n))
temperature = 300 .+ 50 .* sin.(time ./ 2)
electric_field = 1000 .* cos.(time)

# Material properties
strain = 0.01 .* rand(n)
conductivity = 1e-3 .* (1 .+ 0.1 .* randn(n))

# True coupled physics:
# - Thermal expansion: ε_thermal = α(T) * ΔT
# - Electrical response: σ = σ₀(E) * f(strain)
# - Mechanical coupling: stress = E_modulus(T,t) * ε_total

# Unknown functions we want to discover:
# α(T) = 1e-5 * T^0.5              (thermal expansion coefficient)
# σ₀(E) = 1e-6 * E^2                (nonlinear electrical response)
# f(ε) = exp(10*ε)                  (piezoresistive effect)
# E_modulus(T,t) = 2e11 / (1 + T/1000) * (1 + 0.1*sin(t))  (temperature and time dependent modulus)

α_true = @. 1e-5 * temperature^0.5
σ₀_true = @. 1e-6 * electric_field^2
f_strain_true = @. exp(10 * strain)
E_mod_true = @. 2e11 / (1 + temperature/1000) * (1 + 0.1*sin(time))

# Observed quantities (what we measure)
thermal_strain = α_true .* (temperature .- 300)
electrical_conductivity = σ₀_true .* f_strain_true
mechanical_stress = E_mod_true .* (strain .+ thermal_strain)

# Prepare data
X = (
    time=time,
    temperature=temperature,
    electric_field=electric_field,
    strain=strain
)

# Define output struct for multi-physics response
struct MultiPhysics{T}
    thermal_expansion::T
    electrical_response::T
    mechanical_response::T
end

y = [
    MultiPhysics(te, er, mr)
    for (te, er, mr) in zip(thermal_strain, electrical_conductivity, mechanical_stress)
]

# Template structure encoding physics domain knowledge
function coupled_physics_model((; α_coeff, σ_base, strain_factor, modulus_temp, modulus_time), (t, T, E, ε))
    # Each subfunction operates on physically meaningful variables
    _α = α_coeff(T)                    # Thermal expansion coeff depends on temperature
    _σ₀ = σ_base(E)                    # Base conductivity depends on electric field
    _f_strain = strain_factor(ε)       # Strain coupling factor
    _E_temp = modulus_temp(T)          # Temperature-dependent modulus
    _E_time = modulus_time(t)          # Time-dependent modulus factor

    # Physics-based coupling
    thermal_expansion = _α .* (T .- 300.0)
    electrical_response = _σ₀ .* _f_strain
    mechanical_response = _E_temp .* _E_time .* (ε .+ thermal_expansion)

    result = [
        MultiPhysics(te, er, mr)
        for (te, er, mr) in zip(thermal_expansion.x, electrical_response.x, mechanical_response.x)
    ]

    ValidVector(result, _α.valid && _σ₀.valid && _f_strain.valid && _E_temp.valid && _E_time.valid)
end

expression_spec = @template_spec(
    expressions=(α_coeff, σ_base, strain_factor, modulus_temp, modulus_time)
) do t, T, E, ε
    coupled_physics_model((; α_coeff, σ_base, strain_factor, modulus_temp, modulus_time), (t, T, E, ε))
end

model = SRRegressor(
    binary_operators=[+, -, *, /, ^],
    unary_operators=[exp, log, sin, cos, sqrt],
    maxsize=20,
    niterations=200,
    expression_spec=expression_spec,
    # Multi-objective loss for each physics component
    elementwise_loss=(pred, actual) -> (
        (pred.thermal_expansion - actual.thermal_expansion)^2 +
        (pred.electrical_response - actual.electrical_response)^2 +
        (pred.mechanical_response - actual.mechanical_response)^2
    ),
    complexity_of_constants=2,
    parsimony=0.01,
)

mach = machine(model, X, y)
fit!(mach)
r = report(mach)

println("Discovered multi-physics model:")
println(r.equations[r.best_idx])
```

## 17. Performance Monitoring and Search Diagnostics

Understanding search performance is crucial for tuning and debugging. This example shows how to implement comprehensive monitoring of the search process, including population statistics, convergence metrics, and computational profiling.

```julia
using SymbolicRegression, MLJ

# Custom logger that tracks detailed search statistics
mutable struct SearchDiagnostics
    iteration_times::Vector{Float64}
    best_losses::Vector{Float64}
    population_diversity::Vector{Float64}
    mutation_success_rates::Vector{Float64}
    complexity_distribution::Vector{Vector{Int}}

    SearchDiagnostics() = new(Float64[], Float64[], Float64[], Float64[], Vector{Int}[])
end

# Hook into the search process (simplified example)
function monitor_search_progress(hall_of_fame, population, iteration)
    # This would be implemented as a callback in practice
    diagnostics = SearchDiagnostics()

    # Track best loss over time
    if !isempty(hall_of_fame.members)
        best_loss = minimum(member.loss for member in hall_of_fame.members)
        push!(diagnostics.best_losses, best_loss)
    end

    # Monitor population diversity (simplified)
    if length(population.members) > 1
        loss_std = std([member.loss for member in population.members])
        push!(diagnostics.population_diversity, loss_std)
    end

    # Track complexity distribution
    complexities = [member.tree.complexity for member in population.members]
    push!(diagnostics.complexity_distribution, complexities)

    return diagnostics
end

# Example with built-in progress monitoring
X = randn(3, 1000)
y = @. 2*cos(X[1, :]) + X[2, :]^2 - X[3, :]

model = SRRegressor(
    binary_operators=[+, -, *, /],
    unary_operators=[cos, sin, exp],
    maxsize=25,
    niterations=50,
    populations=30,

    # Enable detailed progress tracking
    progress_bar=true,
    verbosity=1000,  # Print every 1000 evaluations

    # Performance tuning parameters
    fraction_replaced_hof=0.1,    # Replace 10% of population with hall of fame
    tournament_selection_n=10,     # Tournament size for selection

    # Convergence monitoring
    early_stop_condition=(loss, complexity) -> loss < 1e-8,
    timeout_in_seconds=300,       # Stop after 5 minutes
    max_evals=100_000,           # Limit total evaluations
)

# Profile the search
using Profile
@profile begin
    mach = machine(model, X', y)
    fit!(mach)
end

# Analyze performance
Profile.print(mincount=10)  # Show functions taking >1% of time

r = report(mach)
println("Search completed with $(length(r.equations)) expressions found")
println("Best expression: $(r.equations[r.best_idx])")
println("Final loss: $(r.losses[r.best_idx])")
```

## 18. Distributed Computing and Batch Processing

For large-scale problems, distributing the search across multiple processes or handling large datasets in batches is essential. This example shows advanced distributed computing patterns.

```julia
using SymbolicRegression, MLJ
using Distributed

# Add worker processes for distributed search
addprocs(4)  # Add 4 worker processes

@everywhere using SymbolicRegression

# Large dataset that benefits from distributed processing
n_samples = 50_000
n_features = 8
X = randn(Float32, n_features, n_samples)
# Complex target function
y = @. sin(X[1, :] * X[2, :]) + exp(-X[3, :]^2) + X[4, :] / (1 + X[5, :]^2) +
       cos(X[6, :]) * X[7, :] + sqrt(abs(X[8, :]))

# Distributed search configuration
model = SRRegressor(
    binary_operators=[+, -, *, /],
    unary_operators=[sin, cos, exp, sqrt],
    maxsize=30,
    niterations=100,

    # Distributed processing settings
    parallelism=:multithreading,  # or :multiprocessing for more processes
    numprocs=4,                   # Number of processes to use

    # Large dataset handling
    batching=true,
    batch_size=1000,              # Process in smaller batches

    # Population settings for distributed search
    populations=40,               # More populations for parallel search
    ncyclesperiteration=300,      # More cycles per iteration

    # Memory management
    should_simplify=true,         # Simplify expressions to save memory
    complexity_of_constants=3,    # Limit constant complexity
)

# Monitor memory usage during fit
function monitor_memory_usage()
    @async begin
        while true
            mem_usage = Sys.maxrss() / 1024^2  # MB
            println("Memory usage: $(round(mem_usage, digits=1)) MB")
            sleep(10)
        end
    end
end

monitor_task = monitor_memory_usage()

# Fit with large dataset
mach = machine(model, X', y)
@time fit!(mach)

# Clean up
Base.throwto(monitor_task, InterruptException())
rmprocs(workers())

r = report(mach)
println("Distributed search found: $(r.equations[r.best_idx])")
```

## 19. Integration with Optimization Libraries

This example shows how to integrate SymbolicRegression.jl with external optimization libraries for hybrid approaches, such as using gradient-based methods for constant optimization or incorporating global optimization for hyperparameter tuning.

```julia
using SymbolicRegression, MLJ
using Optim  # For constant optimization
using BlackBoxOptim  # For hyperparameter optimization

# Generate challenging optimization data
X = randn(4, 800)
# Function with parameters that benefit from good constant optimization
y = @. 3.14159 * sin(2.71828 * X[1, :]) + 1.41421 * X[2, :]^2 - 0.57721 * exp(X[3, :]/1.61803)

# Custom constant optimization using Optim.jl
function custom_constant_optimization(tree, dataset, options)
    # Extract constants from tree for optimization
    constants = []  # This would extract actual constants from the tree

    if isempty(constants)
        return tree, 0.0  # No constants to optimize
    end

    # Define objective for constant optimization
    function constant_objective(c)
        # This would substitute constants back into tree and evaluate loss
        # Simplified for example
        tree_with_constants = tree  # Would substitute constants here
        predictions = tree_with_constants(dataset.X)
        return sum((predictions .- dataset.y).^2)
    end

    # Use Optim.jl for constant optimization
    result = optimize(constant_objective, constants, BFGS())
    optimized_constants = Optim.minimizer(result)

    # Create new tree with optimized constants
    optimized_tree = tree  # Would substitute optimized constants
    final_loss = Optim.minimum(result)

    return optimized_tree, final_loss
end

# Hyperparameter optimization with BlackBoxOptim
function optimize_hyperparameters(X, y)
    # Define search space for hyperparameters
    function evaluate_config(params)
        parsimony, complexity_const, pop_size = params

        try
            model = SRRegressor(
                binary_operators=[+, -, *, /],
                unary_operators=[sin, cos, exp],
                maxsize=20,
                niterations=30,  # Short runs for hyperopt
                parsimony=parsimony,
                complexity_of_constants=complexity_const,
                populations=Int(pop_size),
                verbosity=0,  # Quiet for hyperopt
            )

            mach = machine(model, X', y)
            fit!(mach)
            r = report(mach)

            # Return negative loss (BlackBoxOptim minimizes)
            return -r.losses[r.best_idx]
        catch e
            return -Inf  # Invalid configuration
        end
    end

    # Optimize hyperparameters
    bounds = [(0.001, 0.1),    # parsimony
              (1, 5),          # complexity_of_constants
              (10, 50)]        # populations

    result = bboptimize(evaluate_config;
                       SearchRange=bounds,
                       MaxFuncEvals=50,
                       TraceMode=:compact)

    return best_candidate(result)
end

# First, optimize hyperparameters
println("Optimizing hyperparameters...")
best_params = optimize_hyperparameters(X, y)
parsimony_opt, complexity_const_opt, pop_size_opt = best_params

# Then run full search with optimized hyperparameters
println("Running full search with optimized hyperparameters...")
model = SRRegressor(
    binary_operators=[+, -, *, /],
    unary_operators=[sin, cos, exp],
    maxsize=25,
    niterations=150,
    parsimony=parsimony_opt,
    complexity_of_constants=complexity_const_opt,
    populations=Int(pop_size_opt),

    # Use custom constant optimization
    # In practice, this would be passed to the options
    verbosity=1000,
)

mach = machine(model, X', y)
fit!(mach)
r = report(mach)

println("Optimized search result:")
println("Best expression: $(r.equations[r.best_idx])")
println("Loss: $(r.losses[r.best_idx])")
```

## 20. Debugging and Expression Analysis

Understanding why certain expressions are found (or not found) requires sophisticated debugging tools. This example demonstrates techniques for analyzing search behavior, expression quality, and convergence patterns.

```julia
using SymbolicRegression, MLJ
using PlotlyJS  # For interactive plots

# Generate data with known ground truth for debugging
X = randn(3, 1000)
true_expr = "2*cos(x1) + x2^2 - 0.5*x3"
y = @. 2*cos(X[1, :]) + X[2, :]^2 - 0.5*X[3, :]

# Custom debugging callback system
mutable struct ExpressionDebugger
    expression_history::Vector{String}
    loss_history::Vector{Float64}
    complexity_history::Vector{Int}
    generation_times::Vector{Float64}

    ExpressionDebugger() = new(String[], Float64[], Int[], Float64[])
end

debugger = ExpressionDebugger()

# Expression quality analysis functions
function analyze_expression_components(expr_str)
    """Analyze structural components of an expression"""
    analysis = Dict(
        "has_trigonometric" => occursin(r"sin|cos|tan", expr_str),
        "has_polynomial" => occursin(r"\^[0-9]", expr_str),
        "has_exponential" => occursin(r"exp|log", expr_str),
        "operator_count" => length(collect(eachmatch(r"[+\-*/^]", expr_str))),
        "depth_estimate" => count(c -> c == '(', expr_str),
        "constant_count" => length(collect(eachmatch(r"[0-9]+\.?[0-9]*", expr_str)))
    )
    return analysis
end

function expression_similarity(expr1_str, expr2_str)
    """Compute similarity between two expressions"""
    # Simple structural similarity (in practice, use AST comparison)
    common_tokens = intersect(split(expr1_str, r"[\s\(\)\+\-\*/\^]+"),
                             split(expr2_str, r"[\s\(\)\+\-\*/\^]+"))
    all_tokens = union(split(expr1_str, r"[\s\(\)\+\-\*/\^]+"),
                      split(expr2_str, r"[\s\(\)\+\-\*/\^]+"))
    return length(common_tokens) / length(all_tokens)
end

function plot_search_progress(debugger, true_expr)
    """Create interactive plots of search progress"""

    # Loss convergence plot
    loss_trace = scatter(
        x=1:length(debugger.loss_history),
        y=debugger.loss_history,
        mode="lines+markers",
        name="Loss Evolution",
        line=attr(color="blue")
    )

    # Complexity vs Loss scatter
    complexity_trace = scatter(
        x=debugger.complexity_history,
        y=debugger.loss_history,
        mode="markers",
        name="Complexity vs Loss",
        marker=attr(size=8, color="red", opacity=0.6)
    )

    # Expression similarity to ground truth over time
    similarities = [expression_similarity(expr, true_expr) for expr in debugger.expression_history]
    similarity_trace = scatter(
        x=1:length(similarities),
        y=similarities,
        mode="lines+markers",
        name="Similarity to Truth",
        line=attr(color="green")
    )

    # Create subplots
    fig = make_subplots(
        rows=2, cols=2,
        subplot_titles=["Loss Evolution", "Complexity vs Loss",
                       "Similarity to Ground Truth", "Generation Times"],
        specs=[[Spec() Spec()] [Spec() Spec()]]
    )

    add_trace!(fig, loss_trace, row=1, col=1)
    add_trace!(fig, complexity_trace, row=1, col=2)
    add_trace!(fig, similarity_trace, row=2, col=1)

    return fig
end

# Run search with debugging enabled
model = SRRegressor(
    binary_operators=[+, -, *, /],
    unary_operators=[cos, sin, exp],
    maxsize=20,
    niterations=100,
    populations=20,
    verbosity=0,  # Disable default output for cleaner debugging

    # Enable various debugging features
    save_to_file=false,
    progress_bar=false,
)

println("Starting debugged search...")
mach = machine(model, X', y)

# In practice, you would hook into the search process to collect debugging info
# For demonstration, we'll simulate this
for i in 1:50
    # Simulate expression evaluation
    fake_expr = "$(rand()) * cos(x1) + $(rand()) * x2^2"
    fake_loss = abs(randn()) * exp(-i/10)  # Decreasing loss over time
    fake_complexity = rand(5:25)

    push!(debugger.expression_history, fake_expr)
    push!(debugger.loss_history, fake_loss)
    push!(debugger.complexity_history, fake_complexity)
    push!(debugger.generation_times, rand() * 0.1)
end

fit!(mach)
r = report(mach)

# Analyze results
println("\n=== SEARCH ANALYSIS ===")
println("Final best expression: $(r.equations[r.best_idx])")
println("Final loss: $(r.losses[r.best_idx])")

# Expression component analysis
final_expr_str = string(r.equations[r.best_idx])
analysis = analyze_expression_components(final_expr_str)
println("\nExpression structure analysis:")
for (key, value) in analysis
    println("  $key: $value")
end

# Similarity to ground truth
similarity = expression_similarity(final_expr_str, true_expr)
println("\nSimilarity to ground truth: $(round(similarity, digits=3))")

# Performance statistics
if !isempty(debugger.loss_history)
    println("\nSearch statistics:")
    println("  Best loss achieved: $(minimum(debugger.loss_history))")
    println("  Average generation time: $(round(mean(debugger.generation_times), digits=4))s")
    println("  Expressions evaluated: $(length(debugger.expression_history))")
end

# Create diagnostic plots
fig = plot_search_progress(debugger, true_expr)
# In practice: display(fig) or savefig(fig, "search_diagnostics.html")

println("\nDebugging analysis complete!")
```

## 21. Custom Constraint Systems and Domain-Specific Logic

Advanced applications often require domain-specific constraints that go beyond simple complexity limits. This example shows how to implement custom constraint systems for specific scientific domains.

```julia
using SymbolicRegression, MLJ

# Example: Chemical reaction kinetics with physical constraints
struct ChemicalConstraints
    max_reaction_order::Int
    required_arrhenius::Bool
    conservation_laws::Vector{String}
    forbidden_combinations::Vector{Tuple{String,String}}
end

function chemical_constraint_function(tree, options)
    """
    Custom constraint function for chemical kinetics expressions.
    Returns true if expression violates constraints.
    """
    expr_str = string(tree)

    # Check for negative concentrations (unphysical)
    if occursin(r"exp\s*\(\s*-", expr_str) && !occursin("T", expr_str)
        return true  # Negative exponential without temperature term
    end

    # Require Arrhenius form for temperature dependence
    if occursin("T", expr_str) && !occursin(r"exp\s*\(\s*-.*T", expr_str)
        return true  # Temperature term without Arrhenius form
    end

    # Check reaction orders are reasonable (≤ 3 for elementary reactions)
    power_matches = collect(eachmatch(r"\^([0-9]+)", expr_str))
    for match in power_matches
        order = parse(Int, match.captures[1])
        if order > 3
            return true  # Unrealistic reaction order
        end
    end

    return false  # Expression passes all constraints
end

# Generate synthetic chemical kinetics data
n = 300
# Variables: [A], [B], T (concentrations and temperature)
conc_A = 0.1 .+ 0.9 .* rand(n)
conc_B = 0.1 .+ 0.9 .* rand(n)
T = 273 .+ 100 .* rand(n)  # Temperature in K

# True kinetics: rate = k₀ * [A]^2 * [B] * exp(-Ea/RT)
k0 = 1e6
Ea = 8314 * 50  # Activation energy
R = 8.314
rate = @. k0 * conc_A^2 * conc_B * exp(-Ea/(R*T))

X = (A=conc_A, B=conc_B, T=T)
y = rate

model = SRRegressor(
    binary_operators=[+, -, *, /, ^],
    unary_operators=[exp, log],
    maxsize=25,
    niterations=150,

    # Apply custom constraints
    constraints=chemical_constraint_function,

    # Chemical kinetics specific settings
    complexity_of_constants=2,
    complexity_of_variables=1,
    parsimony=0.01,

    # Favor physically meaningful expressions
    loss_function=:L2,
    should_simplify=true,
)

mach = machine(model, X, y)
fit!(mach)
r = report(mach)

println("Chemically constrained expression:")
println(r.equations[r.best_idx])

# Validate that result respects chemical constraints
best_expr_str = string(r.equations[r.best_idx])
println("\nConstraint validation:")
println("Has Arrhenius form: $(occursin(r"exp\s*\(\s*-.*T", best_expr_str))")
println("Reaction orders ≤ 3: $(all(parse(Int, m.captures[1]) ≤ 3 for m in eachmatch(r"\^([0-9]+)", best_expr_str)))")
```

These advanced examples demonstrate sophisticated usage patterns that help contributors understand:

1. **Multi-stage search strategies** for complex problems
2. **Custom loss functions** that encode domain knowledge
3. **Template expressions** for multi-physics systems
4. **Performance monitoring** and search diagnostics
5. **Distributed computing** for large-scale problems
6. **Integration patterns** with optimization libraries
7. **Debugging techniques** for understanding search behavior
8. **Custom constraint systems** for domain-specific applications

Each example showcases how different components of the library work together and provides patterns that can be adapted for specific research domains. The key insight is that SymbolicRegression.jl is designed as a flexible framework where the search process, evaluation methods, and constraint systems can all be customized to match the requirements of sophisticated scientific applications.
