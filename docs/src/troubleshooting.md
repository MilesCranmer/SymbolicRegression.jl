# Troubleshooting Guide

This guide addresses the most common issues users encounter when working with SymbolicRegression.jl, organized as frequently asked questions with practical solutions.

## Getting Started Issues

### Q: I'm getting Julia-related errors during installation or first run

**Common symptoms:**

- "tried to read a stream that is not readable"
- PyCall-related errors
- Julia version conflicts

**Solutions:**

1. **Check your Julia version**: Use Julia 1.6 or higher (1.9+ recommended)
2. **Remove old Julia versions**: Delete previous Julia installations that might conflict
3. **Verify environment**: If using Jupyter/IPython, restart your kernel after installation
4. **Fresh installation**: Try uninstalling and reinstalling both PySR and Julia
5. **System details matter**: The error can be OS-specific (Linux/Mac/Windows)

```julia
# Check your Julia version
julia --version
# Should show 1.6 or higher
```

### Q: How do I get started with a basic symbolic regression problem?

**Start simple:**

```julia
using SymbolicRegression

# Generate simple test data
X = randn(100, 2)
y = @. 2*X[:, 1] + X[:, 2]^2

# Basic search
model = SRRegressor(
    binary_operators=[+, -, *, /],
    unary_operators=[square, exp],
    niterations=10  # Start small for testing
)

mach = machine(model, X, y)
fit!(mach)
report(mach)
```

### Q: The search runs but I get no meaningful results

**Common causes and fixes:**

1. **Too few iterations**: Start with `niterations=30` for real problems
2. **Wrong operators**: Include operators relevant to your problem (`+` is almost always needed)
3. **Data preprocessing**: Check for NaN, infinite, or extremely large/small values
4. **Check data dimensions**: Ensure X and y have compatible shapes

## Performance and Search Issues

### Q: The search is very slow or gets stuck

**Performance optimization strategies:**

1. **Increase population and cycles:**

```julia
model = SRRegressor(
    populations=40,        # More populations (default: 15)
    population_size=50     # Larger populations (default: 33)
)
```

2. **Tune the search space:**

```julia
model = SRRegressor(
    maxsize=20,           # Allow more complex expressions
    maxdepth=8,           # Allow deeper nesting
    ncyclesperiteration=300  # More mutations per cycle
)
```

3. **Adaptive parsimony issues:**
   - If search gets stuck at one complexity level, the adaptive parsimony might be too aggressive
   - Try disabling it: `adaptive_parsimony_scaling=1000.0` (effectively disables)

### Q: The search keeps finding trivial solutions (constants or single variables)

**Solutions:**

1. **Increase complexity pressure:**

```julia
model = SRRegressor(
    constraints=Dict(
        :complexity => (min=3, max=30)  # Force minimum complexity
    )
)
```

2. **Better initialization:**
   - Include `+` and `*` operators for building complex expressions
   - Ensure your target variable actually depends on multiple inputs

3. **Check data quality:**
   - Verify your target variable isn't actually constant or linear
   - Scale your features if they have very different magnitudes

### Q: My CPU cores aren't being fully utilized

**Parallelization troubleshooting:**

1. **Check head worker occupation:** If this percentage is high (>80%), increase:

```julia
model = SRRegressor(
    ncyclesperiteration=1000,  # More work per iteration
    population_size=100        # Larger populations
)
```

2. **Try different parallelization:**

```julia
# Single-node multi-processing instead of multi-threading
model = SRRegressor(
    multithreading=false,
    procs=8
)
```

3. **Cluster-specific issues:**
   - PBS clusters: Use single-node processing due to ClusterManagers.jl limitations
   - SLURM clusters: Should work with multi-node processing

## Expression Quality Issues

### Q: I'm getting overly complex expressions that don't generalize

**Complexity control strategies:**

1. **Tighter complexity constraints:**

```julia
model = SRRegressor(
    maxsize=15,           # Smaller max size
    parsimony=0.01,       # Stronger parsimony pressure
    constraints=Dict(
        :max_complexity => 10
    )
)
```

2. **Operator-specific constraints:**

```julia
model = SRRegressor(
    nested_constraints=Dict(
        :sin => Dict(:sin => 0, :cos => 1),  # Prevent sin(sin(x))
        :exp => Dict(:exp => 0)              # Prevent exp(exp(x))
    )
)
```

### Q: I'm getting NaN or infinite values in my expressions

**Numerical stability fixes:**

1. **Constrain problematic operators:**

```julia
model = SRRegressor(
    constraints=Dict(
        :/ => (max_arg_size=5,),  # Limit denominator complexity
        :^ => (max_arg_size=3,)   # Limit exponent complexity
    )
)
```

2. **Custom safe operators:**

```julia
safe_log(x) = x > 0 ? log(x) : -10.0
safe_div(x, y) = abs(y) > 1e-6 ? x/y : sign(x) * 1e6

model = SRRegressor(
    unary_operators=[safe_log],
    binary_operators=[+, -, *, safe_div]
)
```

