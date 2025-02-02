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
(_For a more complex example, see ["Searching with template expressions"](examples/template_expression.md)_)

First, let's set up our basic configuration:

```julia
using SymbolicRegression
using Random: rand, MersenneTwister
using MLJBase: machine, fit!, report
```

The key part is defining our template structure. This determines how different parts of the expression combine:

```julia
structure = TemplateStructure{(:f, :g)}(
    ((; f, g), (x1, x2, x3)) -> f(x1, x2) + g(x2) - g(x3)
)
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

Now we can set up and train our model.
Note that we pass the structure in to `expression_options`:

```julia
model = SRRegressor(;
    binary_operators=(+, -, *, /),
    unary_operators=(cos,),
    niterations=500,
    maxsize=25,
    expression_type=TemplateExpression,
    expression_options=(; structure),
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

Be sure to also check out the [Parametric Expression example](examples/parametric_expression.md).

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
using DynamicDiff: D

structure = TemplateStructure{(:f,)}(
    ((; f), (x,)) -> D(f, 1)(x)  # Differentiate `f` with respect to its first argument
)
```

We can now set up the model to find the symbolic expression for the integral:

```julia
using MLJ

model = SRRegressor(
    binary_operators=(+, -, *, /),
    unary_operators=(sqrt,),
    maxsize=20,
    expression_type=TemplateExpression,
    expression_options=(; structure),
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

## 11. Additional features

For the many other features available in SymbolicRegression.jl,
check out the API page for `Options`. You might also find it useful
to browse the documentation for the Python frontend
[PySR](http://astroautomata.com/PySR), which has additional documentation.
In particular, the [tuning page](http://astroautomata.com/PySR/tuning)
is useful for improving search performance.
