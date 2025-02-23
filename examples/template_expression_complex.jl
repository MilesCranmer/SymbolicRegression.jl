#! format: off
#literate_begin file="src/examples/template_expression.md"
#=
# Searching with template expressions

Template expressions are a powerful feature in SymbolicRegression.jl that allow you to impose structure
on the symbolic regression search. Rather than searching for a completely free-form expression, you can
specify a template that combines multiple sub-expressions in a prescribed way.

This is particularly useful when any of the following are true:
- You have domain knowledge about the functional form of your solution
- You want to learn expressions for a vector-valued output
- You need to enforce constraints on which variables can appear in different parts of the expression
- You want to share sub-expressions between multiple components

For example, you might know that your system follows a pattern like:
`sin(f(x1, x2)) + g(x3)^2`
where `f` and `g` are unknown functions you want to learn. With template expressions, you can encode
this structure while still letting the symbolic regression search discover the optimal form of the
sub-expressions.

In this tutorial, we'll walk through a complete example of using template expressions to learn
the components of a particle's motion under magnetic and drag forces. We'll see how to:

1. Define the structure of our template
2. Specify constraints on which variables each sub-expression can access
3. Set up the symbolic regression search
4. Interpret and use the results

Let's get started!
=#
using SymbolicRegression
using SymbolicRegression: ValidVector
using Random
using MLJBase: machine, fit!, predict, report

#=

## The Physical Problem

We'll study a charged particle moving through a magnetic field with temperature-dependent drag.
The total force on the particle will have two components:

```math
\mathbf{F} = \mathbf{F}_\text{drag} + \mathbf{F}_\text{magnetic} = -\eta(T)\mathbf{v} + q \mathbf{v} \times \mathbf{B}(t)
```
where we will take ``q = 1`` for simplicity.

From physics, we know:
- The magnetic force comes from a cross product with the field: ``\mathbf{F}_\text{magnetic} = \mathbf{v} \times \mathbf{B}``
- The drag force opposes motion, and we'll define a simple model for it: ``\mathbf{F}_\text{drag} = -\eta(T)\mathbf{v}``

Now, the parts of this model we don't know:
- The magnetic field ``\mathbf{B}(t)`` varies in time throughout the experiment, but this pattern repeats for each experiment. We want to learn the components of this field, symbolically!
- The drag coefficient ``\eta(T)`` depends only on temperature. We also want to figure out what this is!

We'll generate synthetic data from a known model and then try to rediscover these relationships,
**only knowing the total force** on a particle for a given experiment, as well as the input variables:
time, velocity, and temperature.
We will do this with template expressions to encode the physical structure of the problem.

Let's say we run this experiment 1000 times:
=#
n = 1000
rng = Random.MersenneTwister(0);

#=
Each time we run the experiment, the temperature is a bit different:
=#
T = 298.15 .+ 0.5 .* rand(rng, n)
T[1:3]

#=
We run the experiment, and record the velocity at a random time
between 0 and 10 seconds.
=#
t = 10 .* rand(rng, n)
t[1:3]

#=
We introduce a particle at a random velocity between -1 and 1
=#
v = [ntuple(_ -> 2 * rand(rng) - 1, 3) for _ in 1:n]
v[1:3]

#=
**Now, let's create the true unknown model.**

Let's assume the magnetic field is sinusoidal with frequency 1 Hz along axes x and y,
and decays exponentially along the z-axis:

```math
\mathbf{B}(t) = \begin{pmatrix}
\sin(\omega t) \\
\cos(\omega t) \\
e^{-t/10}
\end{pmatrix}
\quad \text{where} \quad \omega = 2\pi
```

This gives us a rotating magnetic field in the x-y plane that weakens along z:
=#
omega = 2π
B = [(sin(omega * ti), cos(omega * ti), exp(-ti / 10)) for ti in t]
B[1:3]

#=
We assume the drag force is linear in the velocity and
depends on the temperature with a power law:

```math
\mathbf{F}_\text{drag} = -\alpha T^{1/2} \mathbf{v}
\quad \text{where} \quad \alpha = 10^{-5}
```

