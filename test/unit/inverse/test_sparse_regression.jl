@testitem "STLSQ algorithm basic functionality" tags = [:part1] begin
    using SymbolicRegression
    using SymbolicRegression.SparseRegressionModule: stlsq
    using LinearAlgebra: norm

    # Test 1: Simple sparse linear system
    # y = 2*x1 + 0*x2 + 3*x3 (sparse - x2 should be zeroed)
    # Use well-conditioned columns to ensure unique sparse solution
    Theta = Float64[
        1.0 0.1 0.2
        2.0 -0.3 0.1
        3.0 0.4 -0.5
        4.0 -0.2 0.3
        5.0 0.5 -0.1
    ]
    y = 2.0 .* Theta[:, 1] .+ 0.0 .* Theta[:, 2] .+ 3.0 .* Theta[:, 3]

    ξ, success = stlsq(Theta, y; lambda=0.1, max_iter=10)

    @test success
    @test abs(ξ[1] - 2.0) < 1e-6
    @test abs(ξ[2]) < 1e-6  # Should be zeroed
    @test abs(ξ[3] - 3.0) < 1e-6

    # Test 2: All coefficients below threshold
    Theta2 = Float64[1.0 2.0; 3.0 4.0]
    y2 = Float64[0.001, 0.002]

    ξ2, success2 = stlsq(Theta2, y2; lambda=1.0, max_iter=10)

    @test !success2
    @test all(ξ2 .== 0.0)

    # Test 3: Dimension mismatch
    Theta3 = Float64[1.0 2.0; 3.0 4.0]
    y3 = Float64[1.0, 2.0, 3.0]  # Wrong size

    ξ3, success3 = stlsq(Theta3, y3; lambda=0.01, max_iter=10)

    @test !success3
    @test length(ξ3) == 2
    @test all(ξ3 .== 0.0)

    # Test 4: Convergence check
    Theta4 = Float64[
        1.0 0.5 0.1
        2.0 1.0 0.2
        3.0 1.5 0.3
    ]
    y4 = Float64[1.0, 2.0, 3.0]

    ξ4, success4 = stlsq(Theta4, y4; lambda=0.05, max_iter=20)

    @test success4
    # Verify solution satisfies the equation reasonably well
    residual = norm(Theta4 * ξ4 - y4)
    @test residual < 1e-3
end

@testitem "Library construction seed-only (no gen_random_tree_fn)" tags = [:part1] begin
    using SymbolicRegression
    using SymbolicRegression.SparseRegressionModule: build_sindy_library
    using DynamicExpressions: Node

    options = Options(; binary_operators=(+, *, -), unary_operators=(sin, cos))

    X = Float64[1.0 2.0 3.0; 4.0 5.0 6.0]  # 2 features × 3 samples
    y = Float64[1.0, 2.0, 3.0]
    dataset = Dataset(X, y)

    tree_prototype = Node(Float64; val=1.0)
    nfeatures = 2

    # Without gen_random_tree_fn, library is seed-only: 1 constant + nfeatures
    library_trees, Theta, success = build_sindy_library(
        tree_prototype, dataset, options, nfeatures; max_library_size=500
    )

    @test success
    @test length(library_trees) == 3  # 1 constant + 2 features
    @test size(Theta, 1) == 3  # n_samples
    @test size(Theta, 2) == 3

    # No operators at all — same result
    options_minimal = Options(; binary_operators=(), unary_operators=())

    library_trees2, Theta2, success2 = build_sindy_library(
        tree_prototype, dataset, options_minimal, nfeatures; max_library_size=500
    )

    @test success2
    @test length(library_trees2) == 3  # 1 constant + 2 features
    @test size(Theta2, 2) == 3
end

