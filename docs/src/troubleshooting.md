# FAQ

This FAQ addresses the most commonly asked questions based on actual user discussions and issues.

## CPU cores aren't being fully utilized

This is the most common performance question. Check the head worker occupation percentage in the output:

```julia
# If head worker occupation > 50%, increase work per iteration:
options = Options(
    ncycles_per_iteration=1000,    # More cycles per iteration
    populations=20                 # More populations for more cores
)

# For distributed processing (parallelism goes in equation_search):
hall_of_fame = equation_search(X, y;
    options=options,
    parallelism=:multiprocessing,  # Use multiple processes
    procs=8                       # Number of processes
)
```

## My expressions use only 1-2 variables instead of all inputs

This is frequently asked and reflects how the algorithm naturally performs feature selection:

**Why this happens:** The algorithm finds the simplest expression that fits the data. If your target can be predicted well using only a subset of features, that's often the correct mathematical relationship.

**What to do:**

1. **Check if the unused variables actually matter** by computing correlations:

```julia
using Statistics
correlations = [cor(X[:, i], y) for i in 1:size(X, 2)]
```

2. **If you need all variables included**, use a custom loss function:

```julia
function feature_penalty_loss(tree, dataset, options)
    prediction, complete = eval_tree_array(tree, dataset.X, options)
    !complete && return Inf

    # Count which features are actually used in the expression
    features_used = Set{Int}()
    for node in tree
        if node.degree == 0 && !node.constant
            push!(features_used, node.feature)
        end
    end

    # Get total number of features in dataset
    total_features = size(dataset.X, 1)
    unused_features = total_features - length(features_used)

    # Add penalty for unused features
    feature_penalty = unused_features * 100.0  # Adjust penalty weight as needed

    base_loss = sum(abs2, prediction .- dataset.y) / length(dataset.y)
    return base_loss + feature_penalty
end

options = Options(loss_function=feature_penalty_loss)
```

## I'm getting tiny constants like 1e-16 in my expressions

This is a very common issue caused by numerical optimization:

**Cause:** The constant optimizer finds numerically tiny values that should be zero.

**Solution:** Use size constraints to limit expression complexity:

```julia
options = Options(
    constraints=[
        (*) => (-1, 5),    # Multiplication: unlimited left, max size 5 right
        (+) => (10, 10),   # Addition: max size 10 both sides
        (^) => (-1, 3)     # Power: unlimited base, max size 3 exponent
    ]
)
```

**Alternative:** Post-process expressions by setting tiny constants to zero:

```julia
# Post-process by creating expressions with smaller subtrees
# (SymbolicRegression.jl doesn't directly control constant ranges)
options = Options(
    constraints=[
        (*) => (5, 5),     # Limit multiplication argument sizes
        (+) => (8, 8),     # Limit addition argument sizes
        (/) => (3, 3)      # Limit division argument sizes
    ],
    parsimony=0.1  # Higher parsimony discourages complex constants
)
```

## How do I enforce physical constraints (positivity, monotonicity, etc.)?

This is the most frequently asked advanced question. Use custom loss functions:

**Example: Enforce positivity**

```julia
function positive_constraint_loss(tree, dataset, options)
    prediction, complete = eval_tree_array(tree, dataset.X, options)
    !complete && return Inf

    # Heavy penalty for negative predictions
    if any(prediction .< 0)
        return 1e6
    end

    return sum(abs2, prediction .- dataset.y) / length(dataset.y)
end

options = Options(loss_function=positive_constraint_loss)
```

**Example: Enforce monotonicity**

```julia
function monotonic_loss(tree, dataset, options)
    prediction, complete = eval_tree_array(tree, dataset.X, options)
    !complete && return Inf

    # Check if predictions are monotonic in first variable
    sorted_indices = sortperm(dataset.X[1, :])
    sorted_predictions = prediction[sorted_indices]

    # Penalty for non-monotonic behavior
    violations = sum(diff(sorted_predictions) .< 0)
    monotonic_penalty = violations * 100.0

    base_loss = sum(abs2, prediction .- dataset.y) / length(dataset.y)
    return base_loss + monotonic_penalty
end
```

## How do I use external Julia packages for custom operators?

Common need for domain-specific functions:

