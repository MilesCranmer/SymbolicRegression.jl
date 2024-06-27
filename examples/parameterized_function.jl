using SymbolicRegression
using Random: MersenneTwister
using Zygote
using MLJBase: machine, fit!, predict, report

rng = MersenneTwister(0)
X = NamedTuple{(:x1, :x2, :x3, :x4, :x5)}(ntuple(_ -> randn(rng, Float32, 30), Val(5)))
X = (; X..., classes=rand(rng, 1:2, 30))
p1 = rand(rng, Float32, 2)
p2 = rand(rng, Float32, 2)

y = [
    2 * cos(X.x4[i] + p1[X.classes[i]]) + X.x1[i]^2 - p2[X.classes[i]] for
    i in eachindex(X.classes)
]

model = SRRegressor(;
    niterations=10,
    binary_operators=[+, *, /, -],
    unary_operators=[cos, exp],
    populations=10,
    expression_type=ParametricExpression,
    expression_options=(; max_parameters=2),
    autodiff_backend=:Zygote,
    parallelism=:multithreading,
    early_stop_condition=1e-6,
)

mach = machine(model, X, y)

fit!(mach)
idx1 = lastindex(report(mach).equations)
ypred1 = predict(mach, (data=X, idx=idx1))

# Should keep all parameters
fit!(mach)
idx2 = lastindex(report(mach).equations)
ypred2 = predict(mach, (data=X, idx=idx2))

# Should get better:
@test sum(i -> abs2(ypred1[i] - y[i]), eachindex(y)) >=
    sum(i -> abs2(ypred2[i] - y[i]), eachindex(y))
