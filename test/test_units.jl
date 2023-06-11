using SymbolicRegression
using SymbolicRegression.CoreModule.DatasetModule: get_units
using SymbolicRegression.CheckConstraintsModule: violates_dimensional_constraints
import Unitful: @u_str, Units
import DynamicQuantities: Dimensions
using Test

@testset "Dimensional analysis" begin
    X = randn(3, 100)
    y = @. cos(X[3, :] * 2.1 - 0.2) + 0.5
    custom_op(x, y) = x + y
    options = Options(; binary_operators=[-, *, /, custom_op], unary_operators=[cos])
    @extend_operators options
    (x1, x2, x3) = (i -> Node(Float64; feature=i)).(1:3)

    @test get_units([u"m", "1", "kg"]) ==
        [Dimensions(; length=1), Dimensions(), Dimensions(; mass=1)]
    dataset = Dataset(X, y; variable_units=[u"m", u"1", u"kg"])
    @test dataset.variable_units ==
        [Dimensions(; length=1), Dimensions(), Dimensions(; mass=1)]

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
        custom_op(custom_op(x1, 2.1 * x3), x1),
        custom_op(custom_op(x1, 2.1 * x3), 0.9 * x1),
    ]
    bad_expressions = [
        x1 - x3,
        cos(x1),
        cos(x1 - 0.5 * x2),
        x1 - (x3 * (cos(0.9 * x1 - 0.5 * x2) - 1.2)),
        custom_op(x1, x3),
        custom_op(custom_op(x1, 2.1 * x3), x3),
        cos(0.8606301 / x1) / cos(custom_op(cos(x1), 3.2263336)),
    ]

    for expr in good_expressions
        @eval @test !$violates($expr)
    end
    for expr in bad_expressions
        @eval @test $violates($expr)
    end
end

@testset "Search with dimensional constraints" begin
    X = randn(1, 100)
    y = @. cos(X[1, :]) + X[1, :]
    dataset = Dataset(X, y; variable_units=["kg"])
    custom_op(x, y) = x + y
    options = Options(; binary_operators=[*, custom_op], unary_operators=[cos])
    @extend_operators options

    hof = EquationSearch(dataset; options)

    # Solutions should be like cos([cons] * X[1]) + [cons]*X[1]
    dominating = calculate_pareto_frontier(hof)
    best_expr = first(filter(m::PopMember -> m.loss < 1e-7, dominating)).tree

    @test !violates_dimensional_constraints(best_expr, dataset, options)
    @test compute_complexity(best_expr, options) >=
        compute_complexity(custom_op(cos(1 * x1), 1 * x1), options)

    # Check that every cos(...) which contains x1 also has complexity 
    has_cos(tree) =
        any(tree) do t
            t.degree == 1 && options.operators.unaops[t.op] == cos
        end
    valid_trees = [
        !has_cos(member.tree) || any(member.tree) do t
            if (
                t.degree == 1 &&
                options.operators.unaops[t.op] == cos &&
                Node(Float64; feature=1) in t
            )
                return compute_complexity(t, options) > 1
            end
            return false
        end for member in dominating
    ]
    @test all(valid_trees)
    @test length(valid_trees) > 0
end
