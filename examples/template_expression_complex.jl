using SymbolicRegression
using Random: AbstractRNG, default_rng, MersenneTwister
using MLJBase: machine, fit!, report
using Test: @test

function cross((a1, a2, a3), (b1, b2, b3))
    return (a2 * b3 - a3 * b2, a3 * b1 - a1 * b3, a1 * b2 - a2 * b1)
end

options = Options(; binary_operators=(+, *, /, -), unary_operators=(sin, cos))
operators = options.operators

# Inputs: time since experiment start, velocity, room temperature
variable_names = ["t", "v_x", "v_y", "v_z", "T"]

# Latents: the magnetic field (in 3D), drag force
variable_constraints = (; B_x=[1], B_y=[1], B_z=[1], F_d_scale=[5])

# Targets: the total force vector on the particle (in 3D)

# First, let's generate our example data.
function simulate(rng::AbstractRNG=default_rng())
    # Say that each time we run the experiment, the temperature is a bit different:
    T = 298.15 + 0.5 * rand(rng)

    # We run the experiment, and record the velocity at a random time
    # between 0 and 10 seconds.
    t = 10 * rand(rng)

    # We introduce a particle at a random velocity between -1 and 1
    v = ntuple(_ -> 2 * rand(rng) - 1, 3)

    ### TRUE (unknown) MODEL ###
    # The magnetic field is sinusoidal, with frequency 1 Hz,
    # along axes x and y, and decays along the z-axis.
    ω = 2π
    B = (sin(ω * t), cos(ω * t), exp(-t / 10))

    # We assume the drag force is linear in the velocity and
    # depends on the temperature with a power law.
    F_d = -1e-5 * T^(3//2) .* v #= The last part is known, though =#
    ############################

    F_mag = cross(v, B)
    F = F_d .+ F_mag

    return (; t, v, T, F, B, F_d, F_mag)
end

struct ForceVector{T}
    x::T
    y::T
    z::T
end

X, y, other = let
    rng = MersenneTwister(0)
    n = 1000
    data = [simulate(rng) for _ in 1:n]
    X = (;
        t=map(d -> d.t, data),
        v_x=map(d -> d.v[1], data),
        v_y=map(d -> d.v[2], data),
        v_z=map(d -> d.v[3], data),
        T=map(d -> d.T, data),
    )
    y = map(d -> ForceVector(d.F...), data)
    # To check our results at the end:
    other = (;
        B=map(d -> d.B, data), F_d=map(d -> d.F_d, data), F_mag=map(d -> d.F_mag, data)
    )

    X, y, other
end

structure = TemplateStructure{(:B_x, :B_y, :B_z, :F_d_scale)}(;
    combine_strings=e ->
        "\nB = ( $(e.B_x), $(e.B_y), $(e.B_z) )\nF_d = ($(e.F_d_scale)) * v",
    combine_vectors=(e, X) -> [
        let v = (X[2, i], X[3, i], X[4, i]),
            F_d = e.F_d_scale[i] .* v,
            B = (e.B_x[i], e.B_y[i], e.B_z[i]),
            F_mag = cross(v, B)

            ForceVector((F_d .+ F_mag)...)
        end for i in eachindex(axes(X, 2), e.F_d_scale, e.B_x, e.B_y, e.B_z)
    ],
    variable_constraints,
)

model = SRRegressor(;
    binary_operators=(+, -, *, /),
    unary_operators=(sin, cos, sqrt, exp),
    niterations=100,
    maxsize=30,
    expression_type=TemplateExpression,
    expression_options=(; structure),
    # The elementwise needs to operate directly on each row of `y`:
    elementwise_loss=(F1, F2) -> (F1.x - F2.x)^2 + (F1.y - F2.y)^2 + (F1.z - F2.z)^2,
)

mach = machine(model, X, y)
fit!(mach)