3. **Data preprocessing:**
   - Remove or clip extreme outliers
   - Scale features to reasonable ranges
   - Check for missing or invalid data

### Q: The discovered expressions don't include all my input variables

**Variable inclusion strategies:**

1. **Feature constraints:** Currently not directly supported, but you can:
   - Use feature selection preprocessing to identify important variables
   - Create custom loss functions that penalize unused variables
   - Check if your variables actually contribute to the target

2. **Verify data relationships:**

```julia
# Check correlation with target
using Statistics
[cor(X[:, i], y) for i in 1:size(X, 2)]
```

## Parameter and Configuration Issues

### Q: How do I choose the right operators for my problem?

**Domain-specific operator selection:**

1. **Start with basics:** Always include `+`, `*` for building expressions
2. **Add domain-relevant operators:**
   - Physics: `sin`, `cos`, `exp`, `log`, `^`
   - Biology: `exp`, `/`, `^` for growth/decay
   - Engineering: `sqrt`, `abs`, trigonometric functions

3. **Custom operators for your domain:**

```julia
# Example: Activation function for neural network analysis
sigmoid(x) = 1 / (1 + exp(-x))

model = SRRegressor(
    binary_operators=[+, -, *, /],
    unary_operators=[sigmoid, exp]
)
```

### Q: How do I set appropriate time budgets and iteration counts?

**Guidelines for search parameters:**

1. **Quick prototyping:** `niterations=10-30`
2. **Real problems:** `niterations=100-1000`
3. **Complex problems:** `niterations=1000+` with larger populations

4. **Use progress monitoring:**

```julia
# The search will show progress and hall-of-fame updates
# Quit early if no improvement for many iterations
```

### Q: My custom loss function isn't working as expected

**Custom loss troubleshooting:**

1. **Check function signature:**

```julia
# Elementwise loss (point-by-point)
elementwise_loss = "loss(prediction, target) = (prediction - target)^2"

# Full loss function (operates on entire dataset)
full_objective = "loss(tree, dataset) = sum((evaluate_tree(tree, dataset.X) - dataset.y).^2)"
```

2. **Handle edge cases:**

```julia
# Robust loss that handles NaN/Inf
elementwise_loss = """
function safe_loss(pred, target)
    if isnan(pred) || isinf(pred)
        return 1e6
    else
        return (pred - target)^2
    end
end
"""
```

## Advanced Feature Issues

### Q: Template expressions with #N placeholders aren't working

**Template expression troubleshooting:**

**Critical:** Never replace `#1`, `#2`, etc. with dataset variable names! These refer to function arguments.

```julia
# Correct template usage
expressions = [
    "sin(#1) + cos(#2)",     # #1, #2 are function arguments
    "#1 * exp(#2) + #3"      # Will take 3 arguments from dataset
]

model = SRRegressor(
    expression_specs=expressions,
    # ... other parameters
)
```

The `#N` syntax creates templates that get filled with dataset columns during search, but the placeholders themselves should never be renamed.

### Q: How do I use external Julia libraries for custom operators?

**Loading external libraries:**

```julia
# Import Julia and add packages
using Pkg
Pkg.add("SpecialFunctions")
using SpecialFunctions

# Define custom operators using external functions
bessel_op(x, y) = besselj(abs(x), abs(y))  # Make safe for all real inputs

model = SRRegressor(
    binary_operators=[+, -, *, bessel_op],
    nested_constraints=Dict(
        :bessel_op => Dict(:bessel_op => 0)  # Prevent nested Bessel functions
    )
)
```

### Q: Dimensional analysis constraints aren't working

**Dimensional analysis troubleshooting:**

1. **Define units correctly:**

```julia
using DynamicQuantities

model = SRRegressor(
    binary_operators=[+, -, *, /],
    dimensional_constraint_penalty=1e6,
    # Define units for your variables
    unit_constraints=Dict(
        1 => u"m",      # First variable has units of meters
        2 => u"s"       # Second variable has units of seconds
    )
)
```

2. **Common unit issues:**
   - Ensure all variables have properly defined units
   - Check that your target variable's units are achievable
   - Some operators may not preserve dimensional consistency

## Data and Input Issues

### Q: How should I preprocess my data?

**Data preprocessing best practices:**

1. **Handle missing data:**

```julia
# Remove rows with missing values
mask = .!any(ismissing, eachrow([X y]))
X_clean = X[mask, :]
y_clean = y[mask]
```

2. **Feature scaling:**

```julia
using MLJ
# Standardize features
transformer = Standardizer()
mach_transform = machine(transformer, X)
fit!(mach_transform)
X_scaled = MLJ.transform(mach_transform, X)
```

3. **Outlier detection:**

