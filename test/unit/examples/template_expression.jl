using SymbolicRegression
using MLJBase: machine, fit!
using Random

rng = Random.MersenneTwister(0)
n = 50
t = rand(rng, n)
T = rand(rng, n)

X = (; t, T)
y = sin.(t) .+ T

expression_spec = @template_spec(expressions = (f, g)) do t, T
    f(t) + g(T)
end

model = SRRegressor(;
    expression_spec,
    binary_operators=(+, -, *, /),
    unary_operators=(sin, cos, exp),
    niterations=5,
    populations=2,
    population_size=30,
    maxsize=10,
    progress=false,
)

mach = machine(model, X, y)
fit!(mach)
