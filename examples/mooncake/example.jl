using SymbolicRegression, Mooncake, MLJBase, DifferentiationInterface

X = (; x=randn(100), y=randn(100), z=randn(100))
y = @. 2 * cos(X.x) + X.y^2 - 4 * X.z

expression_spec = @template_spec(expressions = (f, g), parameters = (p1=3,),) do x, y, z
    return f(x, y) + g(z) + p1[1] + p1[2]
end

model = SRRegressor(;
    binary_operators=(+, *, /, -),
    unary_operators=(cos, exp),
    autodiff_backend=AutoMooncake(; config=nothing),
    expression_spec=expression_spec,
    parallelism=:serial,
)
mach = machine(model, X, y)
fit!(mach)