```julia
# Simple outlier removal (±3 standard deviations)
using Statistics
outliers = abs.(y .- mean(y)) .> 3 * std(y)
X_clean = X[.!outliers, :]
y_clean = y[.!outliers]
```

### Q: I have high-dimensional data - how do I handle many features?

**Dimensionality reduction strategies:**

1. **Feature selection preprocessing:**

```julia
using MLJFeatureSelection

# Use gradient boosting for feature selection
selector = FeatureSelector(
    :rfe,  # Recursive feature elimination
    n_features=5  # Select top 5 features
)
mach_selector = machine(selector, X, y)
fit!(mach_selector)
X_selected = MLJ.transform(mach_selector, X)
```

2. **Symbolic distillation approach:**
   - First train a neural network on high-dimensional data
   - Then use symbolic regression on the neural network's learned features
   - See the paper examples for detailed methodology

### Q: My data has noise - how do I handle it?

**Noise handling strategies:**

1. **Weighted loss functions:**

```julia
# If you know measurement uncertainties
weights = 1.0 ./ measurement_errors.^2

model = SRRegressor(
    elementwise_loss="loss(pred, target, weight) = weight * (pred - target)^2"
)
```

2. **Robust loss functions:**

```julia
# Huber loss for outlier robustness
huber_loss = """
function huber_loss(pred, target)
    delta = 1.0
    diff = abs(pred - target)
    if diff <= delta
        return 0.5 * diff^2
    else
        return delta * (diff - 0.5 * delta)
    end
end
"""

model = SRRegressor(elementwise_loss=huber_loss)
```

## Technical and Implementation Issues

### Q: I'm getting type errors or precision issues

**Type and precision troubleshooting:**

1. **Check input types:**

```julia
# Ensure consistent numeric types
X = Float64.(X)  # Convert to Float64
y = Float64.(y)
```

2. **Precision settings:**

```julia
model = SRRegressor(
    precision=Float32,  # Use Float32 for speed, Float64 for precision
    # ... other parameters
)
```

### Q: How do I save and load trained models?

**Model persistence:**

```julia
using Serialization

# Save model
serialize("my_model.jls", mach)

# Load model
loaded_mach = deserialize("my_model.jls")

# Make predictions
predictions = MLJ.predict(loaded_mach, X_new)
```

### Q: The MLJ interface is giving me errors

**MLJ interface troubleshooting:**

1. **Check MLJ compatibility:**

```julia
using MLJ
MLJ.version()  # Ensure recent version
```

2. **Proper MLJ usage pattern:**

```julia
# Always wrap in machine
model = SRRegressor(niterations=10)
mach = machine(model, X, y)  # Required step
fit!(mach)

# Get results
r = report(mach)
predictions = MLJ.predict(mach, X)
```

### Q: I need to use SymbolicRegression.jl directly (without MLJ)

**Direct library usage:**

```julia
using SymbolicRegression

options = Options(
    binary_operators=[+, -, *, /],
    unary_operators=[sin, cos],
    npopulations=20,
    niterations=100
)

# Direct search
hall_of_fame = equation_search(X, y; options=options)

# Best equations at each complexity
best_equations = [member.tree for member in hall_of_fame.members[hall_of_fame.exists]]
```

## Performance Monitoring and Debugging

### Q: How do I monitor search progress effectively?

**Progress monitoring:**

1. **Watch the hall of fame:** New entries indicate progress
2. **Check head worker occupation:** Should be <50% for good parallelization
3. **Monitor expressions/second:** Should be >1000 for good performance
4. **Early stopping:** If no improvement for 100+ iterations, consider stopping

### Q: How do I debug expressions that don't make sense?

**Expression debugging:**

1. **Check expression evaluation:**

```julia
# Manually evaluate your expression
best_expr = report(mach).equations[report(mach).best_idx]
test_prediction = best_expr(X[1:5, :])  # Test on first 5 rows
```

2. **Simplification issues:**

```julia
# Sometimes expressions can be simplified
using SymbolicUtils
simplified = simplify(best_expr)
```

3. **Check for numerical issues:**
   - Look for very large or very small constants
   - Check for divide-by-zero scenarios
   - Verify operator precedence in complex expressions

## When to Try Different Approaches

### If Standard Search Isn't Working:

1. **Template expressions** - when you have domain knowledge about functional form
2. **Custom operators** - when standard math functions don't capture your domain
3. **Dimensional analysis** - for physics problems with units
4. **Multi-target regression** - when you have multiple related outputs
5. **Symbolic distillation** - for high-dimensional problems where neural networks work

### Performance vs Accuracy Trade-offs:

- **Faster search:** Reduce `niterations`, `populations`, `maxsize`
- **Better results:** Increase all the above parameters
- **Memory issues:** Reduce `population_size`, use `Float32` precision
- **Interpretability:** Use `maxsize` < 20, add parsimony pressure

Remember: Symbolic regression is a heuristic search process. If one configuration doesn't work, try adjusting the search space, operators, or constraints rather than just increasing iterations.
