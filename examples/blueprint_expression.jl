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
function my_structure(nt::NamedTuple{<:Any,<:Tuple{Vararg{<:AbstractExpression}}})
    return sin(nt.f) + nt.g * nt.g
end
# For combining numerical outputs:
function my_structure(nt::NamedTuple{<:Any,<:Tuple{Vararg{<:AbstractVector}}})
    return @. sin(nt.f) + nt.g * nt.g
end

variable_mapping = (; f=[1, 2], g=[3])

st_expr = BlueprintExpression(
    (; f=x1, g=x3); structure=my_structure, operators, variable_names, variable_mapping
)

# @test Interfaces.test(
#     ExpressionInterface,
#     BlueprintExpression,
#     [st_expr]
# )

model = SRRegressor(;
    niterations=200,
    binary_operators=(+, *, /, -),
    unary_operators=(sin, cos),
    populations=30,
    maxsize=30,
    expression_type=BlueprintExpression,
    expression_options=(; structure=my_structure, variable_mapping),
    parallelism=:multithreading,
)

X = rand(100, 3) .* 5
y = @. exp(X[:, 1]) + X[:, 3] * X[:, 3]

mach = machine(model, X, y)

fit!(mach)

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
