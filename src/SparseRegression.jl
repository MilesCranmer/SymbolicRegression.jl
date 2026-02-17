module SparseRegressionModule

using LinearAlgebra: norm
using Statistics: median
using Random: AbstractRNG, default_rng
using DispatchDoctor: @unstable
using DynamicExpressions:
    AbstractExpressionNode,
    OperatorEnum,
    constructorof,
    eval_tree_array,
    string_tree

using ..CoreModule: AbstractOptions, DATA_TYPE, Dataset

"""
    stlsq(Theta::AbstractMatrix{T}, y::AbstractVector{T}; lambda::T, max_iter::Int) -> (ξ::Vector{T}, success::Bool)

Sequential Thresholded Least Squares algorithm for sparse regression.

Iteratively solves the sparse regression problem: `Theta * ξ ≈ y` where ξ is sparse.

# Arguments
- `Theta::AbstractMatrix{T}`: Library matrix (n_samples × n_features)
- `y::AbstractVector{T}`: Target vector (n_samples)
- `lambda::T`: Sparsification threshold (default: 0.01)
- `max_iter::Int`: Maximum number of iterations (default: 10)

# Returns
- `ξ::Vector{T}`: Sparse coefficient vector
- `success::Bool`: Whether the algorithm succeeded (false if all coefficients are zero)

# Algorithm
1. Normalise library columns for numerical stability
2. Compute initial least squares solution
3. Iteratively threshold small coefficients and re-solve on active set
4. Denormalise and return coefficients

# References
- Brunton, S. L., Proctor, J. L., & Kutz, J. N. (2016). Discovering governing equations from data by sparse identification of nonlinear dynamical systems. PNAS, 113(15), 3932-3937.
"""
function stlsq(
    Theta::AbstractMatrix{T},
    y::AbstractVector{T};
    lambda::T=T(0.01),
    max_iter::Int=10,
) where {T<:DATA_TYPE}
    n_samples, n_features = size(Theta)

    # Check dimensions
    if length(y) != n_samples
        return zeros(T, n_features), false
    end

    # Normalise columns
    col_norms = vec(sqrt.(sum(Theta .^ 2; dims=1)))
    # Avoid division by zero
    col_norms = max.(col_norms, eps(T))
    Theta_normalised = Theta ./ col_norms'

    # Initial least squares solution
    ξ = Theta_normalised \ y

    # Iterative thresholding
    for iter in 1:max_iter
        # Threshold: zero out small coefficients
        small_inds = abs.(ξ) .< lambda

        # Identify active (non-zero) coefficients
        active_inds = .!small_inds

        # If no active coefficients, return failure
        if !any(active_inds)
            return zeros(T, n_features), false
        end

        # Re-solve on active set only
        Theta_active = Theta_normalised[:, active_inds]
        ξ_active = Theta_active \ y

        # Update coefficients
        ξ_new = zeros(T, n_features)
        ξ_new[active_inds] = ξ_active

        # Check convergence
        if norm(ξ_new - ξ) < eps(T) * 10
            ξ = ξ_new
            break
        end
        ξ = ξ_new
    end

    # Denormalise coefficients
    ξ ./= col_norms

    # Check if result is valid
    success = any(abs.(ξ) .> eps(T) * 100)

    return ξ, success
end

