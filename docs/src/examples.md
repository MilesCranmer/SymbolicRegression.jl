# Toy Examples with Code

```julia
using SymbolicRegression
using MLJ
```

## 1. Simple search

Here's a simple example where we
find the expression `2 cos(x3) + x0^2 - 2`.

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

eqn = node_to_symbolic(r.equations[1][r.best_idx[1]], model)
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
# Node{Float32}
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
our penalty are dimensionally consistent! (The `"[⋅]"` indicates free units in a constant,
which can cancel out other units in the expression.) For example,

```julia
"y[m s⁻² kg] = (M[kg] * 2.6353e-22[⋅])"
```

would indicate that the expression is dimensionally consistent, with
a constant `"2.6353e-22[m s⁻²]"`.

## 7. Additional features

For the many other features available in SymbolicRegression.jl,
check out the API page for `Options`. You might also find it useful
to browse the documentation for the Python frontend
[PySR](http://astroautomata.com/PySR), which has additional documentation.
In particular, the [tuning page](http://astroautomata.com/PySR/tuning)
is useful for improving search performance.
