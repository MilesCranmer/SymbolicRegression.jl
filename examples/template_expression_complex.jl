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
B = [(sin(ω * ti), cos(ω * ti), exp(-ti / 10)) for ti in t]

# We assume the drag force is linear in the velocity and
# depends on the temperature with a power law.
F_d = [-1e-5 * Ti^(3//2) .* vi for (Ti, vi) in zip(T, v)]
############################

# Now, let's compute the true magnetic force:
F_mag = [cross(vi, Bi) for (vi, Bi) in zip(v, B)]
# And sum it to get the total force:
F = [fd .+ fm for (fd, fm) in zip(F_d, F_mag)]

# And some random other expression to spice things up:
E = [sin(ω * ti) * cos(ω * ti) for ti in t]

# This forms our dataset!
data = (; t, v, T, F, B, F_d, F_mag, E)

# Now, let's format it for input to the regressor:
X = (;
    t=data.t,
    v_x=[vi[1] for vi in data.v],
    v_y=[vi[2] for vi in data.v],
    v_z=[vi[3] for vi in data.v],
    T=data.T,
    E=data.E,
)

# We can regress directly on a struct!
struct ForceVector{T}
    x::T
    y::T
    z::T
    E::T
end
y = [ForceVector(F..., E) for (F, E) in zip(data.F, data.E)]

# Our variable names are the keys of the struct:
variable_names = ["t", "v_x", "v_y", "v_z", "T"]

# The trick is to define the right structure function.
# First, let's just make a function that prints the expression:
function combine_strings(e)
    # e is a named tuple of strings representing each formula
    B_x_padded = e.B_x
    B_y_padded = e.B_y
    B_z_padded = e.B_z
    return "  ╭ 𝐁 = [ $(B_x_padded) , $(B_y_padded) , $(B_z_padded) ]\n  │ 𝐅 = ($(e.F_d_scale)) * 𝐯\n  ╰ E = $(e.E)"
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
    F_d = [F_d_scale_i .* vi for (F_d_scale_i, vi) in zip(e.F_d_scale, v)]

    # Collect the magnetic field components that we've learned into the vector:
    B = [(bx, by, bz) for (bx, by, bz) in zip(e.B_x, e.B_y, e.B_z)]

    # Using this, we compute the magnetic force with a cross product:
    F_mag = [cross(vi, Bi) for (vi, Bi) in zip(v, B)]

    E = e.E

    # Finally, we combine the drag and magnetic forces into the total force:
    return [ForceVector((fd .+ fm)..., ei) for (fd, fm, ei) in zip(F_d, F_mag, E)]
end

# For the functions we wish to learn, we can constraint what variables
# each of them depends on, explicitly. Let's say B only depends on time,
# and the drag force scale only depends on temperature (we explicitly
# multiply the velocity in)
variable_constraints = (; B_x=[1], B_y=[1], B_z=[1], F_d_scale=[5], E=[1])

structure = TemplateStructure{(:B_x, :B_y, :B_z, :F_d_scale, :E)}(;
    combine_strings=combine_strings,
    combine_vectors=combine_vectors,
    variable_constraints=variable_constraints,
)

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
)

mach = machine(model, X, y)
fit!(mach)
