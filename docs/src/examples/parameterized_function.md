```@meta
EditURL = "../../../examples/parameterized_function.jl"
```

# Learning Parameterized Expressions

_Note: Parametric expressions are currently considered experimental and may change in the future._

Parameterized expressions in SymbolicRegression.jl allow you to discover symbolic expressions that contain
optimizable parameters. This is particularly useful when you have data that follows different patterns
based on some categorical variable, or when you want to learn an expression with constants that should
be optimized during the search.

In this tutorial, we'll generate synthetic data with class-dependent parameters and use symbolic regression to discover the parameterized expressions.

## The Problem

Let's create a synthetic dataset where the underlying function changes based on a class label:

```math
y = 2\cos(x_2 + 0.1) + x_1^2 - 3.2 \ \ \ \ \text{[class 1]} \\
\text{OR} \\
y = 2\cos(x_2 + 1.5) + x_1^2 - 0.5 \ \ \ \ \text{[class 2]}
```

We will need to simultaneously learn the symbolic expression and per-class parameters!

````@example parameterized_function
using SymbolicRegression
using Random: MersenneTwister
using MLJBase: machine, fit!, predict, report
using Test
````

Now, we generate synthetic data, with these 2 different classes.

````@example parameterized_function
X = let rng = MersenneTwister(0), n = 30
    (; x1=randn(rng, n), x2=randn(rng, n), class=rand(rng, 1:2, n))
end
````

Now, we generate target values using the true model that
has class-dependent parameters:

````@example parameterized_function
y = let P1 = [0.1, 1.5], P2 = [3.2, 0.5]
    [2 * cos(x2 + P1[class]) + x1^2 - P2[class] for (x1, x2, class) in zip(X.x1, X.x2, X.class)]
end
````

## Setting up the Search

We'll configure the symbolic regression search to
use template expressions with parameters that _vary by class_

Get number of categories from the data

````@example parameterized_function
n_categories = length(unique(X.class))
````

Create a template expression specification with 2 parameters

````@example parameterized_function
expression_spec = @template_spec(
    expressions = (f,), parameters = (p1=n_categories, p2=n_categories),
) do x1, x2, class
    f(x1, x2, p1[class], p2[class])
end

model = SRRegressor(;
    niterations=100,
    binary_operators=[+, *, /, -],
    unary_operators=[cos, exp],
    populations=30,
    expression_spec=expression_spec,
);
nothing #hide
````

Now, let's set up the machine and fit it:

````@example parameterized_function
mach = machine(model, X, y)
````

At this point, you would run:

```julia
fit!(mach)
```

You can extract the best expression and parameters with:

```julia
report(mach).equations[end]
```

---


```@raw html
<details>
<summary> Show raw source code </summary>
```

```julia
#=
# Learning Parameterized Expressions

_Note: Parametric expressions are currently considered experimental and may change in the future._

Parameterized expressions in SymbolicRegression.jl allow you to discover symbolic expressions that contain
optimizable parameters. This is particularly useful when you have data that follows different patterns
based on some categorical variable, or when you want to learn an expression with constants that should
be optimized during the search.

In this tutorial, we'll generate synthetic data with class-dependent parameters and use symbolic regression to discover the parameterized expressions.

## The Problem

Let's create a synthetic dataset where the underlying function changes based on a class label:

\```math
y = 2\cos(x_2 + 0.1) + x_1^2 - 3.2 \ \ \ \ \text{[class 1]} \\
\text{OR} \\
y = 2\cos(x_2 + 1.5) + x_1^2 - 0.5 \ \ \ \ \text{[class 2]}
\```

We will need to simultaneously learn the symbolic expression and per-class parameters!
=#
using SymbolicRegression
using Random: MersenneTwister
using Zygote  #src
using MLJBase: machine, fit!, predict, report
using Test

#=
Now, we generate synthetic data, with these 2 different classes.
=#

X = let rng = MersenneTwister(0), n = 30
    (; x1=randn(rng, n), x2=randn(rng, n), class=rand(rng, 1:2, n))
end

#=
Now, we generate target values using the true model that
has class-dependent parameters:
=#
y = let P1 = [0.1, 1.5], P2 = [3.2, 0.5]
    [2 * cos(x2 + P1[class]) + x1^2 - P2[class] for (x1, x2, class) in zip(X.x1, X.x2, X.class)]
end

#=
## Setting up the Search

We'll configure the symbolic regression search to
use template expressions with parameters that _vary by class_
=#

stop_at = Ref(1e-4)  #src

# Get number of categories from the data
n_categories = length(unique(X.class))

# Create a template expression specification with 2 parameters
expression_spec = @template_spec(
    expressions = (f,), parameters = (p1=n_categories, p2=n_categories),
) do x1, x2, class
    f(x1, x2, p1[class], p2[class])
end
test_kwargs = if get(ENV, "SYMBOLIC_REGRESSION_IS_TESTING", "false") == "true"  #src
    (;  #src
        expression_spec=ParametricExpressionSpec(; max_parameters=2),  #src
        autodiff_backend=:Zygote,  #src
    )  #src
else  #src
    NamedTuple()  #src
end  #src

model = SRRegressor(;
    niterations=100,
    binary_operators=[+, *, /, -],
    unary_operators=[cos, exp],
    populations=30,
    expression_spec=expression_spec,
    test_kwargs...,  #src
    early_stop_condition=(loss, _) -> loss < stop_at[],  #src
);

#=
Now, let's set up the machine and fit it:
=#

mach = machine(model, X, y)

#=
At this point, you would run:

\```julia
fit!(mach)
\```

You can extract the best expression and parameters with:

\```julia
report(mach).equations[end]
\```

=#
```

which uses Literate.jl to generate this page.

```@raw html
</details>
```



