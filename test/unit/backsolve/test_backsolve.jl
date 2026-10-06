@testitem "STLSQ algorithm basic functionality" tags = [:part1] begin
    using SymbolicRegression
    using SymbolicRegression.EvolutionModule.BacksolveModule: stlsq
    using LinearAlgebra: norm

    theta = Float64[
        1.0 0.1 0.2
        2.0 -0.3 0.1
        3.0 0.4 -0.5
        4.0 -0.2 0.3
        5.0 0.5 -0.1
    ]
    y = 2.0 .* theta[:, 1] .+ 0.0 .* theta[:, 2] .+ 3.0 .* theta[:, 3]

    coefficients, success = stlsq(theta, y; lambda=0.1, max_iter=10)

    @test success
    @test abs(coefficients[1] - 2.0) < 1e-6
    @test abs(coefficients[2]) < 1e-6
    @test abs(coefficients[3] - 3.0) < 1e-6

    theta2 = Float64[1.0 2.0; 3.0 4.0]
    y2 = Float64[0.001, 0.002]

    coefficients2, success2 = stlsq(theta2, y2; lambda=1.0, max_iter=10)

    @test !success2
    @test all(coefficients2 .== 0.0)

    theta3 = Float64[1.0 2.0; 3.0 4.0]
    y3 = Float64[1.0, 2.0, 3.0]

    coefficients3, success3 = stlsq(theta3, y3; lambda=0.01, max_iter=10)

    @test !success3
    @test length(coefficients3) == 2
    @test all(coefficients3 .== 0.0)

    theta4 = Float64[
        1.0 0.5 0.1
        2.0 1.0 0.2
        3.0 1.5 0.3
    ]
    y4 = Float64[1.0, 2.0, 3.0]

    coefficients4, success4 = stlsq(theta4, y4; lambda=0.05, max_iter=20)

    @test success4
    residual = norm(theta4 * coefficients4 - y4)
    @test residual < 1e-3

    theta5 = Float64[
        1.0 2.0 3.0
        2.0 4.0 6.0
        3.0 6.0 9.0
    ]
    y5 = Float64[1.0, 2.0, 3.0]

    coefficients5, success5 = stlsq(theta5, y5; lambda=0.01, max_iter=10)
    @test success5
    @test norm(theta5 * coefficients5 - y5) < 1e-8
end

@testitem "Tree combination with weighted sum" tags = [:part1] begin
    using SymbolicRegression
    using SymbolicRegression.EvolutionModule.BacksolveModule: combine_trees_weighted_sum
    using DynamicExpressions: Node, eval_tree_array

    options = Options(; binary_operators=(+, *), unary_operators=(sin,))

    X = Float64[1.0 2.0 3.0]
    values(tree) = first(eval_tree_array(tree, X, options.operators))

    tree1 = Node(Float64; feature=1)
    trees1 = [tree1]
    coeffs1 = Float64[1.0]

    result1 = combine_trees_weighted_sum(trees1, coeffs1, options)
    @test result1 !== nothing
    @test isapprox(values(result1), X[1, :])

    coeffs2 = Float64[2.5]

    result2 = combine_trees_weighted_sum(trees1, coeffs2, options)
    @test result2 !== nothing
    @test isapprox(values(result2), 2.5 .* X[1, :])

    tree_a = Node(Float64; feature=1)
    tree_b = Node(Float64; val=1.0)
    trees3 = [tree_a, tree_b]
    coeffs3 = Float64[2.0, 3.0]

    result3 = combine_trees_weighted_sum(trees3, coeffs3, options)
    @test result3 !== nothing
    expected3 = 2.0 .* X[1, :] .+ 3.0
    @test isapprox(values(result3), expected3)

    coeffs4 = Float64[0.0, 0.0]

    result4 = combine_trees_weighted_sum(trees3, coeffs4, options)
    @test result4 === nothing

    coeffs5 = Float64[0.0, 5.0]

    result5 = combine_trees_weighted_sum(trees3, coeffs5, options)
    @test result5 !== nothing
    @test isapprox(values(result5), [5.0, 5.0, 5.0])

    options_no_add = Options(; binary_operators=(*,), unary_operators=(sin,))

    result6 = combine_trees_weighted_sum(trees3, coeffs3, options_no_add)
    @test result6 === nothing

    options_no_mult = Options(; binary_operators=(+,), unary_operators=(sin,))

    result7 = combine_trees_weighted_sum(trees3, coeffs3, options_no_mult)
    @test result7 === nothing

    result8 = combine_trees_weighted_sum(trees1, coeffs2, options_no_mult)
    @test result8 === nothing

    coeffs9 = Float64[1.0, 2.0]
    result9 = combine_trees_weighted_sum(trees3, coeffs9, options)
    @test result9 !== nothing
    @test isapprox(values(result9), X[1, :] .+ 2.0)
