@testitem "Dimensional analysis" tags = [:part3] begin
    using SymbolicRegression
    using SymbolicRegression.InterfaceDynamicQuantitiesModule: get_units
    using SymbolicRegression.DimensionalAnalysisModule: violates_dimensional_constraints
    using DynamicQuantities
    using DynamicQuantities: DEFAULT_DIM_BASE_TYPE

    X = randn(3, 100)
    y = @. cos(X[3, :] * 2.1 - 0.2) + 0.5

    custom_op(x, y) = x + y
    options = Options(;
        binary_operators=[-, *, /, custom_op, ^],
        unary_operators=[cos, cbrt, sqrt, abs, inv],
    )
    @extend_operators options

    (x1, x2, x3) = (i -> Node(Float64; feature=i)).(1:3)

    D = Dimensions{DEFAULT_DIM_BASE_TYPE}
    SD = SymbolicDimensions{DEFAULT_DIM_BASE_TYPE}

    @test get_units(Float64, D, [u"m", "1", "kg"], uparse) ==
        [Quantity(1.0; length=1), Quantity(1.0), Quantity(1.0; mass=1)]
    @test get_units(Float64, SD, [us"m", "1", "kg"], sym_uparse) == [
        Quantity(1.0, SymbolicDimensions; m=1),
        Quantity(1.0, SymbolicDimensions),
        Quantity(1.0, SymbolicDimensions; kg=1),
    ]
    # Various input types:
    @test get_units(Float64, SD, [us"m", 1.5, SD()], sym_uparse) == [
        Quantity(1.0, SymbolicDimensions; m=1),
        Quantity(1.5, SymbolicDimensions),
        Quantity(1.0, SymbolicDimensions),
    ]
    @test get_units(Float64, SD, [""], sym_uparse) == [Quantity(1.0, SymbolicDimensions)]
    # Bad unit types:
    @test_throws ErrorException get_units(Float64, D, (; X=[1, 2]), uparse)

    # Dataset creation:
    dataset = Dataset(X, y; X_units=[u"m", u"1", u"kg"], y_units=u"1")
    @test dataset.X_units == [Quantity(1.0; length=1), Quantity(1.0), Quantity(1.0; mass=1)]
    @test dataset.X_sym_units == [
        Quantity(1.0, SymbolicDimensions; m=1),
        Quantity(1.0, SymbolicDimensions),
        Quantity(1.0, SymbolicDimensions; kg=1),
    ]
    @test dataset.y_sym_units == Quantity(1.0, SymbolicDimensions)
    @test dataset.y_units == Quantity(1.0)

    violates(tree) = violates_dimensional_constraints(tree, dataset, options)

    good_expressions = [
        Node(; val=3.2),
        3.2 * x1 / x1,
        1.0 * (3.2 * x1 - x2 * x1),
        3.2 * x1 - x2,
        cos(3.2 * x1),
        cos(0.9 * x1 - 0.5 * x2),
        1.0 * (x1 - 0.5 * (x3 * (cos(0.9 * x1 - 0.5 * x2) - 1.2))),
        1.0 * (custom_op(x1, x1)),
        1.0 * (custom_op(x1, 2.1 * x3)),
        1.0 * (custom_op(custom_op(x1, 2.1 * x3), x1)),
        1.0 * (custom_op(custom_op(x1, 2.1 * x3), 0.9 * x1)),
        x2,
        1.0 * x1,
        1.0 * x3,
        (1.0 * x1)^(Node(; val=3.2)),
        1.0 * (cbrt(x3 * x3 * x3) - x3),
        1.0 * (sqrt(x3 * x3) - x3),
        1.0 * (sqrt(abs(x3) * abs(x3)) - x3),
        inv(x2),
        1.0 * inv(x1),
        x3 * inv(x3),
    ]
    bad_expressions = [
        x1,
        x3,
        x1 - x3,
        1.0 * cos(x1),
        1.0 * cos(x1 - 0.5 * x2),
        1.0 * (x1 - (x3 * (cos(0.9 * x1 - 0.5 * x2) - 1.2))),
        1.0 * custom_op(x1, x3),
        1.0 * custom_op(custom_op(x1, 2.1 * x3), x3),
        1.0 * cos(0.8606301 / x1) / cos(custom_op(cos(x1), 3.2263336)),
        1.0 * (x1^(Node(; val=3.2))),
        1.0 * ((1.0 * x1)^x1),
        1.0 * (cbrt(x3 * x3) - x3),
        1.0 * (sqrt(abs(x3)) - x3),
        inv(x3),
        inv(x1),
        x1 * inv(x3),
    ]

    for expr in good_expressions
        @test !violates(expr) || @show expr
    end
    for expr in bad_expressions
        @test violates(expr) || @show expr
    end
