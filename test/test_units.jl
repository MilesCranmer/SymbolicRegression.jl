using SymbolicRegression
using SymbolicRegression.CoreModule.DatasetModule: get_units
using SymbolicRegression.CheckConstraintsModule: violates_dimensional_constraints
import Unitful: @u_str, Units, uparse, FreeUnits, NoDims
using Test

X = randn(3, 100)
y = @. cos(X[3, :] * 2.1 - 0.2) + 0.5

custom_op(x, y) = x + y

options = Options(; binary_operators=[+, -, *, /, custom_op], unary_operators=[cos])
@extend_operators options

(x1, x2, x3) = (i -> Node(Float64; feature=i)).(1:3)

dimensionless = FreeUnits{(),NoDims,nothing}()
@test get_units([u"m", "1", "kg"]) == (u"m", dimensionless, u"kg")
dataset = Dataset(X, y; variable_units=[u"m", u"1", u"kg"])
@test dataset.variable_units == (u"m", dimensionless, u"kg")

violates(tree) = violates_dimensional_constraints(tree, dataset, options)

good_expressions = [
    Node(; val=3.2),
    3.2 * x1 / x1,
    3.2 * x1 - x2 * x1,
    3.2 * x1 - x2,
    cos(3.2 * x1),
    cos(0.9 * x1 - 0.5 * x2),
    x1 - 0.5 * (x3 * (cos(0.9 * x1 - 0.5 * x2) - 1.2)),
    custom_op(x1, x1),
    custom_op(x1, 2.1 * x3),
    custom_op(x1, 2.1 * x3) + x1,
    custom_op(x1, 2.1 * x3) + 0.9 * x1,
]
bad_expressions = [
    x1 - x3,
    cos(x1),
    cos(x1 - 0.5 * x2),
    x1 - (x3 * (cos(0.9 * x1 - 0.5 * x2) - 1.2)),
    custom_op(x1, x3),
    custom_op(x1, 2.1 * x3) + x3,
    cos(0.8606301 / x1) / cos(cos(x1) + 3.2263336),
]

for expr in good_expressions
    @eval @test !violates($expr)
end
for expr in bad_expressions
    @eval @test violates($expr)
end