end

@testitem "Fit sparse expression full pipeline" tags = [:part1] begin
    using SymbolicRegression
    using SymbolicRegression.EvolutionModule.BacksolveModule: fit_sparse_expression
    using DynamicExpressions: Node, eval_tree_array

    mutable struct ValidationFlipMatrix <: AbstractMatrix{Float64}
        data::Matrix{Float64}
        finite_gets_remaining::Int
    end
    Base.size(A::ValidationFlipMatrix) = size(A.data)
    function Base.getindex(A::ValidationFlipMatrix, i::Int, j::Int)
        if A.finite_gets_remaining > 0
            A.finite_gets_remaining -= 1
            return A.data[i, j]
        end
        return Inf
    end

    make_options(; kws...) = Options(;
        binary_operators=(+, *),
        unary_operators=(sin, cos),
        default_mutations=(),
        mutations=(BacksolveMutation(; max_library_size=500, kws...) => 1.0,),
    )
    options = make_options()

    X = Float64[1.0 2.0 3.0 4.0; 0.5 1.0 1.5 2.0]  # 2 features x 4 samples
    y = Float64[3.5, 7.0, 10.5, 14.0]
    dataset = Dataset(X, y)

    tree_prototype = Node(Float64; val=1.0)
    nfeatures = 2
    fit(target_values=y, fit_dataset=dataset, fit_nfeatures=nfeatures; kws...) =
        fit_sparse_expression(
            tree_prototype,
            target_values,
            fit_dataset,
            make_options(; kws...),
            fit_nfeatures,
        )
    function fit_mse(tree, target_values=y, fit_X=X)
        predicted, _ = eval_tree_array(tree, fit_X, options.operators)
        return sum(abs2, predicted .- target_values) / length(target_values)
    end

    result = fit()

    @test result !== nothing
    @test fit_mse(result) < 0.1

    flip_X = ValidationFlipMatrix(reshape(Float64[1.0, 2.0, 3.0, 4.0], 1, 4), 4)
    y_flip = Float64[2.0, 4.0, 6.0, 8.0]
    dataset_flip = Dataset(flip_X, y_flip)
    result_invalid = fit(y_flip, dataset_flip, 1)
    @test result_invalid === nothing
end

