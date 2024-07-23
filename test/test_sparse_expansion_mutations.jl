@testitem "Test linear solver" tags = [:part3] begin
    using SymbolicRegression.SparseLinearExpansionModule: solve_linear_system
    using LinearAlgebra: I

    A = [1.0 2.0; 3.0 4.0]
    y = [1.0; 2.0]
    x = solve_linear_system(A, y, 0.0)
    @test A * x ≈ y

    # Non-square matrix:
    A = [1.0 2.0; 3.0 4.0; 5.0 6.0]
    y = [1.0; 2.0; 3.0]
    x = solve_linear_system(A, y, 0.0)
    @test A * x ≈ y

    A = [i == j ? 1.0f0 : 0.0f0 for i in 1:10, j in 1:10]
    y = ones(Float32, 10)
    x = solve_linear_system(A, y, 1.0f0)
    @test x isa Vector{Float32}
    @test all(xi -> xi == 0.5, x)  # With regularization, pushes x towards 0

    # Same as non-square
    A = [i == j ? 1.0 : 0.0 for i in 1:5, j in 1:10]
    y = ones(Float64, 5)
    x = solve_linear_system(A, y, 1.0)
    @test all(xi -> xi == 0.5, x[1:5])
    @test all(xi -> xi == 0.0, x[6:10])

    # Test singular matrix with regularization
    A = zeros(5, 5)
    y = ones(5)
    x = solve_linear_system(A, y, 1e-6)
    @test all(xi -> xi == 0.0, x)
end

@testitem "Test masking of duplicate bases" tags = [:part3] begin
    using SymbolicRegression.SparseLinearExpansionModule:
        mask_out_duplicate_bases!, normalize_bases!

    # No duplicates
    x = [
        1.0 2.0 3.0
        4.0 5.0 6.0
    ]
    mask = trues(3)
    mask_out_duplicate_bases!(mask, x)
    @test mask == trues(3)

    # One duplicate
    x = [
        1.0 1.0 3.0
        1.0 1.0 6.0
    ]
    mask = trues(3)
    mask_out_duplicate_bases!(mask, x)
    @test mask == [true, false, true]

    # Linear combinations are NOT detected.
    # (Should be rescaled to stdev BEFORE entering)
    x = [
        1.0 2.0 4.0 6.0
        -1.0 -2.0 -4.0 6.0
    ]
    mask = trues(4)
    mask_out_duplicate_bases!(mask, x)
    @test mask == trues(4)

    # Now, we will re-scale things, which
    # will cause duplicates to be detected:
    x_scales = normalize_bases!(x, mask)
    @test mask == [true, true, true, false]  # 0 stdev causes masking

    # Test scales explicitly:
    @test first(x_scales) ≈ sqrt(2)
    @test last(x_scales) == 0

    # Finally, masking with this will now detect
    # the linear re-scalings:
    mask = trues(4)
    mask_out_duplicate_bases!(mask, x)
    @test mask == [true, false, false, true]
end

@testitem "Test we can recover a known basis" tags = [:part3] begin
    using SymbolicRegression
    using SymbolicRegression.SparseLinearExpansionModule: find_sparse_linear_expression
    using Random: MersenneTwister

    rng = MersenneTwister(0)
    options = Options(; binary_operators=[+, -, *, /], unary_operators=[sin, cos])
    xs = map(1:3) do i
        Node{Float64}(; feature=i)
    end
    X = randn(rng, 3, 128)
    y = @. 1.0 * X[1, :] + 2.0 * X[2, :] + 3.0 * X[3, :]

    coeffs, basis = find_sparse_linear_expression(
        rng, X, y, options, Node; predefined_basis=xs, max_final_basis_size=3
    )
    @test isapprox(coeffs, [1.0, 2.0, 3.0]; atol=1e-4)
end