This creates a temperature-dependent damping effect:
=#
F_d = [-1e-5 * Ti^(1//2) .* vi for (Ti, vi) in zip(T, v)]
F_d[1:3]

#=
Now, let's compute the true magnetic force, in 3D:
=#
cross((a1, a2, a3), (b1, b2, b3)) = (a2 * b3 - a3 * b2, a3 * b1 - a1 * b3, a1 * b2 - a2 * b1)
F_mag = [cross(vi, Bi) for (vi, Bi) in zip(v, B)]
F_mag[1:3]

#=
We then sum these to get the total force:
=#
F = [fd .+ fm for (fd, fm) in zip(F_d, F_mag)]
F[1:3]

#=
This forms our dataset!
=#
data = (; t, v, T, F, B, F_d, F_mag)
keys(data)

#=
Now, let's format the input variables for input to the regressor:
=#
X = (;
    t=data.t,
    v_x=[vi[1] for vi in data.v],
    v_y=[vi[2] for vi in data.v],
    v_z=[vi[3] for vi in data.v],
    T=data.T,
)
keys(X)

#=
Template expressions allow us to regress directly on a struct,
so here we can define a `Force` type:
=#
struct Force{T}
    x::T
    y::T
    z::T
end
y = [Force(F...) for F in data.F]
y[1:3]

#=
Our input variable names are as follows:
=#
variable_names = ["t", "v_x", "v_y", "v_z", "T"]

#=
Template expressions require you to define a _structure_ function,
which describes how to combine the sub-expressions into a single
expression, numerically evaluate them, and print them.
These are evaluated using `ComposableExpression` for the individual
subexpressions (which allow them to be composed into new expressions),
and `ValidVector` for carrying through evaluation results.

Let's define our structure function. Note that this takes two arguments,
one being a named tuple of our expressions (`::ComposableExpression`), and the other being a tuple
of the input variables (`::ValidVector`).
=#
function compute_force((; B_x, B_y, B_z, F_d_scale), (t, v_x, v_y, v_z, T))
    ## First, we evaluate each subexpression on the variables we wish
    ## to have each depend on:
    _B_x = B_x(t)
    _B_y = B_y(t)
    _B_z = B_z(t)
    _F_d_scale = F_d_scale(T)
    ## Note that we can also evaluate an expression multiple times,
    ## including in a hierarchy!

    ## Now, let's do the same computation we did above to
    ## get the total force vectors. Note that the evaluation
    ## output is wrapped in `ValidVector`, so we need
    ## to extract the `.x` to get raw vectors:
    B = [(bx, by, bz) for (bx, by, bz) in zip(_B_x.x, _B_y.x, _B_z.x)]
    v = [(vx, vy, vz) for (vx, vy, vz) in zip(v_x.x, v_y.x, v_z.x)]


    ## Now, let's compute the drag force using our model:
    F_d = [_F_d_scale .* vi for (vi, _F_d_scale) in zip(v, _F_d_scale.x)]

    ## Now, the magnetic force:
    F_mag = [cross(vi, Bi) for (vi, Bi) in zip(v, B)]

    ## Finally, we combine the drag and magnetic forces into the total force:
    F = [Force((fd .+ fm)...) for (fd, fm) in zip(F_d, F_mag)]

    ## The output of this function needs to be another `ValidVector`,
    ## which carries through the validity of the evaluation. We compute
    ## this below.
    ValidVector(F, _B_x.valid && _B_y.valid && _B_z.valid && _F_d_scale.valid)
    ## (Note that if you were doing operations that could not handle NaNs,
    ## you may need to return early - just be sure to also return the `ValidVector`!)
end

#=
Note above that we have constrained what variables each subexpression depends on.

We have constrained the magnetic field to only depend on time,
and the drag force scale to only depend on temperature.
The other variables we simply pass through and use in the evaluation.

Now, we can create our template expression, with the
subexpression symbols we wish to learn:
=#
structure = TemplateStructure{(:B_x, :B_y, :B_z, :F_d_scale)}(compute_force)

#=
Note that we could have also used the `@template_spec` macro which is
more convenient.

First, let's look at an example of how this would be used
in a TemplateExpression, for some guess at the form of
the solution:
=#
options = Options(; binary_operators=(+, *, /, -), unary_operators=(sin, cos, sqrt, exp))
## The inner operators are an `DynamicExpressions.OperatorEnum` which is used by `Expression`:
operators = options.operators
t = ComposableExpression(Node{Float64}(; feature=1); operators, variable_names)
T = ComposableExpression(Node{Float64}(; feature=5); operators, variable_names)
B_x = B_y = B_z = 2.1 * cos(t)
F_d_scale = 1.0 * sqrt(T)

ex = TemplateExpression(
    (; B_x, B_y, B_z, F_d_scale);
    structure, operators, variable_names
)

#=
So we can see that it prints the expression as we've defined it.

Now, we can create a regressor that builds template expressions
which follow this structure!
=#
model = SRRegressor(;
    binary_operators=(+, -, *, /),
    unary_operators=(sin, cos, sqrt, exp),
    niterations=500,
    maxsize=35,
    expression_spec=TemplateExpressionSpec(; structure),
    ## Note that the elementwise loss needs to operate directly on each row of `y`:
    elementwise_loss=(F1, F2) -> (F1.x - F2.x)^2 + (F1.y - F2.y)^2 + (F1.z - F2.z)^2,
    batching=true,
    batch_size=30,
);

#=
Note how we also have to define the custom `elementwise_loss`
function. This is because our `combine_vectors` function
returns a `Force` struct, so we need to combine it against the truth!

Next, we can set up our machine and fit:
=#

mach = machine(model, X, y)

#=
At this point, you would run:
```julia
fit!(mach)
```

which should print using your `combine_strings` function
during the search. The final result is accessible with:
```julia
report(mach)
```
which would return a named tuple of the fitted results,
including the `.equations` field, which is a vector
of `TemplateExpression` objects that dominated the Pareto front.
=#
#literate_end
#! format: on

fit!(mach)