end

@testitem "Search with dimensional constraints" tags = [:part3] begin
    using SymbolicRegression
    using SymbolicRegression.DimensionalAnalysisModule: violates_dimensional_constraints
    using Random: MersenneTwister

    rng = MersenneTwister(0)
    X = rand(rng, 1, 128) .* 20
    y = @. cos(X[1, :]) + X[1, :]
    dataset = Dataset(X, y; X_units=["kg"], y_units="1")
    custom_op(x, y) = x + y
    options = Options(;
        binary_operators=[-, *, /, custom_op],
        unary_operators=[cos],
        early_stop_condition=(loss, complexity) -> (loss < 1e-7 && complexity <= 8),
    )
    @extend_operators options

    hof = equation_search(dataset; niterations=1000, options)

    # Solutions should be like cos([cons] * X[1]) + [cons]*X[1]
    dominating = calculate_pareto_frontier(hof)
    best_expr = first(filter(m::PopMember -> m.loss < 1e-7, dominating)).tree

    @test !violates_dimensional_constraints(best_expr, dataset, options)
    x1 = Node(Float64; feature=1)
    @test compute_complexity(best_expr, options) >=
        compute_complexity(custom_op(cos(1 * x1), 1 * x1), options)

    # Check that every cos(...) which contains x1 also has complexity
    has_cos(tree) =
        any(get_tree(tree)) do t
            t.degree == 1 && options.operators.unaops[t.op] == cos
        end
    valid_trees = [
        !has_cos(member.tree) || any(
            t ->
                t.degree == 1 &&
                    options.operators.unaops[t.op] == cos &&
                    Node(Float64; feature=1) in t &&
                    compute_complexity(t, options) > 1,
            get_tree(member.tree),
        ) for member in dominating
    ]
    @test all(valid_trees)
    @test length(valid_trees) > 0
end

@testitem "Operator compatibility" tags = [:part3] begin
    using SymbolicRegression
    using DynamicQuantities

    ## square cube plus sub mult greater cond relu logical_or logical_and safe_pow atanh_clip
    # Want to ensure these operators perform correctly in the context of units
    @test square(1.0u"m") == 1.0u"m^2"
    @test cube(1.0u"m") == 1.0u"m^3"
    @test plus(1.0u"m", 1.0u"m") == 2.0u"m"
    @test_throws DimensionError plus(1.0u"m", 1.0u"s")
    @test sub(1.0u"m", 1.0u"m") == 0.0u"m"
    @test_throws DimensionError sub(1.0u"m", 1.0u"s")
    @test mult(1.0u"m", 1.0u"m") == 1.0u"m^2"
    @test mult(1.0u"m", 1.0u"s") == 1.0u"m*s"
    @test greater(1.1u"m", 1.0u"m") == true
    @test greater(0.9u"m", 1.0u"m") == false
    @test typeof(greater(1.1u"m", 1.0u"m")) === typeof(1.0u"m")
    @test_throws DimensionError greater(1.0u"m", 1.0u"s")
    @test cond(0.1u"m", 1.5u"m") == 1.5u"m"
    @test cond(-0.1u"m", 1.5u"m") == 0.0u"m"
    @test cond(-0.1u"s", 1.5u"m") == 0.0u"m"
    @test relu(0.1u"m") == 0.1u"m"
    @test relu(-0.1u"m") == 0.0u"m"
    @test logical_or(0.1u"m", 0.0u"m") == 1.0
    @test logical_or(-0.1u"m", 0.0u"m") == 0.0
    @test logical_or(-0.5u"m", 1.0u"m") == 1.0
    @test logical_or(-0.2u"m", -0.2u"m") == 0.0
    @test logical_and(0.1u"m", 0.0u"m") == 0.0
    @test logical_and(0.1u"s", 0.0u"m") == 0.0
    @test logical_and(-0.1u"m", 0.0u"m") == 0.0
    @test logical_and(-0.5u"m", 1.0u"m") == 0.0
    @test logical_and(-0.2u"s", -0.2u"m") == 0.0
    @test logical_and(0.2u"s", 0.2u"m") == 1.0
    @test safe_pow(4.0u"m", 0.5u"1") == 2.0u"m^0.5"
    @test isnan(safe_pow(-4.0u"m", 0.5u"1"))
    @test typeof(safe_pow(-4.0u"m", 0.5u"1")) === typeof(1.0u"m")
    @inferred safe_pow(4.0u"m", 0.5u"1")
    @test_throws DimensionError safe_pow(1.0u"m", 1.0u"m")
    @test atanh_clip(0.5u"1") == atanh(0.5)
    @test atanh_clip(2.5u"1") == atanh(0.5)
    @test_throws DimensionError atanh_clip(1.0u"m")