@testitem "Bad expressions should be masked" tags = [:part3] begin
    using SymbolicRegression
    using SymbolicRegression.SparseLinearExpansionModule: find_sparse_linear_expression
    using Random: MersenneTwister

    options = Options(; binary_operators=[+, -, *, /], unary_operators=[sin, cos])

    x1 = Node{Float64}(; feature=1)
    ex_div_0 = Node(; op=4, l=Node{Float64}(; feature=1), r=Node{Float64}(; val=0.0))
    rng = MersenneTwister(0)
    X = randn(rng, 5, 32)
    y = randn(rng, 32)

    coeffs, basis = find_sparse_linear_expression(
        rng, X, y, options, typeof(x1); predefined_basis=[x1, ex_div_0]
    )
    @test length(coeffs) == 1
    @test only(basis) == x1
end

@testitem "Smoke test linear expansion" tags = [:part3] begin
    using SymbolicRegression
    using SymbolicRegression.SparseLinearExpansionModule: find_sparse_linear_expression
    using Random: MersenneTwister

    options = Options(; binary_operators=[+, -, *, /], unary_operators=[sin, cos])
    rng = MersenneTwister(0)
    X = randn(rng, 5, 1024)
    y = @. 1.5 * X[1, :] * X[2, :] + 2.0 * X[3, :] * X[4, :] + 3.0 * X[5, :]

    coeffs, basis = find_sparse_linear_expression(
        rng, X, y, options, Node; max_final_basis_size=5
    )
    @test length(coeffs) == 5
    @test length(basis) == 5
    @test eltype(coeffs) == Float64
    @test eltype(basis) <: Node{eltype(X)}

    y_pred = sum(
        i -> coeffs[i] .* first(eval_tree_array(basis[i], X, options)), eachindex(coeffs)
    )
    pred_loss = sum(abs2, y_pred .- y)
    baseline_loss = sum(abs2, y)
    @test pred_loss < baseline_loss
end

@testitem "Linear expansion to node" tags = [:part3] begin
    using SymbolicRegression
    using SymbolicRegression.SparseLinearExpansionModule: reduce_coeffs_with_basis
    options = Options(; binary_operators=[+, -, *, /], unary_operators=[sin, cos])
    add = findfirst(==(+), options.operators.binops)::Int
    mul = findfirst(==(*), options.operators.binops)::Int

    x1 = Node{Float64}(; feature=1)
    x2 = Node{Float64}(; feature=2)
    x3 = Node{Float64}(; feature=3)

    bases = [x1, x2 * 3.0, x3 - x1]
    coeffs = [1.0, 2.0, 3.0]
    tree = reduce_coeffs_with_basis(coeffs, bases, mul, add)
    @show tree
end

@testitem "Linear expansion to node" tags = [:part3] begin
    using SymbolicRegression
    using SymbolicRegression.SparseLinearExpansionModule: sparse_linear_expansion!

    options = Options(; binary_operators=[+, -, *, /], unary_operators=[sin, cos])
    X = randn(5, 1024)
    y = @. 1.5 * X[1, :] * X[2, :] + 2.0 * X[3, :] * X[4, :] + 3.0 * X[5, :] + 1.5
    dataset = Dataset(X, y)

    x0 = Node{Float64}(; feature=1)
    tree = x0 + 1.5
    expand_at = x0

    tree = sparse_linear_expansion!(tree, dataset, options, expand_at)
end

@testitem "Test linear expansion assertions" tags = [:part3] begin
    using SymbolicRegression.SparseLinearExpansionModule:
        assert_can_use_sparse_linear_expression
    using SymbolicRegression: L2DistLoss

    @test_throws AssertionError assert_can_use_sparse_linear_expression(
        Options(; binary_operators=[-, /])
    )
    @test_throws AssertionError assert_can_use_sparse_linear_expression(
        Options(; binary_operators=[*, /])
    )
    @test_throws AssertionError assert_can_use_sparse_linear_expression(
        Options(; elementwise_loss=L1DistLoss())
    )
    @test_throws AssertionError assert_can_use_sparse_linear_expression(
        Options(; loss_function=(args...,) -> 1.0)
    )

    assert_can_use_sparse_linear_expression(Options(; elementwise_loss=L2DistLoss()))
end