@testitem "build_basis_library" tags = [:part1] begin
    using SymbolicRegression
    using SymbolicRegression.EvolutionModule.BacksolveModule:
        BasisLibrary, build_basis_library
    using DynamicExpressions: Node, eval_tree_array, string_tree

    options = Options(; binary_operators=(+, *, -), unary_operators=(sin, cos))

    X = Float64[1.0 2.0 3.0 4.0; 0.5 1.0 1.5 2.0]  # 2 features x 4 samples
    y = Float64[3.5, 7.0, 10.5, 14.0]
    dataset = Dataset(X, y)
    tree_prototype = Node(Float64; val=1.0)
    nfeatures = 2

    @test_throws ArgumentError BasisLibrary([tree_prototype], zeros(Float64, 4, 2))
    @test_throws ArgumentError build_basis_library(
        tree_prototype, dataset, options, nfeatures, nothing; max_library_size=2
    )

    basis = build_basis_library(
        tree_prototype, dataset, options, nfeatures, nothing; max_library_size=200
    )

    @test basis isa BasisLibrary
    @test length(basis.terms) == 3  # 1 constant + 2 features
    @test size(basis.evaluated_terms, 1) == 4  # n_samples
    @test size(basis.evaluated_terms, 2) == 3

    member(tree, loss) = begin
        m = PopMember(dataset, tree, options; deterministic=true)
        m.loss = loss
        m
    end

    tree1 = Node(1, Node(Float64; feature=1), Node(Float64; feature=2))  # x1 + x2
    tree2 = Node(1, Node(Float64; feature=1))  # sin(x1)
    tree3 = Node(Float64; feature=1)  # x1

    pop = Population([member(tree1, 1.0), member(tree2, 2.0), member(tree3, 3.0)])

    basis2 = build_basis_library(
        tree_prototype, dataset, options, nfeatures, pop; max_library_size=200
    )

    @test length(basis2.terms) > 3
    @test size(basis2.evaluated_terms, 2) == length(basis2.terms)

    raw_pop = (members=[(loss=0.1, tree=tree1)], n=1)
    basis_raw = build_basis_library(
        tree_prototype, dataset, options, nfeatures, raw_pop; max_library_size=200
    )

    @test length(basis_raw.terms) > 3
    @test size(basis_raw.evaluated_terms, 2) == length(basis_raw.terms)

    member_d1 = member(Node(1, Node(Float64; feature=1), Node(Float64; feature=2)), 1.0)
    member_d2 = member(Node(1, Node(Float64; feature=1), Node(Float64; feature=2)), 2.0)
    pop_dup = Population([member_d1, member_d2])

    basis_dup = build_basis_library(
        tree_prototype, dataset, options, nfeatures, pop_dup; max_library_size=200
    )

    pop_single = Population([member_d1])
    basis_single = build_basis_library(
        tree_prototype, dataset, options, nfeatures, pop_single; max_library_size=200
    )

    @test length(basis_dup.terms) == length(basis_single.terms)

    pop_topk = Population([member(tree1, 10.0), member(tree2, 10.0), member(tree3, 0.1)])

    basis_topk = build_basis_library(
        tree_prototype, dataset, options, nfeatures, pop_topk; max_library_size=200, top_k=1
    )

    basis_all = build_basis_library(
        tree_prototype,
        dataset,
        options,
        nfeatures,
        pop_topk;
        max_library_size=200,
        top_k=10,
    )
    @test length(basis_topk.terms) <= length(basis_all.terms)

    basis_capped = build_basis_library(
        tree_prototype, dataset, options, nfeatures, pop; max_library_size=4, top_k=10
    )

    @test length(basis_capped.terms) <= 4
end

@testitem "fit_sparse_expression with population_for_backsolve" tags = [:part1] begin
    using SymbolicRegression
    using SymbolicRegression.EvolutionModule.BacksolveModule: fit_sparse_expression
    using DynamicExpressions: Node, eval_tree_array

    options = Options(;
        binary_operators=(+, *),
        unary_operators=(sin, cos),
        default_mutations=(),
        mutations=(BacksolveMutation(; max_library_size=500) => 1.0,),
    )

    X = Float64[1.0 2.0 3.0 4.0; 0.5 1.0 1.5 2.0]  # 2 features x 4 samples
    y = Float64[3.5, 7.0, 10.5, 14.0]
    dataset = Dataset(X, y)

    tree1 = Node(1, Node(Float64; feature=1), Node(Float64; val=1.0))  # x1 + 1
    tree2 = Node(1, Node(Float64; feature=2), Node(Float64; val=2.0))  # x2 + 2

    member1 = PopMember(dataset, tree1, options; deterministic=true)
    member1.loss = 1.0
    member2 = PopMember(dataset, tree2, options; deterministic=true)
    member2.loss = 2.0

    pop = Population([member1, member2])

    tree_prototype = Node(Float64; val=1.0)
    nfeatures = 2

    result = fit_sparse_expression(
        tree_prototype, y, dataset, options, nfeatures; population_for_backsolve=pop
    )

    @test result !== nothing

    predicted, _ = eval_tree_array(result, X, options.operators)
    mse = sum((predicted .- y) .^ 2) / length(y)
    @test mse < 1.0
end

