# Toy Examples with Code

## Preamble

```julia
using SymbolicRegression
using DataFrames
```

We'll also code up a simple function to print a single expression:

```julia
function get_best(; hof::HallOfFame{T,L}, options) where {T,L}
    dominating = calculate_pareto_frontier(hof)

    df = DataFrame(;
        tree=[m.tree for m in dominating],
        loss=[m.loss for m in dominating],
        complexity=[compute_complexity(m, options) for m in dominating],
    )

    df[!, :score] = vcat(
        [L(0.0)],
        -1 .* log.(df.loss[2:end] ./ df.loss[1:(end - 1)]) ./
        (df.complexity[2:end] .- df.complexity[1:(end - 1)]),
    )

    min_loss = min(df.loss...)

    best_idx = argmax(df.score .* (df.loss .<= (2 * min_loss)))

    return df.tree[best_idx], df
end
```

## 1. Simple search

Here's a simple example where we
find the expression `2 cos(x3) + x0^2 - 2`.

```julia
X = 2randn(5, 1000)
y = @. 2*cos(X[4, :]) + X[1, :]^2 - 2

options = Options(; binary_operators=[+, -, *, /], unary_operators=[cos])
hof = EquationSearch(X, y; options=options, niterations=30)
```

Let's look at the most accurate expression:

```julia
best, df = get_best(; hof, options)
println(best)
```

## 2. Custom operator

Here, we define a custom operator and use it to find an expression:

```julia
X = 2randn(5, 1000)
y = @. 1/X[1, :]

options = Options(; binary_operators=[+, *], unary_operators=[inv])
hof = EquationSearch(X, y; options=options)
println(get_best(; hof, options)[1])
```

## 3. Multiple outputs

Here, we do the same thing, but with multiple expressions at once,
each requiring a different feature.

```julia
X = 2rand(5, 1000) .+ 0.1
y = @. 1/X[1:3, :]
options = Options(; binary_operators=[+, *], unary_operators=[inv])
hofs = EquationSearch(X, y; options=options)
bests = [get_best(; hof=hofs[i], options)[1] for i=1:3]
println(bests)
```

## 4. Plotting an expression

For now, let's consider the expressions for output 1.
We can see the SymbolicUtils version with:

```julia
using SymbolicUtils

eqn = node_to_symbolic(bests[1], options)
```

We can get the LaTeX version with:

```julia
using Latexify
latexify(string(eqn))
```

Let's plot the prediction against the truth:

```julia
using Plots

scatter(y[1, :], bests[1](X), xlabel="Truth", ylabel="Prediction")
```

Here, we have used the convenience function `(::Node{T})(X)` to evaluate
the expression. However, this will only work because calling `Options()`
will automatically set up calls to `eval_tree_array`. In practice, you should
use the `eval_tree_array` function directly, which is the form of:

```julia
eval_tree_array(bests[1], X, options)
```

## 5. Other types

SymbolicRegression.jl can handle most numeric types you wish to use.
For example, passing a `Float32` array will result in the search using
32-bit precision everywhere in the codebase:

```julia
X = 2randn(Float32, 5, 1000)
y = @. 2*cos(X[4, :]) + X[1, :]^2 - 2

options = Options(; binary_operators=[+, -, *, /], unary_operators=[cos])
hof = EquationSearch(X, y; options=options, niterations=30)
```

we can see that the output types are `Float32`:

```julia
best, df = get_best(; hof, options)
println(typeof(best))
# Node{Float32}
```

We can also use `Complex` numbers:

```julia
cos_re(x::Complex{T}) where {T} = cos(abs(x)) + 0im

X = 15 .* rand(ComplexF64, 5, 1000) .- 7.5
y = @. 2*cos_re((2+1im) * X[4, :]) + 0.1 * X[1, :]^2 - 2

options = Options(; binary_operators=[+, -, *, /], unary_operators=[cos_re], maxsize=30)
hof = EquationSearch(X, y; options=options, niterations=100)
```

## 6. Additional features

For the many other features available in SymbolicRegression.jl,
check out the API page for `Options`. You might also find it useful
to browse the documentation for the Python frontend
[PySR](http://astroautomata.com/PySR), which has additional documentation.
In particular, the [tuning page](http://astroautomata.com/PySR/tuning)
is useful for improving search performance.

