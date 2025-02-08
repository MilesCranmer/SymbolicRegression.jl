using SymbolicRegression
using Random: rand
using MLJBase: machine, fit!, report, predict
using Test: @test

expression_spec = @template_spec(expressions = (f, g1, g2)) do x1, x2, x3
    _f = f(x1, x2)
    _g1 = g1(x3)
    _g2 = g2(x3)
    _out1 = _f + _g1
    _out2 = _f + _g2
    ValidVector(map(tuple, _out1.x, _out2.x), _out1.valid && _out2.valid)
end

x1 = rand(100)
x2 = rand(100)
x3 = rand(100)

# Our dataset is a vector of 2-tuples
y = [(sin(x1[i]) + x3[i]^2, sin(x1[i]) + x3[i]) for i in eachindex(x1, x2, x3)]

model = SRRegressor(;
    binary_operators=(+, *),
    unary_operators=(sin,),
    maxsize=20,
    expression_spec=expression_spec,
    # The elementwise needs to operate directly on each row of `y`:
    elementwise_loss=((x1, x2), (y1, y2)) -> (y1 - x1)^2 + (y2 - x2)^2,
    early_stop_condition=(loss, complexity) -> loss < 1e-6 && complexity <= 7,
)

mach = machine(model, [x1 x2 x3], y)
fit!(mach)

# Check the performance of the model
r = report(mach)
idx = r.best_idx
best_loss = r.losses[idx]

@test best_loss < 1e-5

# Check the expression is split up correctly:
best_expr = r.equations[idx]
best_f = get_contents(best_expr).f
best_g1 = get_contents(best_expr).g1
best_g2 = get_contents(best_expr).g2

@test best_f(x1, x2) ≈ @. sin.(x1)
@test best_g1(x3) ≈ (@. x3 * x3)
@test best_g2(x3) ≈ (@. x3)

# Test prediction
x_test = rand(10, 3)
y_test = [
    (sin(x_test[i, 1]) + x_test[i, 3]^2, sin(x_test[i, 1]) + x_test[i, 3]) for
    i in eachindex(axes(x_test, 1))
]
predictions = predict(mach, (data=x_test, idx=length(r.equations)))
@test map(first, predictions) ≈ map(first, y_test)
@test map(last, predictions) ≈ map(last, y_test)
