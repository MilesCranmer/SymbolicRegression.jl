"""This module defines a mutation which solves for a sparse linear expansion at some node."""
# module SparseLinearExpansionModule

using DynamicExpressions: AbstractExpression, with_contents, eval_tree_array
using LossFunctions: L2DistLoss
using Random: AbstractRNG, default_rng
using StatsBase: std, percentile
using LinearAlgebra: I
using TestItems: @testitem

# using ..CoreModule: Options, Dataset
# using ..PopMemberModule: PopMember
# using ..MutationFunctionsModule: gen_random_tree_fixed_size

function make_random_basis(
    rng::AbstractRNG,
    prototype::AbstractExpression,
    dataset::Dataset{T,L},
    options::Options,
    basis_size::Int;
    min_num_nodes=1,
    max_num_nodes=5,
) where {T,L}
    basis_functions = [copy(prototype) for _ in 1:basis_size]  # TODO: Make this a parameter
    for i in eachindex(basis_functions)
        num_nodes = rand(rng, min_num_nodes:max_num_nodes)
        local new_tree
        attempt = 0
        while attempt < 1000  # TODO: Surely there's a better way to do this
            new_tree = gen_random_tree_fixed_size(
                num_nodes, options, dataset.nfeatures, T, rng
            )
            if any(node -> node.degree == 0 && !node.constant, new_tree)
                break
            end
            attempt += 1
        end
        attempt == 1000 && error("Failed to find a valid basis function")
        basis_functions[i] = with_contents(basis_functions[i], new_tree)
    end
    return basis_functions
end

function assert_can_use_sparse_linear_expression(options::Options)
    @assert options.elementwise_loss isa L2DistLoss
    @assert options.loss_function === nothing
    @assert (+) in options.operators.binops
    @assert (*) in options.operators.binops
    return nothing
end

@testitem "Test linear expansion assertions" begin
    using SymbolicRegression: assert_can_use_sparse_linear_expression
    # using SymbolicRegression.SparseLinearExpansionModule: assert_can_use_sparse_linear_expression
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

function solve_linear_system(
    A::AbstractMatrix{T}, y::AbstractVector{T}, regularization::Real
) where {T}
    n = size(A, 2)  # number of features
    ATA = A'A
    ATy = A'y
    return (ATA + regularization * I(n)) \ ATy
end

@testitem "Test linear solver" begin
    using SymbolicRegression: solve_linear_system
    # using SymbolicRegression.SparseLinearExpansionModule: solve_linear_system
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

function normalize_bases!(A::AbstractMatrix, mask::AbstractVector{Bool})
    A_scales = std(A; dims=1)
    for i_basis in eachindex(axes(A, 2), A_scales, mask)
        if !mask[i_basis]
            continue
        end
        s = A_scales[i_basis]
        if iszero(s)
            mask[i_basis] = false
        else
            A[:, i_basis] ./= s
        end
    end
    return A_scales
end

function mask_out_duplicate_bases!(
    mask::AbstractVector{Bool}, A::AbstractMatrix{T}
) where {T}
    basis_hashes = sizehint!(Dict{UInt,Bool}(), size(A, 2))
    for (i_basis, A_col) in enumerate(eachcol(A))
        basis_hash = hash(A_col)
        if haskey(basis_hashes, basis_hash)
            # There was already an identical basis function, so we mask this one
            mask[i_basis] = false
        else
            basis_hashes[basis_hash] = true
        end
    end
end

@testitem "Test masking of duplicate bases" begin
    using SymbolicRegression: mask_out_duplicate_bases!, normalize_bases!
    # using SymbolicRegression.SparseLinearExpansionModule: mask_out_duplicate_bases!, normalize_bases!

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

