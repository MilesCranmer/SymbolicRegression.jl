# Customization

Many parts of SymbolicRegression.jl are designed to be customizable.

The normal way to do this in Julia is to define a new type that subtypes
an abstract type from a package, and then define new methods for the type,
extending internal methods on that type.

## Custom Options

For example, you can define a custom options type:

```@docs
AbstractOptions
```

Any function in SymbolicRegression.jl you can generally define a new method
on your custom options type, to define custom behavior.

## Custom Mutations

You can define custom mutation operators by defining a new method on
`mutate!`, as well as subtyping `AbstractMutationWeights`:

```@docs
mutate!
AbstractMutationWeights
condition_mutation_weights!
sample_mutation
MutationResult
```

## Custom Expressions

You can create your own expression types by defining a new type that extends `AbstractExpression`.

```@docs
AbstractExpression
```

The interface is fairly flexible, and permits you define specific functional forms,
extra parameters, etc. See the documentation of DynamicExpressions.jl for more details on what
methods you need to implement. You can test the implementation of a given interface by using
`ExpressionInterface` which makes use of `Interfaces.jl`:

```@docs
ExpressionInterface
```

Then, for SymbolicRegression.jl, you would
pass `expression_type` to the `Options` constructor, as well as any
`expression_options` you need (as a `NamedTuple`).

If needed, you may need to overload `SymbolicRegression.ExpressionBuilder.extra_init_params` in
case your expression needs additional parameters. See the method for `ParametricExpression`
as an example.

You can look at the files `src/ParametricExpression.jl` and `src/TemplateExpression.jl`
for more examples of custom expression types, though note that `ParametricExpression` itself
is defined in DynamicExpressions.jl, while that file just overloads some methods for
SymbolicRegression.jl.

## Other Customizations

Other internal abstract types include the following:

```@docs
AbstractRuntimeOptions
AbstractSearchState
```

These let you include custom state variables and runtime options.

## Advanced Customization Patterns

The following sections provide comprehensive guidance on advanced customization patterns that extend beyond basic API usage. These patterns are particularly valuable for researchers and contributors implementing domain-specific extensions.

### Advanced Custom Operator Development

While basic operator definition is straightforward, creating robust, high-performance custom operators requires careful consideration of several aspects:

#### Domain-Specific Operator Libraries

Physics and engineering applications often benefit from specialized operator libraries. Here's a comprehensive example for thermodynamics:

```julia
# Thermodynamic operators with proper error handling
module ThermodynamicOperators

using SymbolicRegression
using DynamicExpressions: OperatorEnum

# Clausius-Clapeyron relation operators
function clausius_clapeyron(T::T1, P::T2)::promote_type(T1, T2) where {T1<:Real, T2<:Real}
    R = 8.314  # Gas constant
    T > zero(T) || return promote_type(T1, T2)(NaN)
    P > zero(P) || return promote_type(T1, T2)(NaN)
    return log(P) / T
end

# Arrhenius temperature dependence
function arrhenius(T::T1, Ea_over_R::T2)::promote_type(T1, T2) where {T1<:Real, T2<:Real}
    T > zero(T) || return promote_type(T1, T2)(NaN)
    return exp(-Ea_over_R / T)
end

# van der Waals equation terms
function vdw_attraction(V::T1, a::T2)::promote_type(T1, T2) where {T1<:Real, T2<:Real}
    V > zero(V) || return promote_type(T1, T2)(NaN)
    return a / (V * V)
end

function vdw_repulsion(V::T1, b::T2)::promote_type(T1, T2) where {T1<:Real, T2<:Real}
    V > b || return promote_type(T1, T2)(NaN)
    return V - b
end

# Export operators for use
const THERMO_BINARY_OPS = [clausius_clapeyron, vdw_attraction, vdw_repulsion]
const THERMO_UNARY_OPS = [arrhenius]

end
```

#### Performance Optimization Patterns

For computationally intensive operators, consider these optimization strategies:

