using SymbolicRegression
using Random: AbstractRNG, default_rng, MersenneTwister
using MLJBase: machine, fit!, report
using Test: @test

function cross((a1, a2, a3), (b1, b2, b3))
    return (a2 * b3 - a3 * b2, a3 * b1 - a1 * b3, a1 * b2 - a2 * b1)
end

options = Options(; binary_operators=(+, *, /, -), unary_operators=(sin, cos))
operators = options.operators

# First, let's generate our example data.
# Let's take 1000 trials:
n = 1000
rng = MersenneTwister(0)

# Say that each time we run the experiment, the temperature is a bit different:
T = 298.15 .+ 0.5 .* rand(rng, n)

# We run the experiment, and record the velocity at a random time
# between 0 and 10 seconds.
t = 10 .* rand(rng, n)

# We introduce a particle at a random velocity between -1 and 1
v = [ntuple(_ -> 2 * rand(rng) - 1, 3) for _ in 1:n]

### TRUE (unknown) MODEL ###
# Let's assume magnetic field is sinusoidal, with frequency 1 Hz,
# along axes x and y, and decays over t along the z-axis.
ω = 2π
B = map(ti -> (sin(ω * ti), cos(ω * ti), exp(-ti / 10)), t)

# We assume the drag force is linear in the velocity and
# depends on the temperature with a power law.
F_d = map((Ti, vi) -> -1e-5 .* Ti^(3//2) .* v, T, v)
############################

# Now, let's compute the true magnetic force:
F_mag = map(cross, v, B)
# And sum it to get the total force:
F = F_d .+ F_mag

# This forms our dataset!
data = (; t, v, T, F, B, F_d, F_mag)

# Now, let's format it for input to the regressor:
X = (;
    t=map(d -> d.t, data),
    v_x=map(d -> d.v[1], data),
    v_y=map(d -> d.v[2], data),
    v_z=map(d -> d.v[3], data),
    T=map(d -> d.T, data),
)

# We can regress directly on a struct!
struct ForceVector{T}
    x::T
    y::T
    z::T
end
y = map(d -> ForceVector(d.F...), data)

# Our variable names are the keys of the struct:
variable_names = ["t", "v_x", "v_y", "v_z", "T"]

# The trick is to define the right structure function.
# First, let's just make a function that prints the expression:
function combine_strings(e)
    # e is a named tuple of strings representing each formula
    return "\nB = ( $(e.B_x), $(e.B_y), $(e.B_z) )\nF_d = ($(e.F_d_scale)) * v"
end

# So, this will just print the separate B and F_d expressions we've learned.

# Then, let's define an expression that takes the numerical values
# evaluated in the TemplateExpression, and combines them into the resultant
# force vector. Inside this function, we can do whatever we want.

function combine_vectors(e, X)
    # This time, e is a named tuple of *vectors*, representing the batched
    # evaluation of each formula.

    # First, extract the 3D velocity vectors from the input matrix:
    v = [(X[2, i], X[3, i], X[4, i]) for i in eachindex(axes(X, 2))]

    # Use this to compute the full drag force:
    F_d = [e.F_d_scale[i] .* v[i] for i in eachindex(v)]

    # Collect the magnetic field components that we've learned into the vector:
    B = [(e.B_x[i], e.B_y[i], e.B_z[i]) for i in eachindex(e.B_x)]

    # Using this, we compute the magnetic force with a cross product:
    F_mag = [cross(v[i], B[i]) for i in eachindex(v)]

    # Finally, we combine the drag and magnetic forces into the total force:
    return [ForceVector((F_d[i] .+ F_mag[i])...) for i in eachindex(F_d)]
end

# For the functions we wish to learn, we can constraint what variables
# each of them depends on, explicitly. Let's say B only depends on time,
# and the drag force scale only depends on temperature (we explicitly
# multiply the velocity in)
variable_constraints = (; B_x=[1], B_y=[1], B_z=[1], F_d_scale=[5])

structure = TemplateStructure{(:B_x, :B_y, :B_z, :F_d_scale)}(;
    combine_strings=combine_strings,
    combine_vectors=combine_vectors,
    variable_constraints=variable_constraints,
)

model = SRRegressor(;
    binary_operators=(+, -, *, /),
    unary_operators=(sin, cos, sqrt, exp),
    niterations=100,
    maxsize=30,
    expression_type=TemplateExpression,
    expression_options=(; structure=structure),
    # The elementwise needs to operate directly on each row of `y`:
    elementwise_loss=(F1, F2) -> (F1.x - F2.x)^2 + (F1.y - F2.y)^2 + (F1.z - F2.z)^2,
)

mach = machine(model, X, y)
fit!(mach)