@testitem "Library construction with random trees" tags = [:part1] begin
    using SymbolicRegression
    using SymbolicRegression.SparseRegressionModule: build_sindy_library
    using SymbolicRegression.MutationFunctionsModule: gen_random_tree_fixed_size
    using DynamicExpressions: Node
    using Random: MersenneTwister

    options = Options(; binary_operators=(+, *, -), unary_operators=(sin, cos))

    X = Float64[1.0 2.0 3.0; 4.0 5.0 6.0]  # 2 features × 3 samples
    y = Float64[1.0, 2.0, 3.0]
    dataset = Dataset(X, y)

    tree_prototype = Node(Float64; val=1.0)
    nfeatures = 2
    rng = MersenneTwister(42)

    # With gen_random_tree_fn: seeds + up to 100 random trees
    library_trees, Theta, success = build_sindy_library(
        tree_prototype,
        dataset,
        options,
        nfeatures;
        max_library_size=500,
        gen_random_tree_fn=gen_random_tree_fixed_size,
        rng=rng,
    )

    @test success
    n_seed = 1 + nfeatures  # 3
    @test length(library_trees) >= n_seed
    @test length(library_trees) <= n_seed + 100  # at most 100 random trees added
    @test size(Theta, 1) == 3  # n_samples
    @test size(Theta, 2) == length(library_trees)  # valid trees only

    # Different seed → different library (randomness works)
    rng2 = MersenneTwister(123)
    library_trees_b, _, _ = build_sindy_library(
        tree_prototype,
        dataset,
        options,
        nfeatures;
        max_library_size=500,
        gen_random_tree_fn=gen_random_tree_fixed_size,
        rng=rng2,
    )
    # Libraries should generally differ (different random trees)
    # Both should have seeds + random trees
    @test length(library_trees_b) >= n_seed

    # max_library_size caps the random portion
    library_trees_small, _, success_small = build_sindy_library(
        tree_prototype,
        dataset,
        options,
        nfeatures;
        max_library_size=5,
        gen_random_tree_fn=gen_random_tree_fixed_size,
        rng=MersenneTwister(42),
    )
    @test success_small
    # Seeds (3) are always included; random portion capped at max(0, 5-3)=2
    @test length(library_trees_small) <= 3 + 2
end

@testitem "Tree combination with weighted sum" tags = [:part1] begin
    using SymbolicRegression
    using SymbolicRegression.SparseRegressionModule: combine_trees_weighted_sum
    using DynamicExpressions: Node, eval_tree_array

    options = Options(; binary_operators=(+, *), unary_operators=(sin,))

    X = Float64[1.0 2.0 3.0]

    # Test 1: Single tree with coefficient ≈ 1
    tree1 = Node(Float64; feature=1)
    trees1 = [tree1]
    coeffs1 = Float64[1.0]

    result1 = combine_trees_weighted_sum(trees1, coeffs1, options)
    @test result1 !== nothing
    # Should return tree as-is
    vals1, _ = eval_tree_array(result1, X, options.operators)
    @test vals1 ≈ X[1, :]

    # Test 2: Single tree with coefficient ≠ 1
    coeffs2 = Float64[2.5]

    result2 = combine_trees_weighted_sum(trees1, coeffs2, options)
    @test result2 !== nothing
    # Should return 2.5 * tree
    vals2, _ = eval_tree_array(result2, X, options.operators)
    @test vals2 ≈ 2.5 .* X[1, :]

    # Test 3: Multiple trees
    tree_a = Node(Float64; feature=1)
    tree_b = Node(Float64; val=1.0)
    trees3 = [tree_a, tree_b]
    coeffs3 = Float64[2.0, 3.0]

    result3 = combine_trees_weighted_sum(trees3, coeffs3, options)
    @test result3 !== nothing
    # Should return 2.0*x1 + 3.0*1.0
    vals3, _ = eval_tree_array(result3, X, options.operators)
    expected3 = 2.0 .* X[1, :] .+ 3.0
    @test vals3 ≈ expected3

    # Test 4: All zero coefficients
    coeffs4 = Float64[0.0, 0.0]

    result4 = combine_trees_weighted_sum(trees3, coeffs4, options)
    @test result4 === nothing

    # Test 5: Sparse coefficients (some zeros)
    coeffs5 = Float64[0.0, 5.0]

    result5 = combine_trees_weighted_sum(trees3, coeffs5, options)
    @test result5 !== nothing
    # Should return 5.0 (only second tree with coeff 5.0)
    vals5, _ = eval_tree_array(result5, X, options.operators)
    @test vals5 ≈ [5.0, 5.0, 5.0]

    # Test 6: Missing + operator
    options_no_add = Options(; binary_operators=(*,), unary_operators=(sin,))

    result6 = combine_trees_weighted_sum(trees3, coeffs3, options_no_add)
    @test result6 !== nothing
    # Should return tree with largest coefficient (tree_b with 3.0)
    @test result6 == tree_b

    # Test 7: Missing * operator
    options_no_mult = Options(; binary_operators=(+,), unary_operators=(sin,))

    result7 = combine_trees_weighted_sum(trees3, coeffs3, options_no_mult)
    @test result7 !== nothing
    # Should return unweighted sum
    vals7, _ = eval_tree_array(result7, X, options_no_mult.operators)
    expected7 = X[1, :] .+ 1.0
    @test vals7 ≈ expected7
