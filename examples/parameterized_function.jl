using SymbolicRegression
using Random: MersenneTwister
using Zygote
using MLJBase: machine, fit!, predict, report
using Test

rng = MersenneTwister(0)
X = NamedTuple{(:x1, :x2, :x3, :x4, :x5)}(ntuple(_ -> randn(rng, Float32, 30), Val(5)))
X = (; X..., classes=rand(rng, 1:2, 30))
p1 = rand(rng, Float32, 2)
p2 = rand(rng, Float32, 2)

y = [
    2 * cos(X.x4[i] + p1[X.classes[i]]) + X.x1[i]^2 - p2[X.classes[i]] for
    i in eachindex(X.classes)
]

stop_at = Ref(1e-6)

model = SRRegressor(;
    niterations=100,
    binary_operators=[+, *, /, -],
    unary_operators=[cos, exp],
    populations=30,
    expression_type=ParametricExpression,
    expression_options=(; max_parameters=2),
    autodiff_backend=:Zygote,
    parallelism=:multithreading,
    early_stop_condition=(loss, _) -> loss < stop_at[],
)

mach = machine(model, X, y)

fit!(mach)
idx1 = lastindex(report(mach).equations)
ypred1 = predict(mach, (data=X, idx=idx1))
loss1 = sum(i -> abs(ypred1[i] - y[i]), eachindex(y))

# Should keep all parameters
stop_at[] = 1e-7
fit!(mach)
idx2 = lastindex(report(mach).equations)
ypred2 = predict(mach, (data=X, idx=idx2))
loss2 = sum(i -> abs(ypred2[i] - y[i]), eachindex(y))

# Should get better:
@test loss1 >= loss2