```julia
# SIMD-friendly operator implementation
using SIMD

function fast_sigmoid(x::T)::T where {T<:AbstractFloat}
    # Clamp input to prevent overflow
    x_clamped = clamp(x, T(-500), T(500))
    return one(T) / (one(T) + exp(-x_clamped))
end

# Vectorized version for SIMD
function fast_sigmoid(x::Vec{N, T})::Vec{N, T} where {N, T<:AbstractFloat}
    # SIMD-optimized sigmoid
    x_clamped = max(min(x, Vec{N, T}(500)), Vec{N, T}(-500))
    return Vec{N, T}(1) / (Vec{N, T}(1) + exp(-x_clamped))
end

# Custom operator with gradient support for automatic differentiation
using ForwardDiff

function smooth_relu(x::T)::T where {T<:Real}
    return log(one(T) + exp(x))
end

# Ensure ForwardDiff compatibility
function smooth_relu(x::ForwardDiff.Dual{T})::ForwardDiff.Dual{T} where {T}
    return log(one(x) + exp(x))
end
```

#### Symbolic Compatibility and Export

Ensuring your custom operators work with symbolic mathematics packages:

```julia
# Register operators for symbolic export
import SymbolicUtils
import SymbolicRegression.InterfaceDynamicExpressionsModule: node_to_symbolic

# Define symbolic representation
function node_to_symbolic(
    tree::Node{T},
    operators::OperatorEnum,
    variable_names::Vector{String};
    evaluate_constants=false,
    expression_type::Type{E}=Expression,
    extra_symbols=Dict{Symbol, Any}()
) where {T, E}
    # Custom symbolic mappings
    if tree.op == findfirst(==(clausius_clapeyron), operators.ops[2])
        lhs = node_to_symbolic(tree.l, operators, variable_names; kwargs...)
        rhs = node_to_symbolic(tree.r, operators, variable_names; kwargs...)
        return SymbolicUtils.Term(clausius_clapeyron, [lhs, rhs])
    end
    # Fall back to default behavior
    return node_to_symbolic_default(tree, operators, variable_names; kwargs...)
end

# LaTeX export support
function latex_op_string(::typeof(clausius_clapeyron))
    return "\\text{CC}"
end
```

### Advanced Mutation Customization Patterns

#### Constraint-Aware Mutation Design

Implementing mutations that respect domain constraints:

```julia
using SymbolicRegression: AbstractMutationWeights, mutate!

struct PhysicsAwareMutationWeights <: AbstractMutationWeights
    # Standard mutations
    mutate_constant::Float64
    mutate_operator::Float64
    swap_operands::Float64

    # Physics-specific mutations
    dimensionally_consistent_substitution::Float64
    conservation_preserving_transform::Float64
    symmetry_preserving_mutation::Float64

    function PhysicsAwareMutationWeights(;
        mutate_constant=0.2,
        mutate_operator=0.3,
        swap_operands=0.1,
        dimensionally_consistent_substitution=0.2,
        conservation_preserving_transform=0.1,
        symmetry_preserving_mutation=0.1
    )
        new(mutate_constant, mutate_operator, swap_operands,
            dimensionally_consistent_substitution,
            conservation_preserving_transform,
            symmetry_preserving_mutation)
    end
end

# Custom mutation sampling
const PHYSICS_MUTATIONS = [
    :mutate_constant, :mutate_operator, :swap_operands,
    :dimensionally_consistent_substitution,
    :conservation_preserving_transform,
    :symmetry_preserving_mutation
]

import SymbolicRegression: sample_mutation
using StatsBase

function sample_mutation(w::PhysicsAwareMutationWeights)
    weights = [w.mutate_constant, w.mutate_operator, w.swap_operands,
               w.dimensionally_consistent_substitution,
               w.conservation_preserving_transform,
               w.symmetry_preserving_mutation]
    weights = weights ./ sum(weights)
    return StatsBase.sample(PHYSICS_MUTATIONS, StatsBase.Weights(weights))
end

# Implement custom mutation operations
function mutate!(
    ex::AbstractExpression,
    options::AbstractOptions,
    ::Val{:dimensionally_consistent_substitution};
    rng=Random.default_rng()
)
    # Implementation that maintains dimensional consistency
    # This would check units and only substitute dimensionally equivalent expressions
    tree = get_contents(ex)

    # Find substitution candidates that preserve units
    candidates = find_dimensionally_equivalent_subtrees(tree, options)

    if !isempty(candidates)
        target, replacement = rand(rng, candidates)
        tree = substitute_node(tree, target, replacement)
        return MutationResult(with_contents(ex, tree), true)
    end

    return MutationResult(ex, false)
end
```

#### Weight Conditioning Strategies

Advanced dynamic weight adjustment based on search progress:

```julia
using SymbolicRegression: condition_mutation_weights!, PopMember

function condition_mutation_weights!(
    ::Type{<:Expression},
    weights::PhysicsAwareMutationWeights,
    member::PopMember,
    options::AbstractOptions,
    curmaxsize::Int
)
    # Adjust weights based on expression complexity and loss
    complexity = compute_complexity(member.tree, options)
    loss = member.loss

    # Increase structure-preserving mutations for complex expressions
    complexity_factor = complexity / curmaxsize
    weights.conservation_preserving_transform *= (1.0 + complexity_factor)

    # Increase exploratory mutations for high-loss expressions
    if loss > 1.0
        weights.dimensionally_consistent_substitution *= 1.5
    end

    # Reduce constant mutations for converged expressions
    if loss < 0.01
        weights.mutate_constant *= 0.5
    end
end
```

### Advanced Loss Function Patterns

#### Physics-Informed Loss Functions

Incorporating physical principles directly into the loss:

```julia
using DynamicQuantities
using SymbolicRegression.DimensionalAnalysisModule: violates_dimensional_constraints

function physics_informed_loss(
    tree::AbstractExpression,
    dataset::Dataset{T,L},
    options::AbstractOptions
) where {T,L}

    # Standard prediction loss
    prediction, complete = eval_tree_array(tree, dataset.X, options)
    !complete && return L(Inf)

    base_loss = sum(abs2, prediction .- dataset.y) / length(dataset.y)

    # Physics constraints
    physics_penalty = zero(L)

    # 1. Dimensional consistency penalty
    if options.dimensional_constraint_penalty !== nothing
        if violates_dimensional_constraints(tree, dataset, options)
            physics_penalty += convert(L, options.dimensional_constraint_penalty)
        end
    end

    # 2. Conservation law penalties
    # Example: Energy conservation check
    if haskey(dataset.extra, :energy_initial) && haskey(dataset.extra, :energy_final)
        energy_conservation_violation = abs(
            sum(dataset.extra.energy_final .- dataset.extra.energy_initial)
        )
        physics_penalty += convert(L, 100.0 * energy_conservation_violation)
    end

    # 3. Symmetry penalties
    # Example: Check rotational symmetry for physics problems
    if haskey(dataset.extra, :rotation_test_data)
        rotation_data = dataset.extra.rotation_test_data
        original_pred, _ = eval_tree_array(tree, rotation_data.X_original, options)
        rotated_pred, _ = eval_tree_array(tree, rotation_data.X_rotated, options)

        # Apply inverse rotation to rotated prediction and compare
        symmetry_violation = norm(original_pred .- inverse_rotate(rotated_pred, rotation_data.angle))
        physics_penalty += convert(L, 10.0 * symmetry_violation)
    end

    return base_loss + physics_penalty
end
```

#### Multi-Objective Loss Design

Balancing multiple objectives with Pareto-efficient approaches:

```julia
struct MultiObjectiveLoss{F1,F2,F3}
    accuracy_loss::F1
    complexity_loss::F2
    interpretability_loss::F3
    weights::NamedTuple{(:accuracy, :complexity, :interpretability), Tuple{Float64,Float64,Float64}}
end

function (mol::MultiObjectiveLoss)(tree, dataset, options)
    acc_loss = mol.accuracy_loss(tree, dataset, options)
    comp_loss = mol.complexity_loss(tree, dataset, options)
    interp_loss = mol.interpretability_loss(tree, dataset, options)

    # Weighted combination
    return (mol.weights.accuracy * acc_loss +
            mol.weights.complexity * comp_loss +
            mol.weights.interpretability * interp_loss)
end

# Example complexity loss based on operator difficulty
function operator_complexity_loss(tree::AbstractExpression, dataset::Dataset, options::AbstractOptions)
    complexity_map = Dict(
        :+ => 1.0,
        :* => 1.5,
        :sin => 3.0,
        :exp => 5.0,
        :log => 4.0
    )

    total_complexity = count_operators(tree, complexity_map)
    return convert(typeof(dataset.y[1]), 0.01 * total_complexity)
end
```

#### Robust Loss Functions for Noisy Data

Implementing loss functions that handle outliers and noise:

```julia
using Distributions

function robust_huber_loss(
    tree::AbstractExpression,
    dataset::Dataset{T,L},
    options::AbstractOptions;
    delta::Float64 = 1.0
) where {T,L}

    prediction, complete = eval_tree_array(tree, dataset.X, options)
    !complete && return L(Inf)

    residuals = prediction .- dataset.y

    # Huber loss: quadratic for small residuals, linear for large ones
    huber_loss = sum(residuals) do r
        abs_r = abs(r)
        if abs_r <= delta
            0.5 * r^2
        else
            delta * (abs_r - 0.5 * delta)
        end
    end

    return convert(L, huber_loss / length(residuals))
end

# Adaptive loss that estimates noise level
function adaptive_robust_loss(
    tree::AbstractExpression,
    dataset::Dataset{T,L},
    options::AbstractOptions
) where {T,L}

    prediction, complete = eval_tree_array(tree, dataset.X, options)
    !complete && return L(Inf)

    residuals = prediction .- dataset.y

    # Estimate noise level using median absolute deviation
    mad_estimate = median(abs.(residuals .- median(residuals))) * 1.4826

    # Use Student-t loss for heavy-tailed noise
    t_loss = sum(residuals) do r
        log(1 + (r / mad_estimate)^2)
    end

    return convert(L, t_loss / length(residuals))
end
```

### Advanced Expression Type Customization

#### Custom Complexity Metrics

Beyond node counting, implementing domain-aware complexity measures:

```julia
import SymbolicRegression.ComplexityModule: compute_complexity

function compute_complexity(
    ex::MyCustomExpression,
    options::AbstractOptions
)
    tree = get_tree(ex)

    # Base structural complexity
    base_complexity = count_nodes(tree)

    # Operator-specific complexity weights
    operator_weights = Dict(
        :+ => 1.0,
        :* => 1.2,
        :/ => 2.0,
        :sin => 3.0,
        :exp => 4.0,
        :log => 3.5
    )

    # Depth penalty for deeply nested expressions
    depth_penalty = 0.5 * count_depth(tree)

    # Parameter count for parametric expressions
    param_penalty = if hasfield(typeof(ex), :parameters)
        0.1 * length(ex.parameters)
    else
        0.0
    end

    return Int(ceil(base_complexity + depth_penalty + param_penalty))
end

# Custom complexity for template expressions
function compute_complexity(
    ex::TemplateExpression,
    options::AbstractOptions
)
    # Sum complexity of all sub-expressions
    total_complexity = 0
    for (key, subexpr) in pairs(ex.trees)
        total_complexity += compute_complexity(subexpr, options)
    end

    # Add template structure overhead
    structure_complexity = length(ex.trees) * 2

    return Int(total_complexity + structure_complexity)
end
```

#### Expression-Specific Evaluation Optimizations

```julia
# Custom evaluation with memoization for expensive operations
struct MemoizedExpression{T,N<:AbstractExpressionNode{T}} <: AbstractExpression{T}
    tree::N
    memo_cache::Dict{Vector{T}, Vector{T}}
    cache_hits::Ref{Int}

    function MemoizedExpression(tree::N) where {T,N<:AbstractExpressionNode{T}}
        new{T,N}(tree, Dict{Vector{T}, Vector{T}}(), Ref(0))
    end
end

function DynamicExpressions.eval_tree_array(
    ex::MemoizedExpression,
    X::AbstractMatrix,
    options::AbstractOptions
)
    # Create cache key (simplified - in practice, use hash)
    cache_key = vec(X)

    if haskey(ex.memo_cache, cache_key)
        ex.cache_hits[] += 1
        return ex.memo_cache[cache_key], true
    end

    # Evaluate normally and cache result
    result, complete = eval_tree_array(ex.tree, X, options)

    if complete && !isnothing(result)
        ex.memo_cache[cache_key] = result
    end

    return result, complete
end
```

### Advanced Search Customization

#### Custom Search State Management

Implementing problem-specific search state that tracks additional information:

```julia
using SymbolicRegression: AbstractSearchState

struct PhysicsSearchState <: AbstractSearchState
    # Standard state
    iteration::Int
    best_loss::Float64

    # Physics-specific tracking
    dimensional_violations::Int
    conservation_violations::Int
    symmetry_violations::Int
    discovered_laws::Vector{String}

    function PhysicsSearchState()
        new(0, Inf, 0, 0, 0, String[])
    end
end

# Update search state with domain-specific information
function update_search_state!(
    state::PhysicsSearchState,
    hall_of_fame,
    dataset,
    options
)
    state.iteration += 1

    # Update best loss
    if !isempty(hall_of_fame.members)
        current_best = minimum(member.loss for member in hall_of_fame.members if member.loss < Inf)
        state.best_loss = min(state.best_loss, current_best)
    end

    # Check for physics violations in population
    for member in hall_of_fame.members
        if member.loss < Inf
            if violates_dimensional_constraints(member.tree, dataset, options)
                state.dimensional_violations += 1
            end
            # Additional violation checks...
        end
    end

    # Detect discovered physical laws
    check_for_known_laws!(state, hall_of_fame)
end

function check_for_known_laws!(state::PhysicsSearchState, hall_of_fame)
    for member in hall_of_fame.members
        if member.loss < 0.01  # Well-fit expressions
            expr_string = string(member.tree)

            # Pattern matching for known laws
            if contains(expr_string, r"x1\s*\*\s*x2") && !("Newton's 2nd Law" in state.discovered_laws)
                push!(state.discovered_laws, "Newton's 2nd Law")
            elseif contains(expr_string, r"x1\s*/\s*x2\^2") && !("Inverse Square Law" in state.discovered_laws)
                push!(state.discovered_laws, "Inverse Square Law")
            end
        end
    end
end
```

#### Runtime Option Modifications

Dynamically adjusting search parameters based on progress:

```julia
using SymbolicRegression: AbstractRuntimeOptions

struct AdaptiveRuntimeOptions <: AbstractRuntimeOptions
    base_options::Options
    adaptation_schedule::Dict{Int, NamedTuple}

    function AdaptiveRuntimeOptions(base_options, schedule)
        new(base_options, schedule)
    end
end

function adapt_options!(
    runtime_options::AdaptiveRuntimeOptions,
    iteration::Int,
    search_state,
    hall_of_fame
)
    # Check if adaptation is scheduled for this iteration
    if haskey(runtime_options.adaptation_schedule, iteration)
        adaptations = runtime_options.adaptation_schedule[iteration]

        # Apply scheduled adaptations
        for (param, value) in pairs(adaptations)
            setfield!(runtime_options.base_options, param, value)
        end
    end

    # Dynamic adaptations based on search progress
    if search_state.iteration > 100
        # Reduce mutation rates for fine-tuning
        runtime_options.base_options.mutation_weights.mutate_constant *= 0.95
        runtime_options.base_options.mutation_weights.add_node *= 0.9
    end

    # Increase complexity limit if good solutions are found
    if !isempty(hall_of_fame.members) && minimum(m.loss for m in hall_of_fame.members) < 0.1
        runtime_options.base_options.maxsize = min(
            runtime_options.base_options.maxsize + 1,
            50  # Maximum allowed complexity
        )
    end
end
```

### Operator Fusion and Compilation Strategies

#### JIT Compilation for Custom Operators

Leveraging Julia's compilation system for optimal performance:

```julia
using RuntimeGeneratedFunctions

# Generate specialized evaluation functions at runtime
function generate_fused_evaluator(operators::Vector{Function}, pattern::Symbol)
    if pattern == :linear_combination
        # Generate code for linear combinations
        code = quote
            function fused_linear_eval(coeffs, inputs)
                result = 0.0
                for (i, (coeff, input)) in enumerate(zip(coeffs, inputs))
                    result += coeff * operators[1](input)  # Assuming first op is identity
                end
                return result
            end
        end
    elseif pattern == :nested_trig
        # Generate code for nested trigonometric operations
        code = quote
            function fused_trig_eval(x)
                sin_x = operators[1](x)  # sin
                cos_sin_x = operators[2](sin_x)  # cos
                return operators[3](cos_sin_x)  # another operation
            end
        end
    end

    return RuntimeGeneratedFunction(code)
end

# Usage in custom expression evaluation
struct FusedExpression{T,F} <: AbstractExpression{T}
    base_tree::Node{T}
    fused_evaluator::F
    fusion_pattern::Symbol
end

function eval_tree_array(
    ex::FusedExpression,
    X::AbstractMatrix,
    options::AbstractOptions
)
    # Use fused evaluator for better performance
    if ex.fusion_pattern == :linear_combination
        return ex.fused_evaluator(extract_coefficients(ex.base_tree), X), true
    else
        # Fall back to standard evaluation
        return eval_tree_array(ex.base_tree, X, options)
    end
end
```