"""
    build_sindy_library(
        tree_prototype::AbstractExpressionNode{T},
        dataset::Dataset{T},
        options::AbstractOptions,
        nfeatures::Int;
        max_library_size::Int=500,
        gen_random_tree_fn::Union{Function, Nothing}=nothing,
        rng::AbstractRNG=default_rng()
    ) -> (library_trees::Vector, Theta::Matrix{T}, success::Bool)

Build a library of candidate functions for sparse regression.

Seeds the library with a constant term and all raw features, then fills
the remaining slots (up to `max_library_size`, capped at 100) with randomly
generated expression trees via `gen_random_tree_fn`. If `gen_random_tree_fn`
is `nothing`, only the seed terms are included.

# Arguments
- `tree_prototype::AbstractExpressionNode{T}`: Prototype node for creating library trees
- `dataset::Dataset{T}`: Dataset containing input features
- `options::AbstractOptions`: Options containing operator definitions
- `nfeatures::Int`: Number of input features
- `max_library_size::Int`: Maximum number of library terms (default: 500)
- `gen_random_tree_fn::Union{Function, Nothing}`: Function with signature
  `(node_count, options, nfeatures, T, rng) -> tree` used to generate random
  candidate trees. Typically `gen_random_tree_fixed_size`. If `nothing`, only
  seed terms (constant + features) are included.
- `rng::AbstractRNG`: Random number generator for tree generation

# Returns
- `library_trees::Vector`: Vector of expression trees representing library terms
- `Theta::Matrix{T}`: Library matrix (n_samples × n_library_terms)
- `success::Bool`: Whether library construction succeeded
"""
function build_sindy_library(
    tree_prototype::AbstractExpressionNode{T},
    dataset::Dataset{T},
    options::AbstractOptions,
    nfeatures::Int;
    max_library_size::Int=500,
    gen_random_tree_fn::Union{Function,Nothing}=nothing,
    rng::AbstractRNG=default_rng(),
) where {T<:DATA_TYPE}
    library_trees = Vector{typeof(tree_prototype)}()
    n_samples = size(dataset.X, 2)

    # 1. Seed terms: constant and all raw features (always included)
    constant_tree = constructorof(typeof(tree_prototype))(T; val=one(T))
    push!(library_trees, constant_tree)

    for i in 1:nfeatures
        feature_tree = constructorof(typeof(tree_prototype))(T; feature=i)
        push!(library_trees, feature_tree)
    end

    # 2. Fill remaining slots with randomly generated trees
    if gen_random_tree_fn !== nothing
        n_random = min(100, max(0, max_library_size - length(library_trees)))
        for _ in 1:n_random
            node_count = rand(rng, 1:5)
            candidate = gen_random_tree_fn(node_count, options, nfeatures, T, rng)
            push!(library_trees, candidate)
        end
    end

    # 3. Evaluate all library trees to build Theta matrix
    Theta = zeros(T, n_samples, length(library_trees))
    valid_trees = Vector{typeof(tree_prototype)}()
    col = 0

    for lib_tree in library_trees
        evaluated_values, eval_success = eval_tree_array(
            lib_tree, dataset.X, options.operators
        )

        if eval_success && !any(isnan, evaluated_values) && !any(isinf, evaluated_values)
            col += 1
            Theta[:, col] = evaluated_values
            push!(valid_trees, lib_tree)
        end
    end
    Theta = Theta[:, 1:col]  # trim unused columns

    # Return failure if library is empty
    if isempty(valid_trees)
        return valid_trees, Theta, false
    end

    return valid_trees, Theta, true
end

"""
    collect_all_subtrees!(subtrees::Vector, node::AbstractExpressionNode)

Recursively collect all subtrees (including the node itself) from an expression tree.
Each node in the tree is the root of a subtree.
"""
function collect_all_subtrees!(
    subtrees::Vector{N}, node::N
) where {T,N<:AbstractExpressionNode{T}}
    push!(subtrees, node)
    if node.degree >= 1
        collect_all_subtrees!(subtrees, node.l)
    end
    if node.degree == 2
        collect_all_subtrees!(subtrees, node.r)
    end
    return subtrees
end