"""Sparse solver available for L2DistLoss"""
function find_sparse_linear_expression(
    rng::AbstractRNG,
    prototype::AbstractExpression,
    dataset::Dataset{T,L},
    options::Options;
    init_basis_size=128,
    max_final_basis_size=rand(rng, 3:20),  # TODO: Make this a parameter
    trim_n_percent_per_iter=50,
    max_iters=10,
    l2_regularization=1e-6,
    predefined_basis=nothing,
    min_num_nodes=1,
    max_num_nodes=5,
) where {T,L}
    assert_can_use_sparse_linear_expression(options)
    basis = if predefined_basis === nothing
        make_random_basis(
            rng,
            prototype,
            dataset,
            options,
            init_basis_size;
            min_num_nodes=min_num_nodes,
            max_num_nodes=max_num_nodes,
        )
    else
        predefined_basis
    end

    (A, mask) = let
        A_and_complete = map(
            let X = dataset.X
                b -> eval_tree_array(b, X, options)
            end,
            basis,
        )
        stack(map(first, A_and_complete)), map(last, A_and_complete)
    end
    y_scale = std(dataset.y)

    A
    # ^(n_rows, n_basis)
    mask
    # ^(n_basis,)
    normalized_y = dataset.y ./ y_scale
    # ^(n_rows,)

    coeffs = similar(A, axes(A, 2))

    # Make all basis functions have comparable standard deviation
    A_scales = normalize_bases!(A, mask)
    # ^(n_basis,)

    # Then, detect and mask duplicate basis functions
    mask_out_duplicate_bases!(mask, A)
    # TODO: Account for all-zero mask

    coeffs[mask] .= solve_linear_system(A[:, mask], normalized_y, l2_regularization)  # Initialize based on least squares
    # TODO: Account for singular matrices, if they are even possible

    # Now, we do iterative pruning of the coefficients, sort of like STLSQ,
    # but with pruning schedule similar to neural network pruning
    n_remaining = sum(mask)
    for _ in 1:max_iters
        max_prune_percentage = min(
            trim_n_percent_per_iter,
            100 * (n_remaining - max_final_basis_size) / n_remaining,
        )
        if max_prune_percentage <= 0
            break
        end
        threshold = percentile(abs.(coeffs[mask]), max_prune_percentage)
        # ^ Each time, we trim the smallest 50% of coefficients
        @. mask = mask & (abs(coeffs) > threshold)
        coeffs[mask] .= solve_linear_system(A[:, mask], normalized_y, l2_regularization)
        n_remaining = sum(mask)
        if n_remaining <= max_final_basis_size
            break
        end
    end

    # normalized_y ~ A * coeffs
    ## Therefore, to fix `coeffs` for regular `y`, we need to move
    ## the scale of `A` and `normalized_y` into `coeffs`.
    ## Since `A` is on the same side, we simply multiply it.
    ## Since `normalized_y` is on the other side, we divide it.

    # Update coeffs based on initial normalization
    coeffs[mask] ./= A_scales[mask]
    # Update coeffs based on y normalization
    coeffs[mask] .*= y_scale

    return coeffs[mask], basis[mask]
end
function find_sparse_linear_expression(
    prototype::AbstractExpression, dataset::Dataset, options::Options; kws...
)
    return find_sparse_linear_expression(default_rng(), prototype, dataset, options; kws...)
end

# end

@testitem "Bad expressions should be masked" begin
    using SymbolicRegression
    using SymbolicRegression: find_sparse_linear_expression
    # using SymbolicRegression.SparseLinearExpansionModule: find_sparse_linear_expression
    using Random: MersenneTwister

    options = Options(; binary_operators=[+, -, *, /], unary_operators=[sin, cos])

    x1 = Expression(
        Node{Float64}(; feature=1);
        operators=options.operators,
        variable_names=["x1", "x2", "x3", "x4", "x5"],
    )
    ex_div_0 = Expression(
        Node(; op=4, l=Node{Float64}(; feature=1), r=Node{Float64}(; val=0.0));
        operators=options.operators,
        variable_names=["x1", "x2", "x3", "x4", "x5"],
    )
    rng = MersenneTwister(0)
    X = randn(rng, 5, 32)
    y = randn(rng, 32)
    dataset = Dataset(X, y)

    coeffs, basis = find_sparse_linear_expression(
        rng, x1, dataset, options; predefined_basis=[x1, ex_div_0]
    )
    @test length(coeffs) == 1
    @test only(basis) == x1
end
@testitem "Smoke test linear expansion" begin
    using SymbolicRegression
    using SymbolicRegression: find_sparse_linear_expression
    # using SymbolicRegression.SparseLinearExpansionModule: find_sparse_linear_expression
    using Random: MersenneTwister

    options = Options(; binary_operators=[+, -, *, /], unary_operators=[sin, cos])
    rng = MersenneTwister(0)
    X = randn(rng, 5, 1024)
    y = @. 1.5 * X[1, :] * X[2, :] + 2.0 * X[3, :] * X[4, :] + 3.0 * X[5, :]
    dataset = Dataset(X, y)

    prototype_ex = Expression(
        Node{Float64}(; val=1.0);
        operators=options.operators,
        variable_names=["x1", "x2", "x3", "x4", "x5"],
    )
    coeffs, basis = find_sparse_linear_expression(
        rng, prototype_ex, dataset, options; max_final_basis_size=5
    )
    @test length(coeffs) == 5
    @test length(basis) == 5
    @test eltype(coeffs) == Float64
    @test eltype(basis) == typeof(prototype_ex)

    y_pred = sum(
        i -> coeffs[i] .* first(eval_tree_array(basis[i], X, options)), eachindex(coeffs)
    )
    pred_loss = sum(abs2, y_pred .- dataset.y)
    baseline_loss = sum(abs2, dataset.y)
    @test pred_loss < baseline_loss
end