#### SIMD Integration Patterns

Optimizing custom operators for vectorized execution:

```julia
using SIMD

# SIMD-optimized custom operators
function simd_polynomial_eval(coeffs::NTuple{N,T}, x::Vec{M,T}) where {N,M,T}
    result = Vec{M,T}(coeffs[1])  # Constant term
    x_power = x

    for i in 2:N
        result += Vec{M,T}(coeffs[i]) * x_power
        x_power *= x
    end

    return result
end

# Integration with expression evaluation
struct SIMDExpression{T,N} <: AbstractExpression{T}
    polynomial_coeffs::NTuple{N,T}
    base_tree::Node{T}
end

function eval_tree_array(
    ex::SIMDExpression{T,N},
    X::AbstractMatrix{T},
    options::AbstractOptions
) where {T,N}

    # Process in SIMD-friendly chunks
    chunk_size = 8  # Adjust based on SIMD width
    n_samples = size(X, 2)
    result = Vector{T}(undef, n_samples)

    for i in 1:chunk_size:n_samples
        end_idx = min(i + chunk_size - 1, n_samples)
        chunk_X = view(X, :, i:end_idx)

        # Use SIMD evaluation for this chunk
        if size(chunk_X, 2) == chunk_size
            x_vec = Vec{chunk_size,T}(chunk_X[1, :])
            result_vec = simd_polynomial_eval(ex.polynomial_coeffs, x_vec)
            result[i:end_idx] = result_vec
        else
            # Handle remainder with standard evaluation
            result[i:end_idx] = eval_tree_array(ex.base_tree, chunk_X, options)[1]
        end
    end

    return result, true
end
```

### Testing Strategies for Custom Components

#### Comprehensive Test Patterns

```julia
using Test, SymbolicRegression

function test_custom_operator_suite(op::Function, op_name::String)
    @testset "Custom Operator: $op_name" begin

        # Basic functionality tests
        @testset "Basic Functionality" begin
            @test op(1.0, 2.0) isa Real
            @test !isnan(op(1.0, 2.0))
            @test !isinf(op(1.0, 2.0))
        end

        # Edge case tests
        @testset "Edge Cases" begin
            @test isnan(op(NaN, 1.0))
            @test isnan(op(1.0, NaN))
            # Add domain-specific edge cases
        end

        # Gradient compatibility
        @testset "Automatic Differentiation" begin
            using ForwardDiff
            @test ForwardDiff.derivative(x -> op(x, 2.0), 1.0) isa Real
            @test ForwardDiff.gradient(x -> op(x[1], x[2]), [1.0, 2.0]) isa Vector
        end

        # SIMD compatibility
        @testset "SIMD Compatibility" begin
            using SIMD
            x_simd = Vec{4,Float64}((1.0, 2.0, 3.0, 4.0))
            y_simd = Vec{4,Float64}((2.0, 3.0, 4.0, 5.0))
            result = op(x_simd, y_simd)
            @test result isa Vec{4,Float64}
            @test all(isfinite, result)
        end

        # Integration with SymbolicRegression
        @testset "SR Integration" begin
            options = Options(binary_operators=[op])
            @extend_operators options

            # Test expression construction
            x1 = Node(Float64; feature=1)
            x2 = Node(Float64; feature=2)
            tree = op(x1, x2)

            # Test evaluation
            X = rand(2, 10)
            result, complete = tree(X, options)
            @test complete
            @test length(result) == 10
            @test all(isfinite, result)
        end
    end
end

# Test custom expression types
function test_custom_expression_interface(ExprType::Type{<:AbstractExpression})
    @testset "Custom Expression Interface: $(ExprType)" begin

        # Test interface compliance
        @test ExprType <: AbstractExpression

        # Test required methods
        expr = create_test_expression(ExprType)
        @test hasmethod(get_tree, (ExprType,))
        @test hasmethod(get_metadata, (ExprType,))

        # Test evaluation
        X = rand(5, 20)
        options = Options()
        result, complete = eval_tree_array(expr, X, options)
        @test complete
        @test length(result) == 20
    end
end
```

These advanced customization patterns provide a foundation for implementing sophisticated domain-specific extensions to SymbolicRegression.jl. They demonstrate how the library's flexible architecture supports complex scientific computing applications while maintaining performance and correctness.