end

@testitem "Search with dimensional constraints on output" tags = [:part3] begin
    using SymbolicRegression
    using MLJBase: MLJBase as MLJ
    using DynamicQuantities
    using Random: MersenneTwister

    include("utils.jl")

    custom_op(x, y) = x + y
    options = Options(;
        binary_operators=[-, *, /, custom_op],
        unary_operators=[cos],
        early_stop_condition=(loss, complexity) -> (loss < 1e-7 && complexity == 3),
    )
    @extend_operators options

    rng = MersenneTwister(0)
    X = randn(rng, 2, 128)
    X[2, :] .= X[1, :]
    y = X[1, :] .^ 2

    # The search should find that y=X[2]^2 is the best,
    # due to the dimensionality constraint:
    hof = EquationSearch(X, y; options, X_units=["kg", "m"], y_units="m^2")

    # Solution should be x2 * x2
    dominating = calculate_pareto_frontier(hof)
    best = get_tree(first(filter(m::PopMember -> m.loss < 1e-7, dominating)).tree)

    x2 = Node(Float64; feature=2)

    if compute_complexity(best, options) == 3
        @test best.degree == 2
        @test best.l == x2
        @test best.r == x2
    else
        @warn "Complexity of best solution is not 3; search with units might have failed"
    end

    rng = MersenneTwister(0)
    X = randn(rng, 2, 128)
    y = @. cbrt(X[1, :]) .+ sqrt(abs(X[2, :]))
    options2 = Options(;
        binary_operators=[+, *],
        unary_operators=[sqrt, cbrt, abs],
        early_stop_condition=(loss, complexity) -> (loss < 1e-7 && complexity == 6),
    )
    hof = EquationSearch(X, y; options=options2, X_units=["kg^3", "kg^2"], y_units="kg")

    dominating = calculate_pareto_frontier(hof)
    best = first(filter(m::PopMember -> m.loss < 1e-7, dominating)).tree
    @test compute_complexity(best, options2) == 6
    @test any(get_tree(best)) do t
        t.degree == 1 && options2.operators.unaops[t.op] == cbrt
    end
    @test any(get_tree(best)) do t
        t.degree == 1 && options2.operators.unaops[t.op] == safe_sqrt
    end

    @testset "With MLJ" begin
        for as_quantity_array in (false, true)
            model = SRRegressor(;
                binary_operators=[+, *],
                unary_operators=[sqrt, cbrt, abs],
                early_stop_condition=(loss, complexity) -> (loss < 1e-7 && complexity <= 6),
            )
            X = if as_quantity_array
                (; x1=randn(128) .* u"kg^3", x2=QuantityArray(randn(128) .* u"kg^2"))
            else
                (; x1=randn(128) .* u"kg^3", x2=randn(128) .* u"kg^2")
            end
            y = (@. cbrt(ustrip(X.x1)) + sqrt(abs(ustrip(X.x2)))) .* u"kg"
            mach = MLJ.machine(model, X, y)
            MLJ.fit!(mach)
            report = MLJ.report(mach)
            best_idx = findfirst(report.losses .< 1e-7)::Int
            @test report.complexities[best_idx] <= 6
            @test any(get_tree(report.equations[best_idx])) do t
                t.degree == 1 && t.op == 2  # cbrt
            end
            @test any(get_tree(report.equations[best_idx])) do t
                t.degree == 1 && t.op == 1  # safe_sqrt
            end

            # Prediction should have same units:
            ypred = MLJ.predict(mach; rows=1:3)
            @test dimension(ypred[begin]) == dimension(y[begin])
        end

        # Multiple outputs, and with RealQuantity
        model = MultitargetSRRegressor(;
            binary_operators=[+, *],
            unary_operators=[sqrt, cbrt, abs],
            early_stop_condition=(loss, complexity) -> (loss < 1e-7 && complexity <= 8),
        )
        X = (; x1=randn(128), x2=randn(128))
        y = (;
            a=(@. cbrt(ustrip(X.x1)) + sqrt(abs(ustrip(X.x2)))) .* RealQuantity(u"kg"),
            b=X.x1,
        )
        @test typeof(y.a) <: AbstractArray{<:RealQuantity}
        mach = MLJ.machine(model, X, y)
        MLJ.fit!(mach)
        report = MLJ.report(mach)
        @test minimum(report.losses[1]) < 1e-7
        @test minimum(report.losses[2]) < 1e-7

        # Repeat with second run:
        MLJ.fit!(mach)  # (Will run with 0 iterations)
        report = MLJ.report(mach)
        @test minimum(report.losses[1]) < 1e-7
        @test minimum(report.losses[2]) < 1e-7

        # Prediction should have same units:
        ypred = MLJ.predict(mach; rows=1:3)
        @test dimension(ypred.a[begin]) == dimension(y.a[begin])
        @test typeof(dimension(ypred.a[begin])) == typeof(dimension(y.a[begin]))
        # TODO: Should return same quantity as input
        @test typeof(ypred.a[begin]) <: Quantity
        @test typeof(y.a[begin]) <: RealQuantity
        @eval @test(typeof(ypred.b[begin]) == typeof(y.b[begin]), broken = true)
    end