"""
    build_adaptive_library(
        tree_prototype::AbstractExpressionNode{T},
        dataset::Dataset{T},
        options::AbstractOptions,
        nfeatures::Int,
        population;
        max_library_size::Int=200,
        top_k::Int=10
    ) -> (library_trees::Vector, Theta::Matrix{T}, success::Bool)

Build an adaptive library by extracting subtrees from the population's best members.

Instead of random trees, this uses subtrees that the GP has already discovered to be
useful. The library evolves alongside the GP — structures that keep appearing in
good solutions become available for STLSQ to recombine.

# Arguments
- `tree_prototype::AbstractExpressionNode{T}`: Prototype node for type information
- `dataset::Dataset{T}`: Dataset containing input features
- `options::AbstractOptions`: Options containing operator definitions
- `nfeatures::Int`: Number of input features
- `population`: Current population to extract subtrees from (duck-typed, must have `.members` and `.n`)
- `max_library_size::Int`: Maximum number of library terms (default: 200)
- `top_k::Int`: Number of top members to extract subtrees from (default: 10)

# Returns
- `library_trees::Vector`: Vector of expression trees representing library terms
- `Theta::Matrix{T}`: Library matrix (n_samples × n_library_terms)
- `success::Bool`: Whether library construction succeeded
"""
function build_adaptive_library(
    tree_prototype::AbstractExpressionNode{T},
    dataset::Dataset{T},
    options::AbstractOptions,
    nfeatures::Int,
    population;
    max_library_size::Int=200,
    top_k::Int=10,
) where {T<:DATA_TYPE}
    library_trees = Vector{typeof(tree_prototype)}()
    n_samples = size(dataset.X, 2)

    # 1. Seed terms: constant and all raw features (always included)
    constant_tree = constructorof(typeof(tree_prototype))(T; val=one(T))
    push!(library_trees, constant_tree)

    for i in 1:nfeatures
        feature_tree = constructorof(typeof(tree_prototype))(T; feature=i)
        push!(library_trees, feature_tree)
    end

    # 2. Get top-k members by loss (lower is better) - only if population is provided
    all_subtrees = Vector{typeof(tree_prototype)}()
    if population !== nothing
        sorted_members = sort(population.members[1:population.n], by=m -> m.loss)
        top_members = sorted_members[1:min(top_k, length(sorted_members))]

        # 3. Extract all subtrees from top members
        for member in top_members
            # Get the tree from the expression
            tree = member.tree
            if tree isa AbstractExpressionNode
                collect_all_subtrees!(all_subtrees, tree)
            else
                # Handle Expression wrapper - get the underlying node
                inner_tree = tree.tree
                if inner_tree isa AbstractExpressionNode
                    collect_all_subtrees!(all_subtrees, inner_tree)
                end
            end
        end
    end

    # 4. Deduplicate by string representation
    seen_strings = Set{String}()
    unique_subtrees = Vector{typeof(tree_prototype)}()
    for subtree in all_subtrees
        s = string_tree(subtree, options)
        if !(s in seen_strings)
            push!(seen_strings, s)
            push!(unique_subtrees, subtree)
        end
    end

    # 5. Add unique subtrees to library (up to max size)
    n_to_add = min(length(unique_subtrees), max_library_size - length(library_trees))
    for i in 1:n_to_add
        push!(library_trees, copy(unique_subtrees[i]))
    end

    # 6. Evaluate all library trees to build Theta matrix
    Theta = zeros(T, n_samples, length(library_trees))
    valid_trees = Vector{typeof(tree_prototype)}()
    col = 0

    for lib_tree in library_trees
        evaluated_values, eval_success = eval_tree_array(
            lib_tree, dataset.X, options.operators
        )

        if eval_success && !any(isnan, evaluated_values) && !any(isinf, evaluated_values)
            col += 1
            Theta[:, col] = evaluated_values
            push!(valid_trees, lib_tree)
        end
    end
    Theta = Theta[:, 1:col]  # trim unused columns

    # Return failure if library is empty
    if isempty(valid_trees)
        return valid_trees, Theta, false
    end

    return valid_trees, Theta, true
end

"""
    combine_trees_weighted_sum(
        trees::Vector{N},
        coefficients::Vector{T},
        options::AbstractOptions
    ) -> Union{N, Nothing}

Combine multiple expression trees into a weighted sum: c1*tree1 + c2*tree2 + ...

# Arguments
- `trees::Vector{N}`: Vector of expression trees to combine
- `coefficients::Vector{T}`: Coefficients for each tree
- `options::AbstractOptions`: Options containing operator definitions

# Returns
- Combined expression tree, or `nothing` if combination fails

# Notes
- Requires `+` operator for summing multiple terms
- Requires `*` operator for weighting terms (if coefficient ≠ 1)
- Falls back gracefully if operators are missing
"""
@unstable function combine_trees_weighted_sum(
    trees::Vector{N}, coefficients::Vector{T}, options::AbstractOptions
)::Union{Nothing,N} where {T<:DATA_TYPE,N<:AbstractExpressionNode{T}}
    # Filter to non-zero coefficients
    active_indices = findall(abs.(coefficients) .> eps(T) * 100)

    if isempty(active_indices)
        return nothing
    end

    active_trees = trees[active_indices]
    active_coeffs = coefficients[active_indices]

    # Single term - just multiply by coefficient if needed
    if length(active_indices) == 1
        tree = active_trees[1]
        coeff = active_coeffs[1]

        # If coefficient ≈ 1.0, return tree as-is
        if abs(coeff - one(T)) < eps(T) * 100
            return tree
        end

        # Otherwise multiply: coeff * tree
        mult_idx = findfirst(op -> op === (*), options.operators.binops)
        if mult_idx === nothing
            # No multiplication available, return unscaled tree
            return tree
        end

        coeff_node = constructorof(typeof(tree))(T; val=coeff)
        return constructorof(typeof(tree))(; op=mult_idx, children=(coeff_node, tree))
    end

    # Multiple terms - need addition operator
    add_idx = findfirst(op -> op === (+), options.operators.binops)
    if add_idx === nothing
        # No addition operator - return tree with largest coefficient
        max_idx = argmax(abs.(active_coeffs))
        return active_trees[max_idx]
    end

    mult_idx = findfirst(op -> op === (*), options.operators.binops)

    # Build weighted terms
    weighted_trees = Vector{N}()
    for (tree, coeff) in zip(active_trees, active_coeffs)
        if abs(coeff - one(T)) < eps(T) * 100
            # Coefficient is 1, use tree directly
            push!(weighted_trees, tree)
        elseif mult_idx !== nothing
            # Multiply by coefficient
            coeff_node = constructorof(typeof(tree))(T; val=coeff)
            weighted = constructorof(typeof(tree))(;
                op=mult_idx, children=(coeff_node, tree)
            )
            push!(weighted_trees, weighted)
        else
            # No multiplication operator, use unweighted tree
            push!(weighted_trees, tree)
        end
    end

    # Sum all weighted trees: tree1 + tree2 + tree3 + ...
    result = weighted_trees[1]
    for i in 2:length(weighted_trees)
        result = constructorof(typeof(result))(;
            op=add_idx, children=(result, weighted_trees[i])
        )
    end

    return result
