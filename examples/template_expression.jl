using SymbolicRegression
using Random: rand
using MLJBase: machine, fit!, report
using Test: @test

options = Options(; binary_operators=(+, *, /, -), unary_operators=(sin, cos))
operators = options.operators
variable_names = (i -> "x$i").(1:3)
x1, x2, x3 = (i -> Expression(Node(Float64; feature=i); operators, variable_names)).(1:3)

structure = TemplateStructure{(:f, :g1, :g2)}(;
    combine_vectors=e -> map((f, g1, g2) -> (f + g1, f + g2), e.f, e.g1, e.g2),
    combine_strings=e -> "( $(e.f) + $(e.g1), $(e.f) + $(e.g2) )",
    variable_constraints=(; f=[1, 2], g1=[3], g2=[3]),
)

st_expr = TemplateExpression((; f=x1, g1=x3, g2=x3); structure, operators, variable_names)

X = rand(100, 3) .* 10

# Our dataset is a vector of 2-tuples
y = [(sin(X[i, 1]) + X[i, 3]^2, sin(X[i, 1]) + X[i, 3]) for i in eachindex(axes(X, 1))]

model = SRRegressor(;
    binary_operators=(+, *),
    unary_operators=(sin,),
    maxsize=15,
    expression_type=TemplateExpression,
    expression_options=(; structure),
    # The elementwise needs to operate directly on each row of `y`:
    elementwise_loss=((x1, x2), (y1, y2)) -> (y1 - x1)^2 + (y2 - x2)^2,
    early_stop_condition=(loss, complexity) -> loss < 1e-5 && complexity <= 7,
)

mach = machine(model, X, y)
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

@test best_f(X') ≈ (@. sin(X[:, 1]))
@test best_g1(X') ≈ (@. X[:, 3] * X[:, 3])
@test best_g2(X') ≈ (@. X[:, 3])
