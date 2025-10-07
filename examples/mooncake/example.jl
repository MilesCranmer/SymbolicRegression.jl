using SymbolicRegression, Mooncake, MLJBase, DifferentiationInterface

X = (; x=randn(100), y=randn(100), z=randn(100), w=randn(100))
y = @. 2 * cos(X.x) + X.y^2 - 4 * X.z + 3 * X.w

expression_spec = @template_spec(expressions = (f, g), parameters = (p=1,)) do x, y, z, w
    return f(x, y) + g(z) + p[1] * w
end

model = SRRegressor(;
    binary_operators=(+, *, /, -),
    unary_operators=(cos, exp),
    autodiff_backend=AutoMooncake(; config=nothing),
    expression_spec=expression_spec,
)
mach = machine(model, X, y)
fit!(mach)