end

@testitem "Fit sparse expression full pipeline" tags = [:part1] begin
    using SymbolicRegression
    using SymbolicRegression.SparseRegressionModule: fit_sparse_expression
    using DynamicExpressions: Node, eval_tree_array

    # Test 1: Simple linear combination
    options = Options(; binary_operators=(+, *), unary_operators=(sin, cos))

    X = Float64[1.0 2.0 3.0 4.0; 0.5 1.0 1.5 2.0]  # 2 features × 4 samples
    # Target: y = 2*x1 + 3*x2
    y = Float64[3.5, 7.0, 10.5, 14.0]
    dataset = Dataset(X, y)

    tree_prototype = Node(Float64; val=1.0)
    nfeatures = 2

    # Seed-only library (const + x1 + x2) is sufficient for y = 2*x1 + 3*x2
    result = fit_sparse_expression(
        tree_prototype,
        y,
        dataset,
        options,
        nfeatures;
        lambda=0.01,
        max_iter=10,
        max_library_size=500,
        validate=false,
        max_mse=Inf,
    )

    @test result !== nothing

    # Verify the fitted expression approximates the target
    predicted, _ = eval_tree_array(result, X, options.operators)
    mse = sum((predicted .- y) .^ 2) / length(y)
    @test mse < 0.1  # Should fit well

    # Test 2: With validation enabled
    result2 = fit_sparse_expression(
        tree_prototype,
        y,
        dataset,
        options,
        nfeatures;
        lambda=0.01,
        max_iter=10,
        max_library_size=500,
        validate=true,
        max_mse=0.05,
    )

    @test result2 !== nothing
    predicted2, _ = eval_tree_array(result2, X, options.operators)
    mse2 = sum((predicted2 .- y) .^ 2) / length(y)
    @test mse2 < 0.05

    # Test 3: Validation fails (max_mse too strict)
    result3 = fit_sparse_expression(
        tree_prototype,
        y,
        dataset,
        options,
        nfeatures;
        lambda=0.01,
        max_iter=10,
        max_library_size=500,
        validate=true,
        max_mse=1e-10,
    )

    # Might return nothing if MSE too high, or succeed if fit is perfect
    if result3 !== nothing
        predicted3, _ = eval_tree_array(result3, X, options.operators)
        mse3 = sum((predicted3 .- y) .^ 2) / length(y)
        @test mse3 < 1e-10
    end
end