end

@testitem "Should error on mismatched units" tags = [:part3] begin
    using SymbolicRegression
    using DynamicQuantities

    X = randn(11, 50)
    y = randn(50)
    @test_throws("Number of features", Dataset(X, y; X_units=["m", "1"], y_units="kg"))
end

@testitem "Should print units" tags = [:part3] begin
    using SymbolicRegression
    using DynamicQuantities

    X = randn(5, 64)
    y = randn(64)
    dataset = Dataset(X, y; X_units=["m^3", "km/s", "kg", "1", "1"], y_units="kg")
    x1, x2, x3, x4, x5 = [Node(Float64; feature=i) for i in 1:5]
    options = Options(; binary_operators=[+, -, *, /], unary_operators=[cos, sin])
    tree = 1.0 * (x1 + x2 * x3 * 5.32) - cos(1.5 * (x1 - 0.5))

    @test string_tree(tree, options) ==
        "(1.0 * (x1 + ((x2 * x3) * 5.32))) - cos(1.5 * (x1 - 0.5))"
    @test string_tree(tree, options; pretty=true) ==
        "(1 * (x₁ + ((x₂ * x₃) * 5.32))) - cos(1.5 * (x₁ - 0.5))"
    @test string_tree(
        tree, options; pretty=true, display_variable_names=dataset.display_variable_names
    ) == "(1 * (x₁ + ((x₂ * x₃) * 5.32))) - cos(1.5 * (x₁ - 0.5))"
    @test string_tree(
        tree,
        options;
        pretty=true,
        display_variable_names=dataset.display_variable_names,
        X_sym_units=dataset.X_sym_units,
        y_sym_units=dataset.y_sym_units,
    ) ==
        "(1[?] * (x₁[m³] + ((x₂[s⁻¹ km] * x₃[kg]) * 5.32[?]))) - cos(1.5[?] * (x₁[m³] - 0.5[?]))"

    @test string_tree(
        x5 * 3.2,
        options;
        pretty=true,
        display_variable_names=dataset.display_variable_names,
        X_sym_units=dataset.X_sym_units,
        y_sym_units=dataset.y_sym_units,
    ) == "x₅ * 3.2[?]"

    # Should print numeric factor in unit if given:
    dataset2 = Dataset(X, y; X_units=[1.5, 1.9, 2.0, 3.0, 5.0u"m"], y_units="kg")
    @test string_tree(
        x5 * 3.2,
        options;
        pretty=true,
        display_variable_names=dataset2.display_variable_names,
        X_sym_units=dataset2.X_sym_units,
        y_sym_units=dataset2.y_sym_units,
    ) == "x₅[5.0 m] * 3.2[?]"

    # With dimensionless_constants_only, it will not print the [?]:
    options = Options(;
        binary_operators=[+, -, *, /],
        unary_operators=[cos, sin],
        dimensionless_constants_only=true,
    )
    @test string_tree(
        x5 * 3.2,
        options;
        pretty=true,
        display_variable_names=dataset2.display_variable_names,
        X_sym_units=dataset2.X_sym_units,
        y_sym_units=dataset2.y_sym_units,
    ) == "x₅[5.0 m] * 3.2"