@testitem "Integration test: backsolve rewrite with sparse fit" tags = [:part2] begin
    using SymbolicRegression
    using SymbolicRegression.EvolutionModule.MutationFunctionsModule:
        backsolve_rewrite_random_node
    using DynamicExpressions: Node, eval_tree_array
    using Random: MersenneTwister

    sr_options() = Options(;
        binary_operators=(+, *, -),
        unary_operators=(sin, cos),
        default_mutations=(),
        mutations=(BacksolveMutation(; max_library_size=500) => 1.0,),
    )

    X = Float64[1.0 2.0 3.0 4.0; 0.5 1.0 1.5 2.0]  # 2 features x 4 samples
    y = Float64[3.5, 7.0, 10.5, 14.0]
    dataset = Dataset(X, y)
    options = sr_options()

    x1 = Node(Float64; feature=1)
    x2 = Node(Float64; feature=2)
    sum_node = Node(1, x1, x2)
    sin_x1 = Node(1, Node(Float64; feature=1))
    tree = Node(2, sum_node, sin_x1)

    rng = MersenneTwister(42)

    orig_vals, _ = eval_tree_array(copy(tree), X, options.operators)
    mutated_tree = backsolve_rewrite_random_node(tree, dataset, options, rng)

    @test mutated_tree !== nothing
    new_vals, _ = eval_tree_array(mutated_tree, X, options.operators)
    @test new_vals != orig_vals

    simple_tree = Node(Float64; feature=1)
    simple_copy = copy(simple_tree)

    mutated_tree4 = backsolve_rewrite_random_node(simple_tree, dataset, options, rng)

    @test mutated_tree4 !== nothing
    @test mutated_tree4.degree == simple_copy.degree
    @test mutated_tree4.feature == simple_copy.feature
end

@testitem "Edge cases and error handling" tags = [:part1] begin
    using SymbolicRegression
    using SymbolicRegression.EvolutionModule.BacksolveModule: stlsq, fit_sparse_expression
    using DynamicExpressions: Node

    options_empty = Options(;
        binary_operators=(),
        unary_operators=(),
        default_mutations=(),
        mutations=(BacksolveMutation() => 1.0,),
    )

    X = Float64[1.0 2.0 3.0]
    y = Float64[1.0, 2.0, 3.0]
    dataset = Dataset(X, y)
    tree_prototype = Node(Float64; val=1.0)

    result = fit_sparse_expression(tree_prototype, y, dataset, options_empty, 1)

    @test result === nothing

    make_options(; kws...) = Options(;
        binary_operators=(+, *),
        unary_operators=(sin,),
        default_mutations=(),
        mutations=(BacksolveMutation(; kws...) => 1.0,),
    )
    options = make_options(; min_improvement=1e10)

    result2 = fit_sparse_expression(tree_prototype, y, dataset, options, 1)

    @test result2 === nothing

    theta_empty = zeros(Float64, 0, 3)
    y_empty = Float64[]

    coefficients_empty, success_empty = stlsq(theta_empty, y_empty; lambda=0.01)
    @test !success_empty

    theta_single = Float64[1.0 2.0 3.0]
    y_single = Float64[6.0]

    coefficients_single, success_single = stlsq(theta_single, y_single; lambda=0.01)
    @test typeof(success_single) == Bool
    @test length(coefficients_single) == 3

    X_inf = Float64[1.0 2.0 3.0]
    y_inf = Float64[1.0, Inf, 3.0]
    dataset_inf = Dataset(X_inf, y_inf)
    options_inf = make_options()

    result5 = fit_sparse_expression(tree_prototype, y_inf, dataset_inf, options_inf, 1)

    @test result5 === nothing

    theta_complex = ComplexF64[
        1.0+0.0im 0.1+0.0im
        2.0+0.0im -0.3+0.0im
        3.0+0.0im 0.4+0.0im
    ]
    y_complex = (2.0 + 1.0im) .* theta_complex[:, 1]

    coefficients_complex, success_complex = stlsq(theta_complex, y_complex; lambda=0.1)
    @test success_complex
    @test maximum(abs.(theta_complex * coefficients_complex - y_complex)) < 1e-12

    X_complex = ComplexF64[1.0 + 1.0im 2.0 - 1.0im 3.0 + 2.0im 4.0 - 3.0im]
    y_fit_complex = (2.0 + 1.0im) .* X_complex[1, :]
    dataset_complex = Dataset(X_complex, y_fit_complex)
    tree_prototype_complex = Node(ComplexF64; feature=1)
    options_complex = make_options()

    result_complex = fit_sparse_expression(
        tree_prototype_complex, y_fit_complex, dataset_complex, options_complex, 1
    )
    @test result_complex !== nothing

    theta_int = Int[1 0; 2 1; 3 1]
    y_int = Int[2, 4, 6]
    @test_throws MethodError stlsq(theta_int, y_int; lambda=0.1)

    dataset_int = Dataset(Int[1 2 3 4], Int[2, 4, 6, 8], Float64)
    tree_prototype_int = Node(Int; feature=1)
    @test_throws MethodError fit_sparse_expression(
        tree_prototype_int, dataset_int.y, dataset_int, make_options(), 1
    )
end