```julia
using SpecialFunctions

# Define safe operators that handle domain errors
safe_gamma(x) = x > 0 ? gamma(x) : NaN
safe_bessel(n, x) = abs(x) < 100 ? besselj(n, x) : NaN

options = Options(
    unary_operators=[safe_gamma],
    binary_operators=[+, -, *, /, safe_bessel],
    # Prevent problematic nesting
    nested_constraints=[
        safe_gamma => [safe_gamma => 0],   # No gamma(gamma(x))
        safe_bessel => [safe_bessel => 0]  # No bessel(bessel(x))
    ]
)
```

## My search seems slow or finds poor results

Common performance issues:

**Most common cause:** Missing the `+` operator

```julia
# Wrong - can't build additive expressions
options = Options(binary_operators=[*, /])

# Correct - include + for building complex expressions
options = Options(binary_operators=[+, -, *, /])
```

**Other fixes:**

```julia
options = Options(
    populations=30,              # More populations for exploration
    population_size=50,          # Larger populations
    ncycles_per_iteration=500,   # More evolution per iteration
    adaptive_parsimony_scaling=1000.0  # Reduce complexity pressure
)
```

## I need to preprocess my data - what's recommended?

Based on successful user workflows:

**Feature scaling:**

```julia
using Statistics
# Standardize features to have mean 0, std 1
X_scaled = (X .- mean(X, dims=2)) ./ std(X, dims=2)
```

**Handle outliers:**

```julia
# Remove extreme outliers (beyond 3 standard deviations)
outliers = abs.(y .- mean(y)) .> 3 * std(y)
X_clean = X[:, .!outliers]
y_clean = y[.!outliers]
```

**For noisy data, use robust loss:**

```julia
function huber_loss(tree, dataset, options)
    prediction, complete = eval_tree_array(tree, dataset.X, options)
    !complete && return Inf

    residuals = prediction .- dataset.y
    delta = 1.0

    huber_values = map(residuals) do r
        abs(r) <= delta ? 0.5 * r^2 : delta * (abs(r) - 0.5 * delta)
    end

    return sum(huber_values) / length(huber_values)
end
```

## How do I interpret the results and select the best model?

**Understanding the output:**

```julia
# Get Hall of Fame (Pareto frontier)
hall_of_fame = equation_search(X, y; options=options)

# Each complexity level has the best expression found
for i in 1:length(hall_of_fame.members)
    if hall_of_fame.exists[i]
        member = hall_of_fame.members[i]
        expr_string = string_tree(member.tree, options)
        println("Complexity $(i): Loss $(member.loss), Expression: $(expr_string)")
    end
end
```

**Model selection:** The "best" model is subjective. Consider:

- **Cross-validation**: Test expressions on held-out data
- **Domain knowledge**: Choose expressions that make physical sense
- **Simplicity preference**: Often simpler expressions generalize better

```julia
# Example: Cross-validation for model selection
cv_errors = Float64[]
for i in 1:length(hall_of_fame.members)
    if hall_of_fame.exists[i]
        # Evaluate expression i on validation data
        expr = hall_of_fame.members[i].tree
        pred, complete = eval_tree_array(expr, X_val, options)
        if complete
            cv_error = sum(abs2, pred .- y_val) / length(y_val)
            push!(cv_errors, cv_error)
        else
            push!(cv_errors, Inf)  # Invalid expression
        end
    else
        push!(cv_errors, Inf)
    end
end
best_by_cv = argmin(cv_errors)
```

## When should I use template expressions vs standard search?

Template expressions are for structured problems:

**Use templates when:**

- You know the general form (e.g., `y = a*f(x) + b*g(x)`)
- You have theoretical constraints on the structure
- Standard search finds overly complex expressions

**Use standard search when:**

- You don't know the functional form
- You want the algorithm to discover the structure
- You have sufficient computational budget

## How do I resume a search or use warm starts?

Continue previous searches:

```julia
# Save intermediate results
hall_of_fame = equation_search(X, y; options=options)
using Serialization
serialize("results.jls", hall_of_fame)

# Resume with modified parameters
loaded_hof = deserialize("results.jls")
options_continue = Options(
    parsimony=0.01,  # Different parsimony for fine-tuning
    niterations=100
)
# Note: Check documentation for correct warm start syntax
final_results = equation_search(X, y;
    options=options_continue
    # saved_state=loaded_hof  # Verify correct parameter name
)
```
