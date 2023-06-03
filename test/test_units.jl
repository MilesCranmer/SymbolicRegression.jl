using SymbolicRegression
using SymbolicRegression.CoreModule.DatasetModule: get_units
using SymbolicRegression.CheckConstraintsModule: violates_dimensional_constraints
import Unitful: @u_str, Units, uparse
using Test

options = Options()
X = randn(3, 100)
y = @. cos(X[3, :] * 2.1 - 0.2) + 0.5

@test get_units([u"m", "1", "kg"]) == (u"m", u"1", u"kg")

@test dataset.variable_units == (u"m", u"1", u"kg")

let dataset = Dataset(X, y; variable_units=[u"m", u"1", u"kg"]),
    options = Options(; unary_operators=[cos, sin]),
    (x1, x2, x3) = (i -> Node(; feature=i)).(1:3)

    dim_cons(tree) = violates_dimensional_constraints(tree, dataset, options)

    @test dim_cons(Node(; val=3.2)) == false
    @test dim_cons(3.2 * x1 / x1) == false
    @test dim_cons(3.2 * x1 - x2) == false
end

# tree = 3.2 * x1 + cos(x2) #cos(x1 * 2.3 - 0.5) * 1.9 + 0.2 * x2
