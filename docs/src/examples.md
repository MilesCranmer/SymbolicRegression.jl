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
    expression_options=(
        structure=TemplateStructure(),
        variable_constraints=Dict(1 => [1, 2], 2 => [2])
    )
)

# Create expression nodes with constraints
operators = options.operators
variable_names = ["x1", "x2"]
x1 = Expression(
    Node{Float64}(feature=1),
    operators=operators,
    variable_names=variable_names,
    structure=options.expression_options.structure
)
x2 = Expression(
    Node{Float64}(feature=2),
    operators=operators,
    variable_names=variable_names,
    structure=options.expression_options.structure
)

# Construct and evaluate expression
expr = x1 * cos(x2 - 3.2)
X = rand(Float64, 2, 100)
output = expr(X)
```

This `Expression` type, contains both the structure
and the operators used in the expression. These are what
are returned by the search. The raw `Node` type (which is
what used to be output directly) is accessible with

```julia
get_contents(expr)
```

## 8. Parametric Expressions

Parametric expressions allow the algorithm to optimize parameters within the expressions during the search process. This is useful for finding expressions that not only fit the data but also have tunable parameters.

To use this, the data needs to have information on which class
each row belongs to --- this class information will be used to
select the parameters when evaluating each expression.

For example:

```julia
using SymbolicRegression
using MLJ

# Define the dataset
X = NamedTuple{(:x1, :x2)}(ntuple(_ -> randn(Float32, 30), Val(2)))
X = (; X..., classes=rand(1:2, 30))
p1 = [0.0f0, 3.2f0]
p2 = [1.5f0, 0.5f0]

y = [
    2 * cos(X.x1[i] + p1[X.classes[i]]) + X.x2[i]^2 - p2[X.classes[i]] for
    i in eachindex(X.classes)
]

# Define the model with parametric expressions
model = SRRegressor(
    niterations=100,
    binary_operators=[+, *, /, -],
    unary_operators=[cos],
    expression_type=ParametricExpression,
    expression_options=(; max_parameters=2),
    parallelism=:multithreading
)

# Train the model
mach = machine(model, X, y)
fit!(mach)

# View the best expression
report(mach)
```

The final equations will contain parameters that were optimized during training:

```julia
eq = report(mach).equations[end]

typeof(eq)
```

We can also access the parameters of the expression with:

```julia
get_metadata(eq).parameters
```

This example demonstrates how to set up a symbolic regression model that searches for expressions with parameters, optimizing both the structure and the parameters of the expressions based on the provided class information.

## 9. Additional features

For the many other features available in SymbolicRegression.jl,
check out the API page for `Options`. You might also find it useful
to browse the documentation for the Python frontend
[PySR](http://astroautomata.com/PySR), which has additional documentation.
In particular, the [tuning page](http://astroautomata.com/PySR/tuning)
is useful for improving search performance.

## 10. Template Expressions

Template expressions allow you to define structured expressions where different parts can be constrained to use specific variables. In this example, we'll create expressions that output pairs of values.

First, let's set up our basic configuration:

```julia
using SymbolicRegression
using Random: rand
using MLJBase: machine, fit!, report

options = Options(
    binary_operators=(+, *, /, -),
    unary_operators=(sin, cos)
)
operators = options.operators
variable_names = ["x1", "x2", "x3"]
```

Now we'll create base expressions for each variable:

```julia
x1, x2, x3 = [
    Expression(
        Node{Float64}(feature=i);
        operators=operators,
        variable_names=variable_names
    )
    for i in 1:3
]
```

The key part is defining our template structure. This determines how different parts of the expression combine:

```julia
structure = TemplateStructure{(:f, :g1, :g2)}(;
    # Define how to combine vectors of evaluated expressions
    combine_vectors=e -> map(
        (f, g1, g2) -> (f + g1, f + g2),
        e.f, e.g1, e.g2
    ),
    # Define how to combine strings for printing
    combine_strings=e -> "( $(e.f) + $(e.g1), $(e.f) + $(e.g2) )",
    # Constrain which variables can be used in each part
    variable_constraints=(; f=[1, 2], g1=[3], g2=[3])
)
```

Let's generate some example data:

```julia
X = rand(100, 3) .* 10
# Create pairs of target expressions
y = [
    (sin(X[i, 1]) + X[i, 3]^2, sin(X[i, 1]) + X[i, 3])
    for i in eachindex(axes(X, 1))
]
```

Now we can set up and train our model:

```julia
model = SRRegressor(;
    binary_operators=(+, *),
    unary_operators=(sin,),
    maxsize=25,
    expression_type=TemplateExpression,
    # Pass options used to instantiate expressions
    expression_options=(; structure),
    # Our `y` is 2-tuple of values
    elementwise_loss=((x1, x2), (y1, y2)) -> (y1 - x1)^2 + (y2 - x2)^2
)

mach = machine(model, X, y)
fit!(mach)
```

After training, we can examine the best expression:

```julia
r = report(mach)
best_expr = r.equations[r.best_idx]

# Access individual parts of the template expression
f_part = get_contents(best_expr).f    # Expression using x1 or x2
g1_part = get_contents(best_expr).g1  # Expression using x3
g2_part = get_contents(best_expr).g2  # Expression using x3
```

The above code demonstrates how template expressions can be used to:

- Define structured expressions with multiple components
- Constrains which variables can be used in each component
- Create expressions that can output multiple values

You can even output custom structs - see the more detailed Template Expression example!
