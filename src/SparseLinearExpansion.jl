"""This module defines a mutation which solves for a sparse linear expansion at some node."""
module SparseLinearExpansionModule

using DynamicExpressions: AbstractExpression, with_contents, eval_tree_array
using LossFunctions: L2DistLoss
using Random: AbstractRNG, default_rng
using StatsBase: std, percentile
using LinearAlgebra: I

using ..CoreModule: Options, Dataset
using ..PopMemberModule: PopMember
using ..MutationFunctionsModule: gen_random_tree_fixed_size

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

function solve_linear_system(
    A::AbstractMatrix{T}, y::AbstractVector{T}, regularization::Real
) where {T}
    n = size(A, 2)  # number of features
    ATA = A'A
    ATy = A'y
    return (ATA + regularization * I(n)) \ ATy
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

    # Update coeffs based on implicit normalizations
    coeffs[mask] ./= A_scales[mask]
    coeffs[mask] .*= y_scale

    return coeffs[mask], basis[mask]
end
function find_sparse_linear_expression(
    prototype::AbstractExpression, dataset::Dataset, options::Options; kws...
)
    return find_sparse_linear_expression(default_rng(), prototype, dataset, options; kws...)
end

end
