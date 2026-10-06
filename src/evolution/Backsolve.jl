module BacksolveModule

using LinearAlgebra: Hermitian, I, PosDefException, cholesky, diag, dot, norm
using DispatchDoctor: @unstable
using DynamicExpressions: AbstractExpressionNode, constructorof, eval_tree_array, get_tree

using ...InterfacesModule.OptionsInterfaceModule: AbstractOptions
using ...InterfacesModule.ProgramConstantsModule: DATA_TYPE
using ...InterfacesModule.DatasetModule: Dataset
using ...InterfacesModule.MutationsModule: BacksolveMutation
using ...ConfigModule.OptionsStructModule: specialized_options
using ...EvaluationModule.ComplexityModule: compute_complexity

const STLSQ_DATA_TYPE = Union{AbstractFloat,Complex{<:AbstractFloat}}

function configured_backsolve(options::AbstractOptions)
    for (mutation, weight) in options.mutations
        mutation isa BacksolveMutation && weight > 0.0 && return mutation
    end
    throw(ArgumentError("BacksolveMutation is not enabled in `options.mutations`."))
end

"""
    _solve_gram(G, g, col_norms)

Solve the normal equations `G x = g` of the column-normalised least-squares
problem via a Cholesky factorisation, adding an escalating Tikhonov ridge
when the Gram matrix is numerically singular. Returns an all-zero vector
when no ridge makes the system solvable, which callers treat as a failed
fit. Working with the precomputed Gram matrix `G = theta' * theta` makes
each solve cost `O(k^3)` in the number of active terms rather than a full
QR factorisation of the library.
"""
function _solve_gram(
    G::AbstractMatrix{T}, g::AbstractVector{T}, col_norms::AbstractVector{<:Real}
)::Vector{T} where {T<:STLSQ_DATA_TYPE}
    A = G ./ (col_norms * col_norms')
    b = g ./ col_norms
    R = typeof(float(real(zero(T))))
    try
        return cholesky(Hermitian(A)) \ b
    catch err
        err isa PosDefException || rethrow()
    end
    ridge = R(1e-10)
    for _ in 1:3
        try
            return cholesky(Hermitian(A + ridge * I)) \ b
        catch err
            err isa PosDefException || rethrow()
            ridge *= R(100)
        end
    end
    return zeros(T, length(b))
end

"""
    BasisLibrary(terms::Vector{N}, evaluated_terms::Matrix{T})

Basis terms and their evaluated values for the sparse-expression fit.
"""
struct BasisLibrary{T,N<:AbstractExpressionNode{T}}
    terms::Vector{N}
    evaluated_terms::Matrix{T}
    n_evaluated::Int

    function BasisLibrary(
        terms::Vector{N}, evaluated_terms::Matrix{T}, n_evaluated::Int=length(terms)
    ) where {T,N<:AbstractExpressionNode{T}}
        size(evaluated_terms, 2) == length(terms) || throw(
            ArgumentError("BasisLibrary requires one evaluated_terms column per term.")
        )
        return new{T,N}(terms, evaluated_terms, n_evaluated)
    end
end

"""
    stlsq(theta::AbstractMatrix{T}, y::AbstractVector{T}; lambda::Real, max_iter::Int) -> (coefficients::Vector{T}, success::Bool)

Sequential thresholded least squares for `theta * coefficients ~= y`.

# Arguments
- `theta::AbstractMatrix{T}`: Library matrix (n_samples x n_features)
- `y::AbstractVector{T}`: Target vector (n_samples)
- `lambda::Real`: Sparsification threshold (default: 0.01)
- `max_iter::Int`: Maximum number of iterations (default: 10)

# Returns
- `coefficients::Vector{T}`: Sparse coefficient vector
- `success::Bool`: Whether the algorithm succeeded (false if all coefficients are zero)

# References
- Brunton, S. L., Proctor, J. L., & Kutz, J. N. (2016). Discovering governing equations from data by sparse identification of nonlinear dynamical systems. PNAS, 113(15), 3932-3937.
"""
function stlsq(
    theta::AbstractMatrix{T}, y::AbstractVector{T}; lambda::Real=0.01, max_iter::Int=10
) where {T<:STLSQ_DATA_TYPE}
    n_samples, n_features = size(theta)

    if length(y) != n_samples
        return zeros(T, n_features), false
    end

    G = theta' * theta
    g = theta' * y
    return _stlsq_gram(G, g; lambda=lambda, max_iter=max_iter)
end

function _stlsq_gram(
    G::AbstractMatrix{T}, g::AbstractVector{T}; lambda::Real=0.01, max_iter::Int=10
)::Tuple{Vector{T},Bool} where {T<:STLSQ_DATA_TYPE}
    n_features = length(g)
    R = typeof(float(real(zero(T))))
    tol = eps(R)
    threshold = R(lambda)

    col_norms = sqrt.(max.(real.(diag(G)), zero(R)))
    col_norms = max.(col_norms, tol)

    coefficients = _solve_gram(G, g, col_norms)

    for iter in 1:max_iter
        small_inds = abs.(coefficients) .< threshold
        active_inds = .!small_inds

        if !any(active_inds)
            return zeros(T, n_features), false
        end

        coefficients_active = _solve_gram(
            G[active_inds, active_inds], g[active_inds], col_norms[active_inds]
        )

        coefficients_new = zeros(T, n_features)
        coefficients_new[active_inds] = coefficients_active

        if norm(coefficients_new - coefficients) < tol * 10
            coefficients = coefficients_new
            break
        end
        coefficients = coefficients_new
    end

    coefficients ./= col_norms
    success = any(abs.(coefficients) .> tol * 100)

    return coefficients, success
end

"""
    weighted_sum_costs(terms, tree_prototype, options) -> (term_costs, join_cost, addend_overhead)

Complexity cost of including each library term as a `coefficient * term`
addend in a weighted sum, the incremental complexity of each `+` join, and
the fixed per-addend overhead (coefficient constant plus multiplication).
Uses `compute_complexity`, so custom per-operator complexities are respected.
"""
function weighted_sum_costs(
    terms::AbstractVector{N}, tree_prototype::N, options::AbstractOptions
)::Tuple{Vector{Int},Int,Int} where {T,N<:AbstractExpressionNode{T}}
    add_idx = something(findfirst(op -> op === (+), options.operators.binops))
    mult_idx = something(findfirst(op -> op === (*), options.operators.binops))

    c1 = constructorof(N)(; val=one(T))
    c2 = constructorof(N)(; val=one(T))
    constant_cost = compute_complexity(c1, options)
    mult_cost =
        compute_complexity(constructorof(N)(; op=mult_idx, children=(c1, c2)), options) -
        2 * constant_cost
    join_cost =
        compute_complexity(constructorof(N)(; op=add_idx, children=(c1, c2)), options) -
        2 * constant_cost

    addend_overhead = constant_cost + mult_cost
    term_costs = [compute_complexity(term, options) + addend_overhead for term in terms]
    return term_costs, join_cost, addend_overhead
end

"""
    greedy_forward_selection_gram(
        G, g, yy;
        term_costs, join_cost, budget, max_terms, min_improvement,
    ) -> (coefficients, success)

Sparse fit of `theta * coefficients ~= y` by greedy forward selection
(orthogonal matching pursuit with a complexity budget), working entirely on
the precomputed Gram matrix `G = theta' * theta`, the cross vector
`g = theta' * y`, and `yy = sum(abs2, y)`.

At each step the column with the largest absolute correlation to the current
residual is added, restricted to columns whose `term_costs[j]` (plus
`join_cost` for every term after the first) still fit in the remaining
`budget`. The active set is refit by least squares after every addition.
Selection stops when the budget or `max_terms` is exhausted, when the
residual is numerically zero, or when the best candidate shrinks the
residual norm by a relative factor smaller than `min_improvement`.

Unlike thresholded least squares, this is invariant to the scale of `y` and
of the individual columns, and the sparsity of the result is controlled
directly by the complexity budget rather than a coefficient-magnitude
cutoff.
"""
function greedy_forward_selection_gram(
    G::AbstractMatrix{T},
    g::AbstractVector{T},
    yy::Real;
    term_costs::AbstractVector{Int},
    join_cost::Int,
    budget::Union{Int,Nothing},
    max_terms::Int,
    min_improvement::Real,
)::Tuple{Vector{T},Bool} where {T<:STLSQ_DATA_TYPE}
    n_features = length(g)
    coefficients = zeros(T, n_features)
    (n_features > 0 && size(G, 1) == n_features && size(G, 2) == n_features) ||
        return coefficients, false

    R = typeof(float(real(zero(T))))
    tol = eps(R)

    col_norms = sqrt.(max.(real.(diag(G)), zero(R)))
    usable = col_norms .> tol
    any(usable) || return coefficients, false
    col_norms = max.(col_norms, tol)

    G_normalised = G ./ (col_norms * col_norms')
    g_normalised = g ./ col_norms

    remaining = budget === nothing ? typemax(Int) : budget
    active = sizehint!(Int[], max_terms)
    x_active = T[]
    residual_norm = sqrt(R(max(yy, zero(yy))))
    y_scale = max(residual_norm, one(R))
    corr_resid = copy(g_normalised)

    while length(active) < max_terms
        extra = isempty(active) ? 0 : join_cost
        best_j = 0
        best_corr = zero(R)
        for j in 1:n_features
            (usable[j] && !(j in active) && term_costs[j] + extra <= remaining) || continue
            corr = abs(corr_resid[j])
            if corr > best_corr
                best_corr = corr
                best_j = j
            end
        end
        best_j == 0 && break

        trial = push!(copy(active), best_j)
        x_trial = _solve_gram(G[trial, trial], g[trial], col_norms[trial])
        trial_norm = sqrt(
            R(
                max(
                    yy - 2 * real(dot(x_trial, g_normalised[trial])) +
                    real(dot(x_trial, G_normalised[trial, trial] * x_trial)),
                    zero(yy),
                ),
            ),
        )

        improvement = (residual_norm - trial_norm) / max(residual_norm, tol * y_scale)
        !(improvement >= min_improvement) && break

        active = trial
        x_active = x_trial
        residual_norm = trial_norm
        remaining -= term_costs[best_j] + extra

        residual_norm <= tol * 100 * y_scale && break
        corr_resid = g_normalised - G_normalised[:, active] * x_active
    end

    isempty(active) && return coefficients, false
    coefficients[active] = x_active ./ col_norms[active]
    success = any(abs.(coefficients) .> tol * 100)
    return coefficients, success
end

"""
    build_basis_library(
        tree_prototype::AbstractExpressionNode{T},
        dataset::Dataset{T},
        options::AbstractOptions,
        nfeatures::Int,
        population;
        max_library_size::Int=200,
        top_k::Int=10
    ) -> BasisLibrary

Build a basis library from seed terms and population subtrees.

!!! warning
    This API supports an experimental mutation and will change in minor version
    increments.

# Arguments
- `tree_prototype::AbstractExpressionNode{T}`: Prototype node for type information
- `dataset::Dataset{T}`: Dataset containing input features
- `options::AbstractOptions`: Options containing operator definitions
- `nfeatures::Int`: Number of input features
- `population`: Current population to extract subtrees from (duck-typed, must have `.members` and `.n`)
- `max_library_size::Int`: Maximum number of library terms (default: 200).
  Must be at least `1 + nfeatures` to include the constant and feature terms.
- `top_k::Int`: Number of top members to extract subtrees from (default: 10)

# Returns
- `BasisLibrary`: Basis terms and their evaluated values
"""
function build_basis_library(
    tree_prototype::N,
    dataset::Dataset{T},
    options::AbstractOptions,
    nfeatures::Int,
    population;
    max_library_size::Int=200,
    top_k::Int=10,
)::BasisLibrary{T,N} where {T<:DATA_TYPE,N<:AbstractExpressionNode{T}}
    return _build_basis_library(
        tree_prototype,
        dataset,
        specialized_options(options),
        nfeatures,
        population;
        max_library_size,
        top_k,
    )
end

function _build_basis_library(
    tree_prototype::N,
    dataset::Dataset{T},
    options::AbstractOptions,
    nfeatures::Int,
    population;
    max_library_size::Int,
    top_k::Int,
)::BasisLibrary{T,N} where {T<:DATA_TYPE,N<:AbstractExpressionNode{T}}
    min_library_size = 1 + nfeatures
    if max_library_size < min_library_size
        throw(
            ArgumentError(
                "build_basis_library requires max_library_size >= 1 + nfeatures; got max_library_size=$(max_library_size), nfeatures=$(nfeatures).",
            ),
        )
    end

    terms = sizehint!(Vector{typeof(tree_prototype)}(), max_library_size)
    n_samples = size(dataset.X, 2)

    constant_tree = constructorof(typeof(tree_prototype))(; val=one(T))
    push!(terms, constant_tree)

    for i in 1:nfeatures
        feature_tree = constructorof(typeof(tree_prototype))(T; feature=i)
        push!(terms, feature_tree)
    end

    all_subtrees = sizehint!(Vector{typeof(tree_prototype)}(), max_library_size)
    if population !== nothing
        sorted_members = sort(population.members[1:(population.n)]; by=m -> m.loss)
        top_members = sorted_members[1:min(top_k, length(sorted_members))]
        all_subtrees = mapreduce(
            member -> collect(get_tree(member.tree)), vcat, top_members; init=all_subtrees
        )
    end

    n_to_add = min(length(all_subtrees), max_library_size - length(terms))
    for i in 1:n_to_add
        push!(terms, copy(all_subtrees[i]))
    end

    evaluated_terms = zeros(T, n_samples, length(terms))
    valid_terms = sizehint!(Vector{typeof(tree_prototype)}(), length(terms))
    col = 0
    column_hashes = Dict{UInt,Int}()

    for term in terms
        evaluated_values, eval_success = eval_tree_array(term, dataset.X, options.operators)

        if eval_success && !any(isnan, evaluated_values) && !any(isinf, evaluated_values)
            # Skip terms that are numerically identical to an existing column;
            # they carry no new information and only add collinearity.
            h = hash(evaluated_values)
            j = get(column_hashes, h, 0)
            j != 0 && evaluated_terms[:, j] == evaluated_values && continue
            col += 1
            column_hashes[h] = col
            evaluated_terms[:, col] = evaluated_values
            push!(valid_terms, term)
        end
    end
    evaluated_terms = evaluated_terms[:, 1:col]

    return BasisLibrary(valid_terms, evaluated_terms, length(terms))
end

function _has_weighted_sum_operators(options::AbstractOptions)::Bool
    return (+) in options.operators.binops && (*) in options.operators.binops
end

"""
    combine_trees_weighted_sum(
        trees::Vector{N},
        coefficients::Vector{T},
        options::AbstractOptions
    ) -> Union{N, Nothing}

Combine expression terms into a weighted sum.

!!! warning
    This API supports an experimental mutation and will change in minor version
    increments.

# Arguments
- `trees::Vector{N}`: Vector of expression trees to combine
- `coefficients::Vector{T}`: Coefficients for each tree
- `options::AbstractOptions`: Options containing operator definitions

# Returns
- Combined expression tree, or `nothing` if combination fails

"""
@unstable function combine_trees_weighted_sum(
    trees::Vector{N}, coefficients::Vector{T}, options::AbstractOptions
)::Union{Nothing,N} where {T<:STLSQ_DATA_TYPE,N<:AbstractExpressionNode{T}}
    _has_weighted_sum_operators(options) || return nothing
    add_idx = something(findfirst(op -> op === (+), options.operators.binops))
    mult_idx = something(findfirst(op -> op === (*), options.operators.binops))

    R = typeof(float(real(zero(T))))
    tol = eps(R)

    active_indices = findall(abs.(coefficients) .> tol * 100)

    isempty(active_indices) && return nothing

    active_trees = trees[active_indices]
    active_coeffs = coefficients[active_indices]

    if length(active_indices) == 1
        tree = active_trees[1]
        coeff = active_coeffs[1]

        if abs(coeff - one(T)) < tol * 100
            return tree
        end

        coeff_node = constructorof(typeof(tree))(; val=coeff)
        return constructorof(typeof(tree))(; op=mult_idx, children=(coeff_node, tree))
    end

    weighted_trees = sizehint!(Vector{N}(), length(active_trees))
    for (tree, coeff) in zip(active_trees, active_coeffs)
        if abs(coeff - one(T)) < tol * 100
            push!(weighted_trees, tree)
        else
            coeff_node = constructorof(typeof(tree))(; val=coeff)
            weighted = constructorof(typeof(tree))(;
                op=mult_idx, children=(coeff_node, tree)
            )
            push!(weighted_trees, weighted)
        end
    end

    result = weighted_trees[1]
    for i in 2:length(weighted_trees)
        result = constructorof(typeof(result))(;
            op=add_idx, children=(result, weighted_trees[i])
        )
    end

    return result
end

"""
    BacksolveSetup(basis, gram, term_costs, join_cost, addend_overhead)

Precomputed basis library, its Gram matrix `theta' * theta`, and the
complexity costs of each term as a weighted-sum addend, so a caller
performing several fits against the same population (e.g. one backsolve
mutation event trying several nodes) only pays the library and Gram cost
once. Construct with [`prepare_backsolve_setup`](@ref).
"""
struct BacksolveSetup{T,N<:AbstractExpressionNode{T}}
    basis::BasisLibrary{T,N}
    gram::Matrix{T}
    term_costs::Vector{Int}
    join_cost::Int
    addend_overhead::Int
end

"""
    prepare_backsolve_setup(tree_prototype, dataset, options, nfeatures, population; max_library_size=200, top_k=10) -> BacksolveSetup

Build the basis library for a backsolve fit and precompute its Gram matrix
and per-term complexity costs.

!!! warning
    This API supports an experimental mutation and will change in minor
    version increments.
"""
function prepare_backsolve_setup(
    tree_prototype::AbstractExpressionNode{T},
    dataset::Dataset{T},
    options::AbstractOptions,
    nfeatures::Int,
    population;
    max_library_size::Int=200,
    top_k::Int=10,
) where {T<:DATA_TYPE}
    basis = build_basis_library(
        tree_prototype,
        dataset,
        options,
        nfeatures,
        population;
        max_library_size=max_library_size,
        top_k=top_k,
    )
    theta = basis.evaluated_terms
    term_costs, join_cost, addend_overhead = weighted_sum_costs(
        basis.terms, tree_prototype, options
    )
    return BacksolveSetup(basis, theta' * theta, term_costs, join_cost, addend_overhead)
end

"""
    fit_sparse_expression(
        tree_prototype::AbstractExpressionNode{T},
        target_values::AbstractVector{T},
        dataset::Dataset{T},
        options::AbstractOptions,
        nfeatures::Int;
        valid_mask=nothing,
        setup=nothing,
        extra_term=nothing,
        max_complexity=nothing,
        population_for_backsolve=nothing
    ) -> Union{AbstractExpressionNode{T}, Nothing}

Fit a sparse expression to backsolved target values by greedy forward
selection (orthogonal matching pursuit) over the basis library.

!!! warning
    This API supports an experimental mutation and will change in minor
    version increments.

Returns `nothing` immediately if `+` and `*` are not both present in the
operator set, since the output is structurally a weighted sum.

# Arguments
- `tree_prototype`: Prototype node for creating trees
- `target_values`: Target values to fit
- `dataset`: Dataset containing input features
- `options`: Options containing operator definitions and backsolve configuration
- `nfeatures`: Number of input features
- `valid_mask`: Optional per-row validity mask (e.g. from
  `eval_inverse_tree_array_masked`). When `extra_term` is given, invalid rows
  have their target replaced by the extra term's values, so the fit is asked
  to preserve the current behaviour on rows where the inversion gave no
  information (the extra term, being part of the library, can absorb this
  exactly). Otherwise invalid rows are dropped from the fit.
- `setup`: Optional precomputed `BacksolveSetup`, sharing the evaluated
  library, its Gram matrix, and per-term complexity costs across several fits.
- `extra_term`: Optional additional library term (typically the subtree
  being replaced), letting the fit retain the existing structure when it is
  already useful.
- `max_complexity`: Optional complexity budget for the returned tree,
  enforced during selection. Returns `nothing` if no non-empty fit respects
  the budget.
- `population_for_backsolve`: Optional population used to extract basis
  terms for the backsolve mutation.

# Returns
- Fitted expression tree, or `nothing` if fitting fails
"""
@unstable function fit_sparse_expression(
    tree_prototype::AbstractExpressionNode{T},
    target_values::AbstractVector{T},
    dataset::Dataset{T},
    options::AbstractOptions,
    nfeatures::Int;
    backsolve_options::BacksolveMutation=configured_backsolve(options),
    population_for_backsolve=nothing,
    valid_mask::Union{Nothing,BitVector}=nothing,
    setup::Union{Nothing,BacksolveSetup}=nothing,
    extra_term::Union{Nothing,AbstractExpressionNode{T}}=nothing,
    max_complexity::Union{Nothing,Int}=nothing,
) where {T<:STLSQ_DATA_TYPE}
    _has_weighted_sum_operators(options) || return nothing

    n_rows = length(target_values)
    if valid_mask !== nothing && count(valid_mask) < min(10, n_rows)
        return nothing
    end

    basis_library = if setup === nothing
        build_basis_library(
            tree_prototype,
            dataset,
            options,
            nfeatures,
            population_for_backsolve;
            max_library_size=backsolve_options.max_library_size,
        )
    else
        setup.basis
    end
    terms = basis_library.terms
    theta = basis_library.evaluated_terms

    extra_values = nothing
    if extra_term !== nothing
        vals, eval_success = eval_tree_array(extra_term, dataset.X, options.operators)
        if !eval_success || any(isnan, vals) || any(isinf, vals)
            return nothing
        end
        extra_values = vals
    end

    drop_rows = valid_mask !== nothing && extra_values === nothing
    target_fit = target_values
    if valid_mask !== nothing && !drop_rows && !all(valid_mask)
        target_fit = copy(target_values)
        target_fit[.!valid_mask] .= (extra_values::AbstractVector{T})[.!valid_mask]
    end

    local G::Matrix{T}
    local g::Vector{T}
    local yy::Float64
    if drop_rows
        mask = valid_mask::BitVector
        theta_masked = if extra_values === nothing
            theta[mask, :]
        else
            hcat(theta, extra_values::AbstractVector{T})[mask, :]
        end
        target_masked = target_values[mask]
        G = theta_masked' * theta_masked
        g = theta_masked' * target_masked
        yy = sum(abs2, target_masked)
    else
        yy = sum(abs2, target_fit)
        g_full = theta' * target_fit
        if extra_values === nothing
            G = setup === nothing ? theta' * theta : setup.gram
            g = g_full
        else
            extra = extra_values::AbstractVector{T}
            p = length(terms)
            base_gram = setup === nothing ? theta' * theta : setup.gram
            G = Matrix{T}(undef, p + 1, p + 1)
            G[1:p, 1:p] = base_gram
            G[1:p, p + 1] = theta' * extra
            G[p + 1, 1:p] = conj.(G[1:p, p + 1])
            G[p + 1, p + 1] = sum(abs2, extra)
            g = Vector{T}(undef, p + 1)
            g[1:p] = g_full
            g[p + 1] = dot(extra, target_fit)
        end
    end

    terms_fit = extra_term === nothing ? terms : [terms; extra_term]

    term_costs, join_cost = if setup === nothing
        costs = weighted_sum_costs(terms_fit, tree_prototype, options)
        (costs[1], costs[2])
    else
        if extra_term === nothing
            (setup.term_costs, setup.join_cost)
        else
            extra_cost = compute_complexity(extra_term, options) + setup.addend_overhead
            ([setup.term_costs; extra_cost], setup.join_cost)
        end
    end

    coefficients, fit_success = greedy_forward_selection_gram(
        G,
        g,
        yy;
        term_costs,
        join_cost,
        budget=max_complexity,
        max_terms=backsolve_options.max_terms,
        min_improvement=backsolve_options.min_improvement,
    )

    if !fit_success
        return nothing
    end

    result_tree = combine_trees_weighted_sum(terms_fit, coefficients, options)
    result_tree === nothing && return nothing

    if max_complexity !== nothing &&
        compute_complexity(result_tree, options) > max_complexity
        return nothing
    end

    predicted, eval_success = eval_tree_array(result_tree, dataset.X, options.operators)

    if !eval_success || any(isnan, predicted) || any(isinf, predicted)
        return nothing
    end

    return result_tree
end

end
