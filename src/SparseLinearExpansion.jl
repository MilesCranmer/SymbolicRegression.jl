"""This module defines a mutation which solves for a sparse linear expansion at some node."""
module SparseLinearExpansionModule

using DynamicExpressions: AbstractExpression, with_contents, eval_tree_array
using LossFunctions: L2DistLoss
using Random: AbstractRNG, default_rng
using StatsBase: std, percentile

using ..CoreModule: Options, Dataset
using ..PopMemberModule: PopMember
using ..MutationFunctionsModule: gen_random_tree_fixed_size

function make_random_basis(
    rng::AbstractRNG, prototype::AbstractExpression, dataset::Dataset{T,L}, options::Options
) where {T,L}
    basis_functions = [copy(prototype) for _ in 1:128]  # TODO: Make this a parameter
    for i in eachindex(basis_functions)
        num_nodes = rand(rng, 1:5)  # TODO: Make this a parameter
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

"""Sparse solver available for L2DistLoss"""
function find_sparse_linear_expression(
    rng::AbstractRNG,
    prototype::AbstractExpression,
    dataset::Dataset{T,L},
    options::Options,
    desired_final_basis_size=rand(rng, 5:20),  # TODO: Make this a parameter
) where {T,L}
    assert_can_use_sparse_linear_expression(options)
    basis = make_random_basis(rng, prototype, dataset, options)

    (A, mask) = let
        A_and_complete = map(
            let X = dataset.X
                b -> eval_tree_array(b, X, options)
            end,
            basis,
        )
        stack(map(first, A_and_complete)), map(last, A_and_complete)
    end
    A::AbstractMatrix{T}
    A             # (n_rows, n_basis)
    mask          # (n_basis,)
    y = dataset.y # (n_rows,)

    coeffs = similar(A, axes(A, 2))

    # Make all basis functions have comparable standard deviation
    scales = std(A; dims=1)
    for i_basis in eachindex(axes(A, 2), scales, mask)
        s = scales[i_basis]
        if iszero(s)
            mask[i_basis] = false
        else
            for i_row in eachindex(axes(A, 1))
                A[i_row, i_basis] /= s
            end
        end
    end
    # TODO: Account for all-zero mask

    @view(coeffs[mask]) .= @view(A[:, mask]) \ y  # Initialize based on least squares
    # TODO: Account for singular matrices
    # TODO: Verify that using `@view` here doen't cause performance issues

    # Now, we do iterative pruning of the coefficients, sort of like STLSQ,
    # but with pruning schedule similar to neural network pruning
    max_iters = 1000
    for _ in 1:max_iters
        let threshold = percentile(@view(coeffs[mask]), 50)
            # ^ Each time, we trim the smallest 50% of coefficients
            @. mask = mask && abs(coeffs) > threshold
            @view(coeffs[mask]) .= @view(A[:, mask]) \ y
        end
        @show sum(mask)
        if sum(mask) < desired_final_basis_size
            break
        end
    end

    # Update coeffs based on initial normalization
    @view(coeffs[mask]) .*= @view(scales[mask])

    return coeffs[mask], basis[mask]
end
function find_sparse_linear_expression(
    prototype::AbstractExpression, dataset::Dataset, options::Options, args...
)
    return find_sparse_linear_expression(default_rng(), prototype, dataset, options)
end

end

using TestItems: @testitem

@testitem "Test random basis" begin
    using SymbolicRegression
    using SymbolicRegression.SparseLinearExpansionModule: find_sparse_linear_expression
    using Random: MersenneTwister

    options = Options(; binary_operators=[+, -, *, /], unary_operators=[sin, cos])
    rng = MersenneTwister(0)
    X = randn(rng, 5, 32)
    y = @. 1.5 * X[1, :] * X[2, :] + 2.0 * X[3, :] * X[4, :] + 3.0 * X[5, :]
    dataset = Dataset(X, y)

    ex = Expression(
        Node{Float64}(; val=1.0);
        operators=options.operators,
        variable_names=["x1", "x2", "x3", "x4", "x5"],
    )

    coeffs, basis = find_sparse_linear_expression(ex, dataset, options, 5)
    for i in eachindex(basis, coeffs)
        @info "basis and coeffs" basis[i] coeffs[i]
    end
end