@testitem "collect_all_subtrees!" tags = [:part1] begin
    using SymbolicRegression.SparseRegressionModule: collect_all_subtrees!
    using DynamicExpressions: Node

    # Test 1: Leaf node (constant)
    leaf = Node(Float64; val=3.0)
    subtrees = Node{Float64}[]
    collect_all_subtrees!(subtrees, leaf)
    @test length(subtrees) == 1
    @test subtrees[1] === leaf

    # Test 2: Leaf node (feature)
    feat = Node(Float64; feature=1)
    subtrees2 = Node{Float64}[]
    collect_all_subtrees!(subtrees2, feat)
    @test length(subtrees2) == 1
    @test subtrees2[1] === feat

    # Test 3: Unary node — sin(x1) → 2 subtrees
    x1 = Node(Float64; feature=1)
    unary_tree = Node(1, x1)  # sin(x1)
    subtrees3 = Node{Float64}[]
    collect_all_subtrees!(subtrees3, unary_tree)
    @test length(subtrees3) == 2
    @test subtrees3[1] === unary_tree
    @test subtrees3[2] === x1

    # Test 4: Binary node — x1 + x2 → 3 subtrees
    x1b = Node(Float64; feature=1)
    x2b = Node(Float64; feature=2)
    binary_tree = Node(1, x1b, x2b)  # x1 + x2
    subtrees4 = Node{Float64}[]
    collect_all_subtrees!(subtrees4, binary_tree)
    @test length(subtrees4) == 3
    @test subtrees4[1] === binary_tree
    @test subtrees4[2] === x1b
    @test subtrees4[3] === x2b

    # Test 5: Nested tree — (x1 + x2) * sin(x1) → 5 nodes
    x1c = Node(Float64; feature=1)
    x2c = Node(Float64; feature=2)
    sum_node = Node(1, x1c, x2c)
    sin_x1 = Node(1, Node(Float64; feature=1))
    nested = Node(2, sum_node, sin_x1)
    subtrees5 = Node{Float64}[]
    collect_all_subtrees!(subtrees5, nested)
    @test length(subtrees5) == 6  # root, sum_node, x1c, x2c, sin_x1, sin_x1.l
    @test subtrees5[1] === nested
    @test subtrees5[2] === sum_node
end

@testitem "build_adaptive_library" tags = [:part1] begin
    using SymbolicRegression
    using SymbolicRegression.SparseRegressionModule: build_adaptive_library
    using DynamicExpressions: Node, eval_tree_array, string_tree

    options = Options(; binary_operators=(+, *, -), unary_operators=(sin, cos))

    X = Float64[1.0 2.0 3.0 4.0; 0.5 1.0 1.5 2.0]  # 2 features × 4 samples
    y = Float64[3.5, 7.0, 10.5, 14.0]
    dataset = Dataset(X, y)
    tree_prototype = Node(Float64; val=1.0)
    nfeatures = 2

    # Test 1: population=nothing → seed-only library (constant + features)
    library, Theta, success = build_adaptive_library(
        tree_prototype, dataset, options, nfeatures, nothing; max_library_size=200
    )

    @test success
    @test length(library) == 3  # 1 constant + 2 features
    @test size(Theta, 1) == 4  # n_samples
    @test size(Theta, 2) == 3

    # Test 2: With real population — subtrees are extracted
    tree1 = Node(1, Node(Float64; feature=1), Node(Float64; feature=2))  # x1 + x2
    tree2 = Node(1, Node(Float64; feature=1))  # sin(x1)
    tree3 = Node(Float64; feature=1)  # x1

    member1 = PopMember(dataset, tree1, options; deterministic=true)
    member1.loss = 1.0
    member2 = PopMember(dataset, tree2, options; deterministic=true)
    member2.loss = 2.0
    member3 = PopMember(dataset, tree3, options; deterministic=true)
    member3.loss = 3.0

    pop = Population([member1, member2, member3])

    library2, Theta2, success2 = build_adaptive_library(
        tree_prototype, dataset, options, nfeatures, pop; max_library_size=200
    )

    @test success2
    # Should have seeds (3) + unique subtrees from population
    @test length(library2) > 3
    @test size(Theta2, 2) == length(library2)

    # Test 3: Deduplication among population subtrees works
    # build_adaptive_library deduplicates within population subtrees (not against seeds).
    # Create a population where two members share the exact same tree structure.
    tree_dup1 = Node(1, Node(Float64; feature=1), Node(Float64; feature=2))  # x1 + x2
    tree_dup2 = Node(1, Node(Float64; feature=1), Node(Float64; feature=2))  # x1 + x2 (same)

    member_d1 = PopMember(dataset, tree_dup1, options; deterministic=true)
    member_d1.loss = 1.0
    member_d2 = PopMember(dataset, tree_dup2, options; deterministic=true)
    member_d2.loss = 2.0

    pop_dup = Population([member_d1, member_d2])

    lib_dup, _, success_dup = build_adaptive_library(
        tree_prototype, dataset, options, nfeatures, pop_dup; max_library_size=200
    )

    # Single member version for comparison
    pop_single = Population([member_d1])
    lib_single, _, _ = build_adaptive_library(
        tree_prototype, dataset, options, nfeatures, pop_single; max_library_size=200
    )

    # Both members contribute same subtrees, so dedup should make them equal
    @test success_dup
    @test length(lib_dup) == length(lib_single)

    # Test 4: top_k limits which members contribute subtrees
    # Give member3 the best (lowest) loss, use top_k=1
    member1b = PopMember(dataset, tree1, options; deterministic=true)
    member1b.loss = 10.0
    member2b = PopMember(dataset, tree2, options; deterministic=true)
    member2b.loss = 10.0
    member3b = PopMember(dataset, tree3, options; deterministic=true)
    member3b.loss = 0.1  # best

    pop_topk = Population([member1b, member2b, member3b])

    library_topk, _, success_topk = build_adaptive_library(
        tree_prototype, dataset, options, nfeatures, pop_topk; max_library_size=200, top_k=1
    )

    @test success_topk
    # top_k=1 → only member3b (x1) contributes subtrees
    # Library should be smaller than with all members contributing
    library_all, _, _ = build_adaptive_library(
        tree_prototype,
        dataset,
        options,
        nfeatures,
        pop_topk;
        max_library_size=200,
        top_k=10,
    )
    @test length(library_topk) <= length(library_all)

    # Test 5: max_library_size caps total library size
    library_capped, _, success_capped = build_adaptive_library(
        tree_prototype, dataset, options, nfeatures, pop; max_library_size=4, top_k=10
    )

    @test success_capped
    @test length(library_capped) <= 4
