#! format: off
#literate_begin file=src/examples/template_expression.md
#=
# Searching with template expressions
=#
using SymbolicRegression, MLJBase, Random
using Test: @test  #src

function cross((a1, a2, a3), (b1, b2, b3))
    return (a2 * b3 - a3 * b2, a3 * b1 - a1 * b3, a1 * b2 - a2 * b1)
end

options = Options(; binary_operators=(+, *, /, -), unary_operators=(sin, cos))
operators = options.operators

#=
First, let's generate our example data.
Let's take 1000 trials:
=#
n = 1000
rng = Random.MersenneTwister(0);

#=
Say that each time we run the experiment, the temperature is a bit different:
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

Let's assume magnetic field is sinusoidal, with frequency 1 Hz,
along axes x and y, and decays over t along the z-axis.
=#
ω = 2π
B = [(sin(ω * ti), cos(ω * ti), exp(-ti / 10)) for ti in t]
B[1:3]

#=
We assume the drag force is linear in the velocity and
depends on the temperature with a power law.
=#
F_d = [-1e-5 * Ti^(3//2) .* vi for (Ti, vi) in zip(T, v)]
F_d[1:3]

#=
Now, let's compute the true magnetic force:
=#
F_mag = [cross(vi, Bi) for (vi, Bi) in zip(v, B)]
F_mag[1:3]

#=
And sum it to get the total force:
=#
F = [fd .+ fm for (fd, fm) in zip(F_d, F_mag)]
F[1:3]

#=
And some random other expression to spice things up:
=#
E = [sin(ω * ti) * cos(ω * ti) for ti in t]
E[1:3]

#=
This forms our dataset!
=#
data = (; t, v, T, F, B, F_d, F_mag, E)
keys(data)

#=
Now, let's format it for input to the regressor:
=#
X = (;
    t=data.t,
    v_x=[vi[1] for vi in data.v],
    v_y=[vi[2] for vi in data.v],
    v_z=[vi[3] for vi in data.v],
    T=data.T,
    E=data.E,
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
    E::T
end
y = [Force(F..., E) for (F, E) in zip(data.F, data.E)]
y[1:3]

#=
Our variable names are the keys of the struct:
=#
variable_names = ["t", "v_x", "v_y", "v_z", "T"]

#=
Template expressions require you to define a _structure_ function,
which describes how to combine the sub-expressions into a single
expression, numerically evaluate them, and print them.

First, let's just make a function that prints the expression:
=#
function combine_strings(e)
    # e is a named tuple of strings representing each formula
    B_x_padded = e.B_x
    B_y_padded = e.B_y
    B_z_padded = e.B_z
    return "  ╭ 𝐁 = [ $(B_x_padded) , $(B_y_padded) , $(B_z_padded) ]\n  │ 𝐅 = ($(e.F_d_scale)) * 𝐯\n  ╰ E = $(e.E)"
end

#=
So, this will just print the separate B and F_d expressions we've learned.

Then, let's define an expression that takes the numerical values
evaluated in the TemplateExpression, and combines them into the resultant
force vector. Inside this function, we can do whatever we want.
=#
function combine_vectors(e, X)
    # This time, e is a named tuple of *vectors*, representing the batched
    # evaluation of each formula.

    # First, extract the 3D velocity vectors from the input matrix:
    v = [(X[2, i], X[3, i], X[4, i]) for i in eachindex(axes(X, 2))]

    # Use this to compute the full drag force:
    F_d = [F_d_scale_i .* vi for (F_d_scale_i, vi) in zip(e.F_d_scale, v)]

    # Collect the magnetic field components that we've learned into the vector:
    B = [(bx, by, bz) for (bx, by, bz) in zip(e.B_x, e.B_y, e.B_z)]

    # Using this, we compute the magnetic force with a cross product:
    F_mag = [cross(vi, Bi) for (vi, Bi) in zip(v, B)]

    E = e.E

    # Finally, we combine the drag and magnetic forces into the total force:
    return [ForceVector((fd .+ fm)..., ei) for (fd, fm, ei) in zip(F_d, F_mag, E)]
end

#=
For the functions we wish to learn, we can constraint what variables
each of them depends on, explicitly. Let's say B only depends on time,
and the drag force scale only depends on temperature (we explicitly
multiply the velocity in).
=#
variable_constraints = (; B_x=[1], B_y=[1], B_z=[1], F_d_scale=[5], E=[1])

#=
Now, we can create our template expression:
=#
structure = TemplateStructure{(:B_x, :B_y, :B_z, :F_d_scale, :E)}(;
    combine_strings=combine_strings,
    combine_vectors=combine_vectors,
    variable_constraints=variable_constraints,
)

#=
Let's look at an example of how this would be used
in a TemplateExpression:
=#
t = Expression(Node{Float64}(; feature=1); operators, variable_names)
T = Expression(Node{Float64}(; feature=5); operators, variable_names)
B_x = B_y = B_z = 2.1 * cos(t)
F_d_scale = 1.0 * sqrt(T)
E = 2.1 * sin(t) * cos(t)

ex = TemplateExpression(
    (; B_x, B_y, B_z, F_d_scale, E);
    structure, operators, variable_names
)

#=
So we can see that it prints the expression as we've defined it.

Now, we can create a regressor that builds template expressions
which follow this structure:
=#
model = SRRegressor(;
    binary_operators=(+, -, *, /),
    unary_operators=(sin, cos, sqrt, exp),
    niterations=500,
    maxsize=35,
    expression_type=TemplateExpression,
    expression_options=(; structure=structure),
    # The elementwise needs to operate directly on each row of `y`:
    elementwise_loss=(F1, F2) ->
        (F1.x - F2.x)^2 + (F1.y - F2.y)^2 + (F1.z - F2.z)^2 + (F1.E - F2.E)^2,
    mutation_weights=MutationWeights(; rotate_tree=0.5),
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
