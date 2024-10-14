using SymbolicRegression
using DynamicExpressions:
    DynamicExpressions as DE,
    Metadata,
    get_tree,
    get_operators,
    get_variable_names,
    OperatorEnum,
    AbstractExpression
using Random: MersenneTwister
using MLJBase: machine, fit!, predict, report
using Test

using DynamicExpressions.InterfacesModule: Interfaces, ExpressionInterface

# Impose structure:
#   Function f(x1, x2)
#   Function g(x3)
#   y = sin(f) + g^2
operators = OperatorEnum(; binary_operators=(+, *, /, -), unary_operators=(sin, cos))
variable_names = (i -> "x$i").(1:3)
x1, x2, x3 = (i -> Expression(Node(Float64; feature=i); operators, variable_names)).(1:3)

# For combining expressions to a single expression:
function my_structure(nt::NamedTuple{<:Any,<:Tuple{Vararg{<:AbstractString}}})
    return "( $(nt.f) + $(nt.g1), $(nt.f) + $(nt.g2), $(nt.f) + $(nt.g3) )"
end
function my_structure(nt::NamedTuple{<:Any,<:Tuple{Vararg{<:AbstractVector}}})
    return map(
        i -> (nt.f[i] + nt.g1[i], nt.f[i] + nt.g2[i], nt.f[i] + nt.g3[i]), eachindex(nt.f)
    )
end

variable_mapping = (; f=[1, 2], g1=[3], g2=[3], g3=[3])

st_expr = TemplateExpression(
    (; f=x1, g1=x3, g2=x3, g3=x3);
    structure=my_structure,
    operators,
    variable_names,
    variable_mapping,
)

# @test Interfaces.test(
#     ExpressionInterface,
#     TemplateExpression,
#     [st_expr]
# )

model = SRRegressor(;
    niterations=200,
    binary_operators=(+, *, /, -),
    unary_operators=(sin, cos),
    populations=30,
    maxsize=30,
    expression_type=TemplateExpression,
    expression_options=(; structure=my_structure, variable_mapping),
    parallelism=:multithreading,
    elementwise_loss=((x1, x2, x3), (y1, y2, y3)) ->
        (y1 - x1)^2 + (y2 - x2)^2 + (y3 - x3)^2,
)

X = rand(100, 3)
y = [
    (sin(X[i, 1]) + X[i, 3]^2, sin(X[i, 2]) + X[i, 3]^2, sin(X[i, 3]) + X[i, 3]^2) for
    i in eachindex(axes(X, 1))
]

dataset = Dataset(X', y)

mach = machine(model, X, y)
fit!(mach)

println("hello")

# using Profile
# Profile.init(n=10^8, delay=1e-4)
# mach = machine(model, X, y)
# @profile fit!(mach, verbosity=0)
# Profile.clear()
# mach = machine(model, X, y)
# @profile fit!(mach)

# using PProf
# pprof()
# idx1 = lastindex(report(mach).equations)
# ypred1 = predict(mach, (data=X, idx=idx1))
# loss1 = sum(i -> abs2(ypred1[i] - y[i]), eachindex(y))

# # Should keep all parameters
# stop_at[] = 1e-5
# fit!(mach)
# idx2 = lastindex(report(mach).equations)
# ypred2 = predict(mach, (data=X, idx=idx2))
# loss2 = sum(i -> abs2(ypred2[i] - y[i]), eachindex(y))

# # Should get better:
# @test loss1 >= loss2