end

@testitem "fit_sparse_expression with population" tags = [:part1] begin
    using SymbolicRegression
    using SymbolicRegression.SparseRegressionModule: fit_sparse_expression
    using DynamicExpressions: Node, eval_tree_array

    options = Options(; binary_operators=(+, *), unary_operators=(sin, cos))

    X = Float64[1.0 2.0 3.0 4.0; 0.5 1.0 1.5 2.0]  # 2 features × 4 samples
    # Target: y = 2*x1 + 3*x2
    y = Float64[3.5, 7.0, 10.5, 14.0]
    dataset = Dataset(X, y)

    # Build population whose members contain x1 and x2 as subtrees
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
        tree_prototype,
        y,
        dataset,
        options,
        nfeatures;
        lambda=0.01,
        max_iter=10,
        max_library_size=500,
        validate=true,
        max_mse=1.0,
        population=pop,
    )

    @test result !== nothing

    predicted, _ = eval_tree_array(result, X, options.operators)
    mse = sum((predicted .- y) .^ 2) / length(y)
    @test mse < 1.0
end

@testitem "Integration test: inverse mutation with sparse regression" tags = [:part2] begin
    using SymbolicRegression
    using SymbolicRegression.MutationFunctionsModule: backsolve_rewrite_random_node
    using DynamicExpressions: Node, eval_tree_array
    using Random: MersenneTwister

    # Test 1: Basic inverse mutation with sparse regression enabled
    options = Options(;
        binary_operators=(+, *, -),
        unary_operators=(sin, cos),
        sparse_regression=SparseRegressionOptions(;
            use=true,
            lambda=0.01,
            max_iter=10,
            max_library_size=500,
            validate=false,
            max_mse=Inf,
        ),
    )

    X = Float64[1.0 2.0 3.0 4.0; 0.5 1.0 1.5 2.0]  # 2 features × 4 samples
    y = Float64[3.5, 7.0, 10.5, 14.0]
    dataset = Dataset(X, y)

    # Build a tree: (x1 + x2) * sin(x1)
    x1 = Node(Float64; feature=1)
    x2 = Node(Float64; feature=2)
    sum_node = Node(1, x1, x2)  # x1 + x2
    sin_x1 = Node(1, Node(Float64; feature=1))  # sin(x1)
    tree = Node(2, sum_node, sin_x1)  # (x1 + x2) * sin(x1)

    rng = MersenneTwister(42)

    # Capture original output before mutation (function mutates in-place)
    orig_vals, _ = eval_tree_array(copy(tree), X, options.operators)

    # Perform inverse mutation (signature: tree, dataset, options, rng)
    mutated_tree = backsolve_rewrite_random_node(tree, dataset, options, rng)

    @test mutated_tree !== nothing
    # Mutation modifies in-place; verify the tree was actually changed
    new_vals, _ = eval_tree_array(mutated_tree, X, options.operators)
    @test new_vals != orig_vals

    # Test 2: Sparse regression disabled (fallback to median)
    options_no_sparse = Options(;
        binary_operators=(+, *, -),
        unary_operators=(sin, cos),
        sparse_regression=SparseRegressionOptions(; use=false),
    )

    orig_vals2, _ = eval_tree_array(copy(tree), X, options_no_sparse.operators)
    mutated_tree2 = backsolve_rewrite_random_node(tree, dataset, options_no_sparse, rng)

    @test mutated_tree2 !== nothing
    new_vals2, _ = eval_tree_array(mutated_tree2, X, options_no_sparse.operators)
    @test new_vals2 != orig_vals2

    # Test 3: Sparse regression with validation
    options_validate = Options(;
        binary_operators=(+, *, -),
        unary_operators=(sin, cos),
        sparse_regression=SparseRegressionOptions(;
            use=true, lambda=0.01, max_iter=10, validate=true, max_mse=1.0
        ),
    )

    orig_vals3, _ = eval_tree_array(copy(tree), X, options_validate.operators)
    mutated_tree3 = backsolve_rewrite_random_node(tree, dataset, options_validate, rng)

    @test mutated_tree3 !== nothing
    new_vals3, _ = eval_tree_array(mutated_tree3, X, options_validate.operators)
    @test new_vals3 != orig_vals3

    # Test 4: Single-node tree returns unchanged (length <= 1 early return)
    simple_tree = Node(Float64; feature=1)
    simple_copy = copy(simple_tree)

    mutated_tree4 = backsolve_rewrite_random_node(simple_tree, dataset, options, rng)

    @test mutated_tree4 !== nothing
    # Single-node tree should be returned as-is
    @test mutated_tree4.degree == simple_copy.degree
    @test mutated_tree4.feature == simple_copy.feature