end

"""
    fit_sparse_expression(
        tree_prototype::AbstractExpressionNode{T},
        inverted_values::AbstractVector{T},
        dataset::Dataset{T},
        options::AbstractOptions,
        nfeatures::Int;
        lambda::T=T(0.01),
        max_iter::Int=10,
        max_library_size::Int=500,
        rng::AbstractRNG=default_rng(),
        validate::Bool=false,
        max_mse::T=T(Inf),
        population=nothing
    ) -> Union{AbstractExpressionNode{T}, Nothing}

Fit a sparse symbolic expression to target values using SINDy-style sparse regression.

Uses an adaptive library built from population subtrees (Option B): extracts useful
subtrees from the top-k population members to form a candidate library, then applies
STLSQ to find a sparse linear combination.

Returns `nothing` immediately if `+` and `*` are not both present in the
operator set, since the output is structurally a weighted sum.

# Arguments
- `tree_prototype`: Prototype node for creating trees
- `inverted_values`: Target values to fit
- `dataset`: Dataset containing input features
- `options`: Options containing operator definitions
- `nfeatures`: Number of input features
- `lambda`: Sparsity threshold for STLSQ (default: 0.01)
- `max_iter`: Maximum STLSQ iterations (default: 10)
- `max_library_size`: Maximum library size (default: 500)
- `rng`: Random number generator
- `validate`: Validate fit quality before accepting (default: false)
- `max_mse`: Maximum acceptable MSE for validation (default: Inf)
- `population`: Population to extract subtrees from for adaptive library.

# Returns
- Fitted expression tree, or `nothing` if fitting fails
"""
@unstable function fit_sparse_expression(
    tree_prototype::AbstractExpressionNode{T},
    inverted_values::AbstractVector{T},
    dataset::Dataset{T},
    options::AbstractOptions,
    nfeatures::Int;
    lambda::T=T(0.01),
    max_iter::Int=10,
    max_library_size::Int=500,
    rng::AbstractRNG=default_rng(),
    validate::Bool=false,
    max_mse::T=T(Inf),
    population=nothing,
) where {T<:DATA_TYPE}
    # Guard: sparse regression output is a weighted sum, requires both + and *
    add_idx = findfirst(op -> op === (+), options.operators.binops)
    mult_idx = findfirst(op -> op === (*), options.operators.binops)
    if add_idx === nothing || mult_idx === nothing
        return nothing
    end

    # Build adaptive library from population subtrees
    # This extracts useful subtrees from the best population members
    library_trees, Theta, lib_success = build_adaptive_library(
        tree_prototype, dataset, options, nfeatures, population;
        max_library_size=max_library_size,
    )

    if !lib_success || isempty(library_trees)
        return nothing
    end

    # Perform sparse regression
    coefficients, stlsq_success = stlsq(Theta, inverted_values; lambda=lambda, max_iter=max_iter)

    if !stlsq_success
        return nothing
    end

    # Combine trees with coefficients
    result_tree = combine_trees_weighted_sum(library_trees, coefficients, options)

    if result_tree === nothing
        return nothing
    end

    # Optional validationRegularizedEvolution.jl
    if validate
        predicted, eval_success = eval_tree_array(result_tree, dataset.X, options.operators)

        if !eval_success || any(isnan, predicted) || any(isinf, predicted)
            return nothing
        end

        mse = sum((predicted .- inverted_values) .^ 2) / length(inverted_values)
        if mse > max_mse
            return nothing
        end
    end

    return result_tree
end

end