end

@testitem "Dimensionless constants" tags = [:part3] begin
    using SymbolicRegression
    using SymbolicRegression.DimensionalAnalysisModule: violates_dimensional_constraints
    using DynamicQuantities

    include("utils.jl")

    options = Options(;
        binary_operators=[+, -, *, /, square, cube],
        unary_operators=[cos, sin],
        dimensionless_constants_only=true,
    )
    X = randn(5, 64)
    y = randn(64)
    dataset = Dataset(X, y; X_units=["m^3", "km/s", "kg", "hr", "1"], y_units="kg")
    x1, x2, x3, x4, x5 = [Node(Float64; feature=i) for i in 1:5]

    dimensionally_valid_equations = [
        1.5 * x1 / (cube(x2) * cube(x4)) * x3, x3, (square(x3) / x3) + x3
    ]
    for tree in dimensionally_valid_equations
        onfail(@test !violates_dimensional_constraints(tree, dataset, options)) do
            @warn "Failed on" tree
        end
    end
    dimensionally_invalid_equations = [Node(Float64; val=1.5), 1.5 * x1, x3 - 1.0 * x1]
    for tree in dimensionally_invalid_equations
        onfail(@test violates_dimensional_constraints(tree, dataset, options)) do
            @warn "Failed on" tree
        end
    end
    # But, all of these would be fine if we allow dimensionless constants:
    let
        options = Options(; binary_operators=[+, -, *, /], unary_operators=[cos, sin])
        for tree in dimensionally_invalid_equations
            onfail(@test !violates_dimensional_constraints(tree, dataset, options)) do
                @warn "Failed on" tree
            end
        end
    end
end

@testitem "Miscellaneous tests of unit interface" tags = [:part3] begin
    using SymbolicRegression
    using DynamicQuantities
    using SymbolicRegression.DimensionalAnalysisModule: @maybe_return_call, WildcardQuantity
    using SymbolicRegression.MLJInterfaceModule: unwrap_units_single
    using SymbolicRegression.InterfaceDynamicQuantitiesModule: get_dimensions_type
    using MLJModelInterface: MLJModelInterface as MMI

    function test_return_call(op::Function, w...)
        @maybe_return_call(typeof(first(w)), op, w)
        return nothing
    end

    x = WildcardQuantity{typeof(u"m")}(u"m/s", true, false)

    # Valid input returns as expected
    @test ustrip(test_return_call(+, x, x)) == 2.0

    # Regular errors are thrown
    thrower(_...) = error("")
    @test_throws ErrorException test_return_call(thrower, 1.0, 1.0)

    # But method errors are safely caught
    @test test_return_call(+, 1.0, "1.0") === nothing

    # Edge case
    ## First, what happens if we just pass some data with quantities,
    ## and some without?
    data = (a=randn(3), b=fill(us"m", 3), c=fill(u"m/s", 3))
    Xm_t = MMI.matrix(data; transpose=true)
    @test typeof(Xm_t) <: Matrix{<:Quantity}
    _, test_dims = unwrap_units_single(Xm_t, Dimensions)
    @test test_dims == dimension.([u"1", u"m", u"m/s"])
    @test test_dims != dimension.([u"m", u"m", u"m"])
    @inferred unwrap_units_single(Xm_t, Dimensions)

    ## Now, we force promotion to generic `Number` type:
    data = (a=Number[randn(3)...], b=fill(us"m", 3), c=fill(u"m/s", 3))
    Xm_t = MMI.matrix(data; transpose=true)
    @test typeof(Xm_t) === Matrix{Number}
    _, test_dims = unwrap_units_single(Xm_t, Dimensions)
    @test test_dims == dimension.([u"1", u"m", u"m/s"])
    @test_skip @inferred unwrap_units_single(Xm_t, Dimensions)

    # Another edge case
    ## Should be able to pull it out from array:
    @test get_dimensions_type(Number[1.0, us"1"], Dimensions) <: SymbolicDimensions
    @test get_dimensions_type(Number[1.0, 1.0], Dimensions) <: Dimensions
end