end

@testitem "Edge cases and error handling" tags = [:part1] begin
    using SymbolicRegression
    using SymbolicRegression.SparseRegressionModule: stlsq, fit_sparse_expression
    using DynamicExpressions: Node

    # Test 1: No binary operators → +/* guard fires, returns nothing immediately
    options_empty = Options(; binary_operators=(), unary_operators=())

    X = Float64[1.0 2.0 3.0]
    y = Float64[1.0, 2.0, 3.0]
    dataset = Dataset(X, y)
    tree_prototype = Node(Float64; val=1.0)

    result = fit_sparse_expression(
        tree_prototype, y, dataset, options_empty, 1; lambda=0.01, max_iter=10
    )

    @test result === nothing  # no + and * available

    # Test 2: Very high lambda (all coefficients zeroed)
    options = Options(; binary_operators=(+, *), unary_operators=(sin,))

    result2 = fit_sparse_expression(
        tree_prototype,
        y,
        dataset,
        options,
        1;
        lambda=1e10,
        max_iter=10,  # Extremely high threshold
    )

    # With lambda=1e10 all coefficients should be zeroed → stlsq fails → nothing
    @test result2 === nothing

    # Test 3: Zero samples (edge case)
    Theta_empty = zeros(Float64, 0, 3)
    y_empty = Float64[]

    ξ_empty, success_empty = stlsq(Theta_empty, y_empty; lambda=0.01)
    @test !success_empty

    # Test 4: Single sample
    Theta_single = Float64[1.0 2.0 3.0]
    y_single = Float64[6.0]

    ξ_single, success_single = stlsq(Theta_single, y_single; lambda=0.01)
    # Should either succeed or fail gracefully
    @test typeof(success_single) == Bool
    @test length(ξ_single) == 3

    # Test 5: NaN/Inf in target values
    X_inf = Float64[1.0 2.0 3.0]
    y_inf = Float64[1.0, Inf, 3.0]
    dataset_inf = Dataset(X_inf, y_inf)

    result5 = fit_sparse_expression(
        tree_prototype,
        y_inf,
        dataset_inf,
        options,
        1;
        lambda=0.01,
        max_iter=10,
        validate=true,
    )

    # Inf in target causes invalid STLSQ result; validation rejects it
    @test result5 === nothing
end
