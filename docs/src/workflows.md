# Scientific Workflows

This guide provides comprehensive workflows for using SymbolicRegression.jl across different domains and applications. Each workflow includes step-by-step instructions, code examples, parameter recommendations, and troubleshooting advice based on community best practices.

## 1. Scientific Discovery Workflow

The core workflow for discovering mathematical relationships from experimental or simulation data.

### Prerequisites

- Clean, preprocessed data with reasonable signal-to-noise ratio
- Domain knowledge to select appropriate operators and constraints
- Understanding of the expected complexity of the underlying relationship

### Step-by-Step Process

#### Step 1: Data Preparation and Exploration

```julia
using SymbolicRegression, MLJ
using Statistics, Plots

# Load and examine your data
X = your_input_data  # Should be a matrix (n_samples × n_features)
y = your_output_data # Should be a vector (n_samples,)

# Basic data exploration
println("Data shape: ", size(X))
println("Output range: ", extrema(y))
println("Input ranges: ", [extrema(X[:, i]) for i in 1:size(X, 2)])

# Check for correlations and visualize if feasible
if size(X, 2) <= 3
    # Create scatter plots for low-dimensional data
    scatter(X[:, 1], y, xlabel="x1", ylabel="y", alpha=0.6)
end

# Check for missing values or outliers
any_missing = any(ismissing, X) || any(ismissing, y)
any_infinite = any(!isfinite, X) || any(!isfinite, y)
println("Missing values: ", any_missing)
println("Non-finite values: ", any_infinite)
```

#### Step 2: Initial Parameter Selection

Start with conservative parameters for your first run:

```julia
# Basic configuration for initial exploration
model = SRRegressor(
    # Core operators - start simple
    binary_operators=[+, -, *, /],
    unary_operators=[exp, log, sin, cos],

    # Search parameters - conservative start
    niterations=30,         # Start small, increase if needed
    populations=15,         # Multiple populations for diversity
    population_size=33,     # Reasonable population size

    # Complexity control
    maxsize=20,            # Prevent overly complex expressions
    maxdepth=6,            # Limit tree depth

    # Numerical stability
    parsimony=0.0032,      # Small parsimony penalty
    constraints=[
        (/,) => 5,         # Limit division complexity
        (log,) => 5,       # Limit log complexity
        (exp,) => 3        # Be more restrictive with exp
    ],

    # Computational efficiency
    procs=4,               # Use multiple processes if available
    multithreading=true
)
```

#### Step 3: Initial Search

```julia
# Fit the model
mach = machine(model, X, y)
fit!(mach)

# Examine results
r = report(mach)
println("Search completed. Found ", length(r.equations), " expressions.")

# Look at the Hall of Fame
for i in 1:min(10, length(r.equations))
    eq = r.equations[i]
    println("Complexity $(eq.complexity): Loss $(eq.loss) - $(eq)")
end

# Get the best tradeoff
best_eq = r.equations[r.best_idx]
println("Selected best expression: ", best_eq)
```

#### Step 4: Validation and Interpretation

```julia
# Cross-validation for robustness
using MLJBase: evaluate, CV
using Random: sample

# Simple train-test split validation
train_idx = sample(1:length(y), Int(0.8 * length(y)), replace=false)
test_idx = setdiff(1:length(y), train_idx)

X_train, X_test = X[train_idx, :], X[test_idx, :]
y_train, y_test = y[train_idx], y[test_idx]

# Refit on training data
model_val = SRRegressor(model.binary_operators, model.unary_operators,
                       niterations=model.niterations)
mach_val = machine(model_val, X_train, y_train)
fit!(mach_val)

# Test on validation set
r_val = report(mach_val)
best_eq_val = r_val.equations[r_val.best_idx]
y_pred = predict(mach_val, X_test)

mse_test = mean((y_test .- y_pred).^2)
println("Test MSE: ", mse_test)
println("Test R²: ", 1 - mse_test/var(y_test))
```

#### Step 5: Iterative Refinement

Based on initial results, refine your approach:

```julia
# Refinement strategies based on initial results:

# If no good solutions found:
refined_model = SRRegressor(
    # Expand operator set
    binary_operators=[+, -, *, /, ^],
    unary_operators=[exp, log, sin, cos, sqrt, abs],

    # Increase search intensity
    niterations=100,        # More iterations
    populations=20,         # More populations
    ncyclesperiteration=500, # More cycles per iteration

    # Relax complexity constraints slightly
    maxsize=25,
    maxdepth=8,

    # Adjust loss function if needed
    loss_function=L2DistLoss(),  # Try different losses
)

# If expressions are too complex:
simplified_model = SRRegressor(
    binary_operators=[+, -, *],  # Remove division temporarily
    unary_operators=[],          # Start without unary ops

    maxsize=15,                  # Stricter complexity limit
    maxdepth=4,
    parsimony=0.01,             # Higher parsimony penalty

    # Add constraints
    constraints=[
        (*,) => 4,              # Limit multiplication chains
    ]
)
```

### Expected Outcomes

**Success indicators:**

- Loss decreases significantly during search
- Multiple expressions found across complexity levels
- Best selected expression has reasonable complexity
- Good performance on validation data
- Expression makes physical/domain sense

**Warning signs:**

- All expressions have very high loss
- Only trivial expressions (just constants) found
- Extremely complex expressions with marginal improvement
- Poor generalization to test data
- Numerically unstable expressions

### Common Problems and Solutions

**Problem: Search finds only constants or trivial expressions**

_Solutions:_

```julia
# Increase search intensity and operator diversity
model = SRRegressor(
    binary_operators=[+, -, *, /, ^],
    unary_operators=[exp, log, sin, cos, sqrt, tanh],
    niterations=200,           # Much longer search
    populations=30,            # More diversity
    tournament_selection_n=8,  # More selection pressure
    perturbation_factor=0.1,   # Higher mutation rates
)
```

**Problem: Expressions are too complex or overfitted**

_Solutions:_

```julia
# Strengthen complexity penalties
model = SRRegressor(
    maxsize=12,                # Stricter size limit
    parsimony=0.05,           # Much higher parsimony
    adaptive_parsimony_scaling=100.0,  # Adaptive scaling

    # Add early stopping
    early_stop_condition="stop_if(loss, complexity) = loss < 1e-6 && complexity < 8"
)
```

**Problem: Numerical instability or NaN errors**

_Solutions:_

```julia
# Add numerical safeguards
model = SRRegressor(
    constraints=[
        (/,) => 8,            # Penalize division heavily
        (^,) => 6,            # Limit exponentiation
        (log,) => 4,          # Be careful with logarithms
    ],

    # Enable turbo mode for better numerical handling
    turbo=true,

    # Use more stable operators
    unary_operators=[sin, cos, tanh, atan],  # Bounded functions
)
```

### Advanced Tips

1. **Feature Engineering**: Consider transforming inputs before symbolic regression:

   ```julia
   # Log-transform heavily skewed variables
   X_transformed = copy(X)
   X_transformed[:, 1] = log.(abs.(X[:, 1]) .+ 1e-10)
   ```

2. **Multi-Stage Discovery**: Use simple expressions to guide more complex searches:

   ```julia
   # Stage 1: Find basic structure
   simple_model = SRRegressor(binary_operators=[+, -, *], maxsize=10)
   # Stage 2: Refine with more operators
   complex_model = SRRegressor(binary_operators=[+, -, *, /, ^], maxsize=20)
   ```

3. **Ensemble Methods**: Combine multiple searches for robustness:
   ```julia
   # Run multiple independent searches
   models = [SRRegressor(random_state=i, niterations=50) for i in 1:5]
   results = [fit!(machine(m, X, y)) for m in models]
   ```

---

## 2. Domain-Specific Workflows

### Physics Applications

Physics problems often involve well-known functional forms and dimensionally consistent relationships.

#### Prerequisites

- Understanding of physical units and dimensional analysis
- Knowledge of expected functional forms (exponential decay, power laws, etc.)
- Awareness of physical constraints and symmetries

#### Typical Physics Workflow

```julia
# Example: Discovering laws of motion, decay processes, etc.
physics_model = SRRegressor(
    # Physics-relevant operators
    binary_operators=[+, -, *, /, ^],
    unary_operators=[exp, log, sin, cos, sqrt, abs],

    # Common physics functional forms
    extra_sympy_mappings=Dict(
        "heaviside" => x -> x >= 0 ? 1.0 : 0.0,
        "gaussian" => x -> exp(-x^2)
    ),

    # Dimensional consistency (if using DimensionalAnalysis.jl)
    dimensional_constraint_penalty=10.0,

    # Physics often has exact relationships
    optimizer_nrestarts=3,     # Better constant optimization
    optimizer_iterations=300,

    # Allow for physical symmetries
    constraints=[
        (^,) => 3,            # Physical laws rarely have high powers
        (exp,) => 4,          # Exponentials common in physics
    ]
)

# Example: Arrhenius equation discovery
# Expected form: k = A * exp(-Ea / (R * T))
T = temperature_data
k = rate_constant_data

# Prepare data (log-transform often helps with exponentials)
X_physics = hcat(T, 1 ./ T)
y_physics = log.(k)

# Fit model
mach_physics = machine(physics_model, X_physics, y_physics)
fit!(mach_physics)
```

#### Physics-Specific Tips

1. **Dimensional Analysis**: Use units to constrain search space
2. **Logarithmic Transforms**: Many physics laws are exponential
3. **Symmetry Constraints**: Use known symmetries to reduce search space
4. **Conservation Laws**: Ensure discovered laws respect conservation principles

### Chemistry Applications

Chemistry problems often involve reaction kinetics, thermodynamic relationships, and molecular properties.

#### Prerequisites

- Understanding of chemical kinetics and thermodynamics
- Knowledge of typical concentration ranges and units
- Awareness of chemical constraints (stoichiometry, equilibrium)

#### Typical Chemistry Workflow

```julia
# Example: Reaction kinetics discovery
chemistry_model = SRRegressor(
    # Chemistry-relevant operators
    binary_operators=[+, -, *, /, ^],
    unary_operators=[exp, log, sqrt],

    # Common chemistry functions
    extra_sympy_mappings=Dict(
        "arrhenius" => (E, T) -> exp(-E / T),
        "michaelis_menten" => (S, Km, Vmax) -> Vmax * S / (Km + S)
    ),

    # Kinetics often involves products and ratios
    constraints=[
        (*,) => 6,            # Products of concentrations
        (/,) => 4,            # Ratios in equilibrium
        (^,) => 3,            # Power laws in kinetics
    ],

    # High precision for equilibrium constants
    optimizer_nrestarts=5,
    optimizer_iterations=500
)

# Example: Michaelis-Menten kinetics
substrate_conc = [0.1, 0.2, 0.5, 1.0, 2.0, 5.0, 10.0]
reaction_rate = [0.05, 0.09, 0.17, 0.25, 0.33, 0.42, 0.45]

X_chem = reshape(substrate_conc, :, 1)
y_chem = reaction_rate

mach_chem = machine(chemistry_model, X_chem, y_chem)
fit!(mach_chem)
```

### Engineering Applications

Engineering problems often involve control systems, fluid dynamics, and optimization.

#### Prerequisites

- Understanding of engineering principles and constraints
- Knowledge of typical parameter ranges and units
- Awareness of stability and performance requirements

#### Typical Engineering Workflow

```julia
# Example: Control system or fluid dynamics
engineering_model = SRRegressor(
    # Engineering-relevant operators
    binary_operators=[+, -, *, /, ^],
    unary_operators=[exp, log, sin, cos, tanh, abs],

    # Engineering functions
    extra_sympy_mappings=Dict(
        "sigmoid" => x -> 1 / (1 + exp(-x)),
        "relu" => x -> max(0, x),
        "step" => x -> x > 0 ? 1.0 : 0.0
    ),

    # Engineering systems often have bounded outputs
    constraints=[
        (tanh,) => 2,         # Bounded activation functions
        (exp,) => 4,          # Exponential responses
        (/,) => 6,            # Transfer functions
    ],

    # Robustness important in engineering
    perturbation_factor=0.05,  # Lower mutation for stability
    tournament_selection_n=6
)

# Example: System identification
input_signal = control_input_data
output_response = system_output_data

# Often helpful to include time delays and derivatives
X_eng = hcat(input_signal, [0; diff(input_signal)],
             [output_response[1:end-1]; 0])  # Previous output
y_eng = output_response

mach_eng = machine(engineering_model, X_eng, y_eng)
fit!(mach_eng)
```

---

## 3. Advanced Research Workflows

### Custom Loss Functions

For specialized objectives beyond standard MSE.

#### When to Use Custom Loss Functions

- Asymmetric error penalties (false positives vs false negatives)
- Robust regression (outlier resistance)
- Physics constraints (conservation laws, boundary conditions)
- Multi-objective optimization (accuracy + interpretability + physical validity)

#### Custom Loss Workflow

```julia
# Example: Robust loss function for outlier resistance
function robust_loss(tree, dataset::Dataset{T,L}, options) where {T,L}
    # Evaluate the tree on the dataset
    prediction, completed = eval_tree_array(tree, dataset.X, options)

    if !completed
        return L(Inf)  # Penalty for failed evaluation
    end

    # Huber loss (robust to outliers)
    residuals = prediction .- dataset.y
    delta = 1.0  # Huber parameter

    huber_loss = sum(residuals) do r
        if abs(r) <= delta
            0.5 * r^2
        else
            delta * (abs(r) - 0.5 * delta)
        end
    end

    return L(huber_loss / length(dataset.y))
end

# Use custom loss
custom_model = SRRegressor(
    binary_operators=[+, -, *, /],
    unary_operators=[exp, log],
    loss_function=robust_loss,
    niterations=50
)
```

#### Physics-Informed Loss Functions

```julia
# Example: Conservation law enforcement
function physics_informed_loss(tree, dataset::Dataset{T,L}, options) where {T,L}
    prediction, completed = eval_tree_array(tree, dataset.X, options)

    if !completed
        return L(Inf)
    end

    # Standard MSE
    mse = sum((prediction .- dataset.y).^2) / length(dataset.y)

    # Physics constraint: energy conservation
    # Assume X[:, 1] is kinetic energy, X[:, 2] is potential energy
    total_energy = dataset.X[1, :] .+ dataset.X[2, :]
    energy_violation = var(total_energy)  # Should be constant

    # Combined loss
    return L(mse + 10.0 * energy_violation)  # Weight physics constraint
end
```

### Template Expression Workflows

For problems with known structural forms but unknown parameters.

#### When to Use Template Expressions

- Known physical laws with unknown parameters
- Hierarchical models with shared sub-expressions
- Multi-component systems (e.g., mixture models)
- Constraining search to interpretable forms

#### Template Expression Workflow

```julia
using SymbolicRegression: TemplateExpression

# Example: Multi-component Arrhenius-like model
# Form: y = A1*exp(-E1/T) + A2*exp(-E2/T) + C
template_spec = TemplateExpression(
    [
        "A1 * exp(-E1 / T)",      # Component 1
        "A2 * exp(-E2 / T)",      # Component 2
        "C"                       # Constant offset
    ],
    combine=+,                    # How to combine components
    variable_names=["T"]          # Input variables
)

template_model = SRRegressor(
    expression_spec=template_spec,
    binary_operators=[+, -, *, /],
    unary_operators=[exp],
    niterations=100,

    # Template-specific settings
    optimizer_nrestarts=10,       # Good constant optimization crucial
    optimizer_iterations=1000,
    perturbation_factor=0.1
)

# Fit template model
X_template = reshape(temperature_data, :, 1)
y_template = reaction_data

mach_template = machine(template_model, X_template, y_template)
fit!(mach_template)

# Extract fitted parameters
r_template = report(mach_template)
best_template = r_template.equations[r_template.best_idx]
println("Fitted template: ", best_template)
```

### Multi-Objective Optimization

Balancing multiple objectives simultaneously.

#### Multi-Objective Workflow

```julia
# Example: Accuracy + Simplicity + Physical Validity
function multi_objective_loss(tree, dataset::Dataset{T,L}, options) where {T,L}
    prediction, completed = eval_tree_array(tree, dataset.X, options)

    if !completed
        return L(Inf)
    end

    # Objective 1: Prediction accuracy
    mse = sum((prediction .- dataset.y).^2) / length(dataset.y)

    # Objective 2: Simplicity (complexity penalty)
    complexity = count_nodes(tree)
    complexity_penalty = 0.01 * complexity^2

    # Objective 3: Physical validity (example: monotonicity)
    if size(dataset.X, 1) > 1
        # Check if relationship is monotonic in first variable
        sorted_idx = sortperm(dataset.X[1, :])
        sorted_pred = prediction[sorted_idx]
        monotonicity_violation = sum(max.(0, diff(sorted_pred) .* -1))  # Penalize non-monotonic
        monotonicity_penalty = 0.1 * monotonicity_violation
    else
        monotonicity_penalty = 0.0
    end

    # Combined multi-objective loss
    total_loss = mse + complexity_penalty + monotonicity_penalty
    return L(total_loss)
end

multi_obj_model = SRRegressor(
    binary_operators=[+, -, *, /],
    unary_operators=[exp, log],
    loss_function=multi_objective_loss,
    niterations=200,
    populations=20  # More diversity for multi-objective
)
```

### Distributed Computing Workflows

For large-scale problems requiring significant computational resources.

#### Prerequisites

- Access to multiple compute nodes or high-core-count machines
- Understanding of Julia's distributed computing capabilities
- Proper environment setup across compute nodes

#### Distributed Workflow

```julia
using Distributed

# Add worker processes
addprocs(16)  # or use cluster manager

@everywhere using SymbolicRegression, MLJ

# Distributed search
distributed_model = SRRegressor(
    binary_operators=[+, -, *, /, ^],
    unary_operators=[exp, log, sin, cos, sqrt],

    # Distributed settings
    procs=16,                    # Use all available processes
    populations=32,              # More populations for parallel search

    # Longer search enabled by parallelization
    niterations=500,
    ncyclesperiteration=1000,

    # Communication settings
    migration=true,              # Enable population migration
    hof_migration=true,          # Share best expressions
    migration_fraction=0.05      # Fraction of population to migrate
)

# Large-scale fitting
X_large = your_large_dataset_X
y_large = your_large_dataset_y

mach_distributed = machine(distributed_model, X_large, y_large)
fit!(mach_distributed)

# Clean up
rmprocs(workers())
```

---

## 4. Production Workflows

### Model Validation and Testing

Comprehensive validation before deploying discovered expressions.

#### Validation Workflow

```julia
using MLJBase: evaluate, CV, StratifiedCV
using Statistics: mean, std
using Random: sample

# Comprehensive validation function
function comprehensive_validation(model, X, y; n_folds=5, n_bootstrap=100)
    results = Dict()

    # 1. Cross-validation
    cv_machine = machine(model, X, y)
    cv_results = evaluate!(cv_machine, resampling=CV(nfolds=n_folds),
                          measure=[rms, mae, rsquared])

    results[:cv_rmse] = cv_results.measurement[1]
    results[:cv_mae] = cv_results.measurement[2]
    results[:cv_r2] = cv_results.measurement[3]

    # 2. Bootstrap validation
    n_samples = length(y)
    bootstrap_scores = Float64[]

    for i in 1:n_bootstrap
        # Bootstrap sample
        idx = sample(1:n_samples, n_samples, replace=true)
        X_boot, y_boot = X[idx, :], y[idx]

        # Out-of-bag samples
        oob_idx = setdiff(1:n_samples, unique(idx))
        if length(oob_idx) > 10  # Enough OOB samples
            X_oob, y_oob = X[oob_idx, :], y[oob_idx]

            # Fit and test
            boot_mach = machine(model, X_boot, y_boot)
            fit!(boot_mach)
            y_pred = predict(boot_mach, X_oob)

            score = sqrt(mean((y_oob .- y_pred).^2))
            push!(bootstrap_scores, score)
        end
    end

    results[:bootstrap_rmse_mean] = mean(bootstrap_scores)
    results[:bootstrap_rmse_std] = std(bootstrap_scores)

    # 3. Residual analysis
    final_mach = machine(model, X, y)
    fit!(final_mach)
    y_pred_full = predict(final_mach, X)
    residuals = y .- y_pred_full

    results[:outlier_fraction] = count(abs.(residuals) .> 3*std(residuals)) / length(residuals)

    return results, final_mach
end

# Run comprehensive validation
validation_results, validated_model = comprehensive_validation(model, X, y)
println("Validation Results:")
for (key, value) in validation_results
    println("  $key: $value")
end
```

#### Expression Stability Testing

```julia
# Test stability across different random seeds
function stability_test(model_constructor, X, y; n_runs=10)
    expressions = String[]
    scores = Float64[]

    for i in 1:n_runs
        # Different random seed for each run
        model = model_constructor(random_state=i)
        mach = machine(model, X, y)
        fit!(mach)

        r = report(mach)
        best_expr = r.equations[r.best_idx]
        push!(expressions, string(best_expr))
        push!(scores, best_expr.loss)
    end

    # Analyze stability
    unique_expressions = unique(expressions)
    expression_counts = [count(==(expr), expressions) for expr in unique_expressions]

    println("Stability Analysis:")
    println("  Unique expressions found: ", length(unique_expressions))
    println("  Most common expression ($(maximum(expression_counts))/$(n_runs) runs): ",
            unique_expressions[argmax(expression_counts)])
    println("  Score std dev: ", std(scores))

    return expressions, scores
end

# Test model stability
model_constructor = (;kwargs...) -> SRRegressor(
    binary_operators=[+, -, *, /],
    unary_operators=[exp, log],
    niterations=100;
    kwargs...
)

expressions, scores = stability_test(model_constructor, X, y)
```

### Saving and Loading Models

Proper model persistence for production use.

#### Model Persistence Workflow

```julia
using Serialization
using Dates: now
using Pkg: pkgversion

# Comprehensive model saving
function save_sr_model(mach, filepath; metadata=Dict())
    model_data = Dict(
        "model" => mach.model,
        "fitted_params" => fitted_params(mach),
        "report" => report(mach),
        "metadata" => merge(metadata, Dict(
            "save_time" => now(),
            "julia_version" => VERSION,
            "sr_version" => pkgversion(SymbolicRegression)
        ))
    )

    serialize(filepath, model_data)
    println("Model saved to: $filepath")
end

# Comprehensive model loading with validation
function load_sr_model(filepath)
    if !isfile(filepath)
        error("Model file not found: $filepath")
    end

    model_data = deserialize(filepath)

    # Version compatibility check
    saved_version = get(model_data["metadata"], "sr_version", "unknown")
    current_version = pkgversion(SymbolicRegression)

    if saved_version != current_version
        @warn "Version mismatch: saved with $saved_version, loading with $current_version"
    end

    # Reconstruct machine
    model = model_data["model"]
    mach = machine(model)

    # Restore fitted parameters (if available)
    if haskey(model_data, "fitted_params")
        # Note: This may require additional implementation
        @warn "Fitted parameter restoration not fully implemented"
    end

    return mach, model_data["report"], model_data["metadata"]
end

# Example usage
metadata = Dict(
    "dataset" => "experimental_data_v1.2",
    "experimenter" => "Dr. Smith",
    "experiment_date" => "2024-01-15",
    "notes" => "Final model after parameter tuning"
)

save_sr_model(validated_model, "production_model_v1.jls", metadata=metadata)
loaded_mach, loaded_report, saved_metadata = load_sr_model("production_model_v1.jls")
```

### Integration into Larger Systems

Deploying discovered expressions in production environments.

#### Production Integration Workflow

```julia
# Create a production-ready expression evaluator
struct ProductionExpression
    expression::String
    variable_names::Vector{String}
    eval_function::Function
    metadata::Dict

    function ProductionExpression(expr, var_names, metadata=Dict())
        # Create optimized evaluation function
        eval_func = create_fast_evaluator(expr, var_names)
        new(expr, var_names, eval_func, metadata)
    end
end

function create_fast_evaluator(expr_string, var_names)
    # Convert to optimized Julia function
    # This is a simplified example - production version would be more robust

    expr_parsed = Meta.parse(expr_string)

    # Create function dynamically
    func_def = quote
        function fast_eval($(Symbol.(var_names)...))
            $expr_parsed
        end
    end

    eval(func_def)
    return fast_eval
end

# Production prediction with error handling
function predict_production(prod_expr::ProductionExpression, X::Matrix)
    n_samples = size(X, 1)
    predictions = Vector{Float64}(undef, n_samples)

    for i in 1:n_samples
        try
            # Extract input variables
            inputs = [X[i, j] for j in 1:length(prod_expr.variable_names)]

            # Evaluate expression
            pred = prod_expr.eval_function(inputs...)

            # Numerical validation
            if isfinite(pred)
                predictions[i] = pred
            else
                predictions[i] = NaN
                @warn "Non-finite prediction for sample $i"
            end

        catch e
            predictions[i] = NaN
            @warn "Evaluation error for sample $i: $e"
        end
    end

    return predictions
end

# Convert SR model to production expression
function to_production_expression(mach)
    r = report(mach)
    best_eq = r.equations[r.best_idx]

    # Extract variable names (assuming standard naming)
    var_names = ["x$i" for i in 1:size(fitted_params(mach).X, 2)]

    metadata = Dict(
        "complexity" => best_eq.complexity,
        "loss" => best_eq.loss,
        "creation_time" => now(),
        "source" => "SymbolicRegression.jl"
    )

    return ProductionExpression(string(best_eq), var_names, metadata)
end

# Example usage
prod_expr = to_production_expression(validated_model)
production_predictions = predict_production(prod_expr, X_new)
```

### Version Management and Reproducibility

Ensuring reproducible results across different environments.

#### Reproducibility Workflow

```julia
using Pkg, UUIDs
using JSON3
using SHA: sha256

# Create reproducible environment specification
function create_reproducible_spec(model, X, y, results;
                                 experiment_name="sr_experiment")

    spec = Dict(
        "experiment_info" => Dict(
            "name" => experiment_name,
            "timestamp" => now(),
            "uuid" => string(uuid4())
        ),

        "environment" => Dict(
            "julia_version" => string(VERSION),
            "pkg_status" => Pkg.status(),
            "machine_info" => Dict(
                "hostname" => gethostname(),
                "cpu_threads" => Threads.nthreads(),
                "memory_gb" => Sys.total_memory() / 1024^3
            )
        ),

        "model_config" => Dict(
            "binary_operators" => string.(model.binary_operators),
            "unary_operators" => string.(model.unary_operators),
            "niterations" => model.niterations,
            "populations" => model.populations,
            "population_size" => model.population_size,
            "random_state" => get(model, :random_state, nothing)
        ),

        "data_info" => Dict(
            "X_shape" => size(X),
            "y_shape" => size(y),
            "X_checksum" => bytes2hex(sha256(string(X))),
            "y_checksum" => bytes2hex(sha256(string(y)))
        ),

        "results" => results
    )

    return spec
end

# Save reproducible specification
function save_reproducible_experiment(spec, filepath)
    open(filepath, "w") do f
        JSON3.pretty(f, spec)
    end
    println("Reproducible experiment spec saved to: $filepath")
end

# Load and validate reproducible experiment
function load_and_validate_experiment(spec_filepath)
    spec = JSON3.read(read(spec_filepath, String))

    # Validate environment
    current_version = string(VERSION)
    saved_version = spec["environment"]["julia_version"]

    if current_version != saved_version
        @warn "Julia version mismatch: current=$current_version, saved=$saved_version"
    end

    # Additional validations...
    println("Experiment loaded: ", spec["experiment_info"]["name"])
    println("Original timestamp: ", spec["experiment_info"]["timestamp"])

    return spec
end

# Example usage
experiment_spec = create_reproducible_spec(
    model, X, y, validation_results,
    experiment_name="physics_law_discovery_v2"
)

save_reproducible_experiment(experiment_spec, "experiment_spec.json")
```

---

## 5. Troubleshooting Workflows

### Systematic Debugging When Results Are Poor

Step-by-step diagnosis of poor performance.

#### Debugging Workflow

```julia
using StatsBase: skewness, cor

# Comprehensive debugging function
function diagnose_poor_performance(model, X, y; verbose=true)
    diagnostics = Dict()

    println("🔍 Starting systematic diagnosis...")

    # 1. Data quality checks
    println("\\n1️⃣ Data Quality Analysis")

    # Check for basic issues
    has_missing = any(ismissing, X) || any(ismissing, y)
    has_infinite = any(!isfinite, X) || any(!isfinite, y)
    has_constant_features = any(std(X[:, i]) < 1e-10 for i in 1:size(X, 2))

    diagnostics[:data_issues] = Dict(
        "missing_values" => has_missing,
        "infinite_values" => has_infinite,
        "constant_features" => has_constant_features
    )

    verbose && println("  Missing values: $has_missing")
    verbose && println("  Infinite values: $has_infinite")
    verbose && println("  Constant features: $has_constant_features")

    # 2. Target variable analysis
    println("\\n2️⃣ Target Variable Analysis")

    y_stats = Dict(
        "mean" => mean(y),
        "std" => std(y),
        "range" => extrema(y),
        "skewness" => skewness(y),
        "outlier_fraction" => count(abs.(y .- mean(y)) .> 3*std(y)) / length(y)
    )

    diagnostics[:target_stats] = y_stats

    verbose && println("  Mean: $(y_stats["mean"])")
    verbose && println("  Std: $(y_stats["std"])")
    verbose && println("  Range: $(y_stats["range"])")
    verbose && println("  Outlier fraction: $(y_stats["outlier_fraction"])")

    # 3. Feature analysis
    println("\\n3️⃣ Feature Analysis")

    feature_stats = []
    for i in 1:size(X, 2)
        feature_stat = Dict(
            "feature" => i,
            "mean" => mean(X[:, i]),
            "std" => std(X[:, i]),
            "range" => extrema(X[:, i]),
            "correlation_with_target" => cor(X[:, i], y)
        )
        push!(feature_stats, feature_stat)

        if verbose
            println("  Feature $i: range=$(feature_stat["range"]), cor=$(round(feature_stat["correlation_with_target"], digits=3))")
        end
    end

    diagnostics[:feature_stats] = feature_stats

    # 4. Model configuration analysis
    println("\\n4️⃣ Model Configuration Analysis")

    config_issues = String[]

    # Check if operators are appropriate
    if isempty(model.unary_operators) && maximum(abs.(cor(X, y))) < 0.3
        push!(config_issues, "Low correlation with linear operators - consider adding unary operators (exp, log, sin, cos)")
    end

    if model.maxsize < 10 && maximum(abs.(cor(X, y))) < 0.5
        push!(config_issues, "Low correlation and small max size - consider increasing maxsize")
    end

    if model.niterations < 50
        push!(config_issues, "Very few iterations - consider increasing niterations")
    end

    diagnostics[:config_issues] = config_issues
    verbose && println("  Configuration issues: ", length(config_issues))
    for issue in config_issues
        verbose && println("    - $issue")
    end

    # 5. Test with simplified model
    println("\\n5️⃣ Baseline Model Test")

    simple_model = SRRegressor(
        binary_operators=[+, -, *],
        unary_operators=[],
        niterations=20,
        maxsize=7,
        populations=5
    )

    simple_mach = machine(simple_model, X, y)
    fit!(simple_mach)
    simple_report = report(simple_mach)

    if length(simple_report.equations) > 0
        best_simple = simple_report.equations[simple_report.best_idx]
        diagnostics[:baseline_performance] = Dict(
            "best_loss" => best_simple.loss,
            "best_complexity" => best_simple.complexity,
            "expression" => string(best_simple)
        )

        verbose && println("  Baseline model best loss: $(best_simple.loss)")
        verbose && println("  Baseline expression: $(string(best_simple))")
    else
        diagnostics[:baseline_performance] = "No expressions found"
        verbose && println("  ⚠️  Baseline model found no expressions!")
    end

    return diagnostics
end

# Usage
diagnostics = diagnose_poor_performance(model, X, y)
```

---

## 6. Large-Scale Data Workflows

### High-Dimensional and Large Dataset Strategies

Based on community experience, datasets with >10 features or >50K samples require specific approaches.

#### Prerequisites

- Understanding of computational constraints and memory limitations
- Knowledge of feature selection and dimensionality reduction techniques
- Awareness of parallelization trade-offs

#### Large Dataset Workflow (>100K samples)

```julia
# Community-recommended approach for large datasets
using SymbolicRegression, MLJ
using Statistics, Random

# Step 1: Intelligent subsampling (community insight)
# Symbolic regression often converges with smaller, representative samples
function intelligent_subsample(X, y; target_size=50000, stratify_quantiles=5)
    n_total = length(y)

    if n_total <= target_size
        return X, y
    end

    # Stratified sampling based on output quantiles (community best practice)
    quantiles = quantile(y, (0:stratify_quantiles) / stratify_quantiles)

    indices = Int[]
    samples_per_stratum = target_size ÷ stratify_quantiles

    for i in 1:(stratify_quantiles-1)
        lower, upper = quantiles[i], quantiles[i+1]
        stratum_indices = findall(q -> lower <= q < upper, y)

        if length(stratum_indices) > samples_per_stratum
            selected = sample(stratum_indices, samples_per_stratum, replace=false)
        else
            selected = stratum_indices
        end
        append!(indices, selected)
    end

    return X[indices, :], y[indices]
end

# Apply subsampling
X_sample, y_sample = intelligent_subsample(X, y)
println("Reduced dataset from $(size(X, 1)) to $(size(X_sample, 1)) samples")

# Step 2: Staged feature selection (community pattern)
# Start with aggressive feature selection, then refine
stage1_model = SRRegressor(
    binary_operators=[+, -, *],
    unary_operators=[],

    # Fast initial screening
    niterations=20,
    populations=10,
    population_size=20,

    # Enable feature selection
    select_k_features=min(5, size(X_sample, 2)),
    feature_selection="best",

    # Computational efficiency for large data
    batch_size=min(10000, length(y_sample)),
    turbo=true
)

# Fit stage 1
mach_stage1 = machine(stage1_model, X_sample, y_sample)
fit!(mach_stage1)

# Extract important features for stage 2
r1 = report(mach_stage1)
important_features = r1.selected_features
println("Selected features: ", important_features)

# Step 3: Refined search with selected features
X_refined = X_sample[:, important_features]

stage2_model = SRRegressor(
    # Expand operators once features are selected
    binary_operators=[+, -, *, /],
    unary_operators=[exp, log, sqrt],

    # More intensive search
    niterations=100,
    populations=20,
    population_size=40,

    # Large dataset optimizations
    batch_size=min(5000, length(y_sample)),
    batching=true,
    turbo=true,

    # Memory management
    procs=min(8, Threads.nthreads()),
    multithreading=true
)

mach_stage2 = machine(stage2_model, X_refined, y_sample)
fit!(mach_stage2)
```

#### High-Dimensional Data Workflow (>20 features)

```julia
# Community approach for high-dimensional problems
# Multi-stage search with progressive complexity

# Stage 1: Aggressive dimensionality reduction
initial_features = min(8, size(X, 2))

reduction_model = SRRegressor(
    binary_operators=[+, -, *],
    unary_operators=[],

    # Quick screening parameters
    niterations=30,
    populations=15,
    population_size=25,

    # Force feature selection
    select_k_features=initial_features,
    selection_method="best",  # Use best performing features

    # Prevent overfitting with many features
    maxsize=12,
    parsimony=0.01,
    adaptive_parsimony_scaling=100.0
)

# Stage 2: Ensemble approach with different feature sets
# Community insight: Different runs may find different important feature combinations
ensemble_results = []
feature_sets = []

for run in 1:5
    # Different random selections and seeds
    temp_model = SRRegressor(
        binary_operators=[+, -, *, /],
        unary_operators=[exp, log],

        select_k_features=initial_features + 2,  # Slightly expand
        random_state=run * 1000,

        niterations=50,
        populations=20,

        # Moderate complexity
        maxsize=15,
        parsimony=0.005
    )

    temp_mach = machine(temp_model, X, y)
    fit!(temp_mach)

    temp_report = report(temp_mach)
    push!(ensemble_results, temp_report)
    push!(feature_sets, temp_report.selected_features)
end

# Analyze ensemble results
all_selected_features = unique(vcat(feature_sets...))
consistent_features = []

for feature in all_selected_features
    selection_count = sum(feature in fs for fs in feature_sets)
    if selection_count >= 3  # Selected in majority of runs
        push!(consistent_features, feature)
    end
end

println("Consistently selected features: ", consistent_features)

# Stage 3: Final refinement with consensus features
X_final = X[:, consistent_features]

final_model = SRRegressor(
    binary_operators=[+, -, *, /, ^],
    unary_operators=[exp, log, sin, cos, sqrt],

    # Extended search on reduced feature space
    niterations=200,
    populations=30,
    population_size=50,

    # Allow more complexity with fewer features
    maxsize=25,
    maxdepth=8,

    # Fine-tuned regularization
    parsimony=0.001,
    adaptive_parsimony_scaling=20.0
)

mach_final = machine(final_model, X_final, y)
fit!(mach_final)
```

### Memory and Performance Optimization Patterns

#### Community-Tested Configuration for Large Datasets

```julia
# Optimized settings based on community feedback
large_data_model = SRRegressor(
    # Core settings
    binary_operators=[+, -, *, /],
    unary_operators=[exp, log, sqrt],

    # Memory-efficient batch processing
    batching=true,
    batch_size=5000,  # Community sweet spot for most systems

    # Computational optimization
    turbo=true,  # SIMD vectorization
    fast_cycle=true,  # Skip some optimization steps for speed

    # Parallelization tuned for large datasets
    procs=min(16, Threads.nthreads()),  # Don't over-parallelize
    multithreading=true,

    # Search parameters optimized for convergence speed
    niterations=100,  # Often sufficient for large datasets
    populations=20,   # Balance between diversity and overhead
    population_size=33,  # Community-tested optimal size

    # Aggressive early convergence
    ncyclesperiteration=300,  # Lower than default for speed

    # Memory management
    save_to_file=false,  # Disable if memory is tight

    # Complexity management for large datasets
    maxsize=20,  # Prevent overfitting
    parsimony=0.005,  # Higher parsimony for large data
    adaptive_parsimony_scaling=50.0  # Community-tested value
)
```

---

## 7. Validation and Robustness Workflows

### Advanced Cross-Validation Strategies

Community experience shows that standard validation approaches often miss symbolic regression-specific issues.

#### Multi-Modal Validation Workflow

```julia
using MLJBase: evaluate, CV, Holdout
using Statistics: mean, std, quantile

# Community-developed comprehensive validation
function comprehensive_sr_validation(model, X, y;
                                   validation_fraction=0.2,
                                   stability_runs=10,
                                   noise_levels=[0.01, 0.05, 0.1])

    results = Dict()
    n_samples = length(y)

    println("🔍 Starting comprehensive SR validation...")

    # 1. Hold-out validation with multiple splits
    println("\n1️⃣ Multiple Hold-out Validation")
    holdout_scores = Float64[]
    holdout_complexities = Int[]

    for split_seed in 1:5
        Random.seed!(split_seed)
        train_idx = sample(1:n_samples, Int((1-validation_fraction) * n_samples), replace=false)
        val_idx = setdiff(1:n_samples, train_idx)

        X_train, X_val = X[train_idx, :], X[val_idx, :]
        y_train, y_val = y[train_idx], y[val_idx]

        # Fit on training set
        temp_mach = machine(model, X_train, y_train)
        fit!(temp_mach)

        # Evaluate on validation set
        y_pred = predict(temp_mach, X_val)
        val_score = sqrt(mean((y_val .- y_pred).^2))

        # Get complexity of best model
        temp_report = report(temp_mach)
        best_complexity = temp_report.equations[temp_report.best_idx].complexity

        push!(holdout_scores, val_score)
        push!(holdout_complexities, best_complexity)
    end

    results[:holdout_rmse_mean] = mean(holdout_scores)
    results[:holdout_rmse_std] = std(holdout_scores)
    results[:complexity_consistency] = std(holdout_complexities)

    println("   Hold-out RMSE: $(round(results[:holdout_rmse_mean], digits=4)) ± $(round(results[:holdout_rmse_std], digits=4))")
    println("   Complexity variation: $(round(results[:complexity_consistency], digits=2))")

    # 2. Stability across random seeds (community best practice)
    println("\n2️⃣ Stability Analysis Across Seeds")
    seed_expressions = String[]
    seed_scores = Float64[]

    for seed in 1:stability_runs
        # Create model with specific seed
        seeded_model = SRRegressor(
            model.binary_operators, model.unary_operators,
            niterations=model.niterations,
            populations=model.populations,
            population_size=model.population_size,
            maxsize=model.maxsize,
            parsimony=model.parsimony,
            random_state=seed * 1234
        )

        temp_mach = machine(seeded_model, X, y)
        fit!(temp_mach)

        temp_report = report(temp_mach)
        best_eq = temp_report.equations[temp_report.best_idx]

        push!(seed_expressions, string(best_eq))
        push!(seed_scores, best_eq.loss)
    end

    # Analyze expression diversity
    unique_expressions = unique(seed_expressions)
    expression_frequencies = [count(==(expr), seed_expressions) for expr in unique_expressions]
    most_common_freq = maximum(expression_frequencies)

    results[:expression_diversity] = length(unique_expressions)
    results[:expression_consensus] = most_common_freq / stability_runs
    results[:score_stability] = std(seed_scores) / mean(seed_scores)  # Coefficient of variation

    println("   Unique expressions found: $(results[:expression_diversity])")
    println("   Consensus rate: $(round(results[:expression_consensus] * 100, digits=1))%")
    println("   Score CV: $(round(results[:score_stability], digits=3))")

    # 3. Noise robustness testing (community insight)
    println("\n3️⃣ Noise Robustness Analysis")
    noise_robustness = Float64[]

    for noise_level in noise_levels
        noise_scores = Float64[]

        for trial in 1:3  # Multiple trials per noise level
            # Add Gaussian noise
            y_noisy = y .+ noise_level * std(y) * randn(length(y))

            temp_mach = machine(model, X, y_noisy)
            fit!(temp_mach)

            # Test on original (clean) data
            y_pred_clean = predict(temp_mach, X)
            clean_score = sqrt(mean((y .- y_pred_clean).^2))

            push!(noise_scores, clean_score)
        end

        push!(noise_robustness, mean(noise_scores))
    end

    results[:noise_robustness] = noise_robustness

    for (i, noise_level) in enumerate(noise_levels)
        println("   Noise $(noise_level*100)%: RMSE = $(round(noise_robustness[i], digits=4))")
    end

    # 4. Extrapolation testing (physics-inspired)
    println("\n4️⃣ Extrapolation Performance")

    # Test on extended ranges for each input variable
    extrapolation_scores = Float64[]

    for feature_idx in 1:size(X, 2)
        feature_range = extrema(X[:, feature_idx])
        range_width = feature_range[2] - feature_range[1]

        # Create test points 20% beyond the training range
        extension = 0.2 * range_width

        # Generate extrapolation test points
        n_extrap_points = 50
        extrap_low = range(feature_range[1] - extension, feature_range[1], length=n_extrap_points÷2)
        extrap_high = range(feature_range[2], feature_range[2] + extension, length=n_extrap_points÷2)

        # Create test dataset (keeping other features at median values)
        X_extrap = repeat(median(X, dims=1), n_extrap_points, 1)
        X_extrap[1:n_extrap_points÷2, feature_idx] .= extrap_low
        X_extrap[n_extrap_points÷2+1:end, feature_idx] .= extrap_high

        # Fit model and make extrapolation predictions
        temp_mach = machine(model, X, y)
        fit!(temp_mach)

        try
            y_pred_extrap = predict(temp_mach, X_extrap)

            # Check for reasonable predictions (not NaN/Inf)
            reasonable_predictions = all(isfinite.(y_pred_extrap))

            if reasonable_predictions
                # Simple heuristic: predictions shouldn't be wildly different from training range
                y_range = extrema(y)
                y_range_width = y_range[2] - y_range[1]

                prediction_range = extrema(y_pred_extrap)
                extrap_score = (prediction_range[2] - prediction_range[1]) / y_range_width

                # Score closer to 1.0 is better (similar range to training)
                push!(extrapolation_scores, min(extrap_score, 10.0))  # Cap at 10x
            else
                push!(extrapolation_scores, Inf)
            end
        catch
            push!(extrapolation_scores, Inf)
        end
    end

    results[:extrapolation_stability] = mean(filter(isfinite, extrapolation_scores))

    if isfinite(results[:extrapolation_stability])
        println("   Extrapolation stability: $(round(results[:extrapolation_stability], digits=2))x training range")
    else
        println("   Extrapolation: Unstable (NaN/Inf predictions)")
    end

    return results
end

# Example usage
validation_results = comprehensive_sr_validation(model, X, y)

# Community-based interpretation guidelines
function interpret_validation_results(results)
    println("\n📊 Validation Summary & Recommendations")

    # Holdout performance
    if results[:holdout_rmse_std] / results[:holdout_rmse_mean] < 0.1
        println("✅ Good holdout consistency (CV < 10%)")
    else
        println("⚠️  High holdout variation - consider more data or regularization")
    end

    # Expression stability
    if results[:expression_consensus] > 0.6
        println("✅ Good expression consensus ($(round(results[:expression_consensus]*100, digits=1))%)")
    elseif results[:expression_consensus] > 0.3
        println("⚠️  Moderate expression consensus - consider ensemble methods")
    else
        println("❌ Poor expression consensus - search may be unreliable")
    end

    # Noise robustness
    noise_degradation = (results[:noise_robustness][end] - results[:noise_robustness][1]) / results[:noise_robustness][1]
    if noise_degradation < 0.5
        println("✅ Good noise robustness ($(round(noise_degradation*100, digits=1))% degradation)")
    else
        println("⚠️  Poor noise robustness - expression may be overfitted")
    end

    # Extrapolation
    if haskey(results, :extrapolation_stability) && isfinite(results[:extrapolation_stability])
        if results[:extrapolation_stability] < 3.0
            println("✅ Reasonable extrapolation behavior")
        else
            println("⚠️  Unstable extrapolation - use with caution outside training range")
        end
    else
        println("❌ Extrapolation produces invalid results")
    end
end

interpret_validation_results(validation_results)
```

### Ensemble Strategies for Robustness

Community experience shows that ensemble methods significantly improve reliability.

#### Multi-Strategy Ensemble Workflow

```julia
# Community-developed ensemble approach
function sr_ensemble_search(X, y; n_strategies=5, final_selection="consensus")

    ensemble_results = []

    println("🎯 Running ensemble symbolic regression...")

    # Strategy 1: Conservative (favors simplicity)
    conservative_model = SRRegressor(
        binary_operators=[+, -, *],
        unary_operators=[],

        niterations=150,
        populations=25,
        population_size=40,

        maxsize=12,
        parsimony=0.02,  # High parsimony
        adaptive_parsimony_scaling=100.0,

        random_state=1001
    )

    # Strategy 2: Aggressive (allows complexity)
    aggressive_model = SRRegressor(
        binary_operators=[+, -, *, /, ^],
        unary_operators=[exp, log, sin, cos, sqrt, abs],

        niterations=200,
        populations=30,
        population_size=50,

        maxsize=30,
        parsimony=0.001,  # Low parsimony
        adaptive_parsimony_scaling=10.0,

        random_state=2002
    )

    # Strategy 3: Physics-inspired (common physics operators)
    physics_model = SRRegressor(
        binary_operators=[+, -, *, /, ^],
        unary_operators=[exp, log, sin, cos, sqrt],

        niterations=175,
        populations=25,
        population_size=45,

        # Physics constraints
        constraints=[
            (^,) => 4,  # Limit high powers
            (exp,) => 3,  # Limit exponential nesting
        ],

        maxsize=20,
        parsimony=0.005,

        random_state=3003
    )

    # Strategy 4: Feature-focused (with feature selection)
    feature_model = SRRegressor(
        binary_operators=[+, -, *, /],
        unary_operators=[exp, log, sqrt],

        select_k_features=min(8, size(X, 2)),
        feature_selection="best",

        niterations=125,
        populations=20,
        population_size=35,

        maxsize=18,
        parsimony=0.008,

        random_state=4004
    )

    # Strategy 5: Regularized (high parsimony, early stopping)
    regularized_model = SRRegressor(
        binary_operators=[+, -, *, /],
        unary_operators=[exp, log],

        niterations=100,
        populations=20,
        population_size=30,

        maxsize=15,
        parsimony=0.05,  # Very high parsimony
        adaptive_parsimony_scaling=200.0,

        # Early stopping
        early_stop_condition="stop_if_loss_less_than_parsimony",

        random_state=5005
    )

    strategies = [
        ("Conservative", conservative_model),
        ("Aggressive", aggressive_model),
        ("Physics-inspired", physics_model),
        ("Feature-focused", feature_model),
        ("Regularized", regularized_model)
    ]

    # Run all strategies
    for (name, model) in strategies
        println("   Running $name strategy...")

        mach = machine(model, X, y)
        fit!(mach)

        r = report(mach)
        push!(ensemble_results, (name=name, report=r, model=model))
    end

    # Analyze ensemble results
    println("\n📊 Ensemble Analysis")

    all_expressions = []
    for result in ensemble_results
        best_eq = result.report.equations[result.report.best_idx]
        push!(all_expressions, (strategy=result.name, expression=string(best_eq),
                               loss=best_eq.loss, complexity=best_eq.complexity))

        println("   $(result.name): Loss=$(round(best_eq.loss, digits=6)), "
                * "Complexity=$(best_eq.complexity), Expr=$(string(best_eq))")
    end

    # Selection strategies
    if final_selection == "best_loss"
        best_result = argmin([expr.loss for expr in all_expressions])
        selected = all_expressions[best_result]
        println("\n🏆 Selected: Best Loss ($(selected.strategy))")

    elseif final_selection == "consensus"
        # Look for expressions that appear in multiple strategies
        expr_counts = Dict{String, Int}()
        for expr in all_expressions
            expr_counts[expr.expression] = get(expr_counts, expr.expression, 0) + 1
        end

        max_consensus = maximum(values(expr_counts))
        if max_consensus > 1
            consensus_expr = first([k for (k, v) in expr_counts if v == max_consensus])
            selected_idx = findfirst(expr -> expr.expression == consensus_expr, all_expressions)
            selected = all_expressions[selected_idx]
            println("\n🏆 Selected: Consensus ($(selected.strategy), appeared $max_consensus times)")
        else
            # Fall back to best complexity-loss tradeoff
            scores = [expr.loss * (1 + 0.01 * expr.complexity) for expr in all_expressions]
            best_idx = argmin(scores)
            selected = all_expressions[best_idx]
            println("\n🏆 Selected: Best Tradeoff ($(selected.strategy))")
        end

    else  # "pareto_optimal"
        # Select based on Pareto front of complexity vs loss
        pareto_indices = []
        for i in 1:length(all_expressions)
            is_dominated = false
            for j in 1:length(all_expressions)
                if i != j
                    # j dominates i if j is better in both loss and complexity
                    if (all_expressions[j].loss <= all_expressions[i].loss &&
                        all_expressions[j].complexity <= all_expressions[i].complexity &&
                        (all_expressions[j].loss < all_expressions[i].loss ||
                         all_expressions[j].complexity < all_expressions[i].complexity))
                        is_dominated = true
                        break
                    end
                end
            end
            if !is_dominated
                push!(pareto_indices, i)
            end
        end

        println("\n🏆 Pareto Optimal Solutions:")
        for idx in pareto_indices
            expr = all_expressions[idx]
            println("   $(expr.strategy): Loss=$(round(expr.loss, digits=6)), " *
                   "Complexity=$(expr.complexity)")
        end

        # Select the simplest among Pareto optimal
        pareto_complexities = [all_expressions[i].complexity for i in pareto_indices]
        simplest_idx = pareto_indices[argmin(pareto_complexities)]
        selected = all_expressions[simplest_idx]
    end

    return ensemble_results, selected
end

# Example usage
ensemble_results, best_ensemble = sr_ensemble_search(X, y, final_selection="consensus")
```

---

## 8. Parameter Tuning and Optimization Workflows

### Community-Tested Parameter Combinations

Based on extensive community feedback, here are parameter combinations that work well for different scenarios.

#### Quick Discovery (< 30 minutes)

```julia
# Community optimized for fast results
quick_model = SRRegressor(
    # Minimal operator set
    binary_operators=[+, -, *],
    unary_operators=[],

    # Fast convergence settings
    niterations=50,
    populations=15,
    population_size=25,
    ncyclesperiteration=200,

    # Aggressive complexity control
    maxsize=10,
    maxdepth=4,
    parsimony=0.01,
    adaptive_parsimony_scaling=50.0,

    # Early stopping
    early_stop_condition="stop_if_no_improvement_for_n_iterations=10",

    # Computational efficiency
    turbo=true,
    fast_cycle=true
)
```

#### Balanced Search (1-3 hours)

```julia
# Community recommended balanced approach
balanced_model = SRRegressor(
    # Standard operator set
    binary_operators=[+, -, *, /],
    unary_operators=[exp, log, sqrt],

    # Community-tested sweet spot
    niterations=100,
    populations=20,
    population_size=33,  # Community found this optimal
    ncyclesperiteration=550,

    # Moderate complexity
    maxsize=20,
    maxdepth=6,

    # Version-stable parameters (community feedback)
    parsimony=0.0032,
    adaptive_parsimony_scaling=20.0,  # v0.24.5 compatible

    # Constraints based on experience
    constraints=[
        (/,) => 5,    # Limit division complexity
        (exp,) => 3,  # Prevent exp(exp(...))
        (log,) => 5   # Allow log chains but limit them
    ],

    # Stability settings
    turbo=true,
    optimizer_nrestarts=2,  # Better constant optimization
    optimizer_iterations=8
)
```

#### Deep Search (6+ hours)

```julia
# Community approach for thorough exploration
deep_model = SRRegressor(
    # Extended operator set
    binary_operators=[+, -, *, /, ^],
    unary_operators=[exp, log, sin, cos, sqrt, abs, tanh],

    # Extended search
    niterations=300,
    populations=30,
    population_size=50,
    ncyclesperiteration=1000,

    # Allow complexity but with strong regularization
    maxsize=35,
    maxdepth=10,

    # Dynamic parsimony (community insight)
    parsimony=0.001,  # Start low
    adaptive_parsimony_scaling=1000.0,  # But scale up quickly

    # Advanced constraints (physics-motivated)
    constraints=[
        (^,) => 6,     # Reasonable powers
        (exp,) => 4,   # Limit exponential depth
        (sin,) => 3,   # Prevent excessive trig nesting
        (cos,) => 3,
        (/,) => 8      # Allow complex fractions
    ],

    # Nested constraints (community best practice)
    nested_constraints=[
        exp => [exp => 0, sin => 2, cos => 2],  # No exp(exp), limit exp(trig)
        sin => [sin => 1, cos => 1],            # Limited trig nesting
        cos => [sin => 1, cos => 1]
    ],

    # Enhanced optimization
    turbo=true,
    optimizer_nrestarts=5,
    optimizer_iterations=20,

    # Migration settings for long runs
    migration=true,
    hof_migration=true,
    migration_fraction=0.05,

    # Deterministic for reproducibility
    deterministic=true,
    random_state=42
)
```

### Systematic Parameter Tuning Workflow

```julia
# Community approach to systematic parameter optimization
function systematic_parameter_tuning(X, y;
                                   tuning_budget_minutes=60,
                                   validation_fraction=0.2)

    println("🔧 Starting systematic parameter tuning...")

    # Split data for tuning
    n_samples = length(y)
    train_size = Int((1 - validation_fraction) * n_samples)

    Random.seed!(42)
    train_idx = sample(1:n_samples, train_size, replace=false)
    val_idx = setdiff(1:n_samples, train_idx)

    X_train, X_val = X[train_idx, :], X[val_idx, :]
    y_train, y_val = y[train_idx], y[val_idx]

    # Parameter grid based on community experience
    parameter_grid = [
        # Quick screening
        Dict(:niterations => 30, :populations => 10, :population_size => 20,
             :parsimony => 0.02, :maxsize => 12),
        Dict(:niterations => 50, :populations => 15, :population_size => 25,
             :parsimony => 0.01, :maxsize => 15),

        # Balanced approaches
        Dict(:niterations => 80, :populations => 20, :population_size => 30,
             :parsimony => 0.005, :maxsize => 18),
        Dict(:niterations => 100, :populations => 25, :population_size => 35,
             :parsimony => 0.003, :maxsize => 22),

        # More intensive (if time permits)
        Dict(:niterations => 150, :populations => 30, :population_size => 40,
             :parsimony => 0.001, :maxsize => 25)
    ]

    results = []
    start_time = time()
    minutes_per_config = tuning_budget_minutes / length(parameter_grid)

    for (i, params) in enumerate(parameter_grid)
        config_start = time()

        println("\n   Config $i/$(length(parameter_grid)): ", params)

        try
            # Create model with current parameters
            model = SRRegressor(
                binary_operators=[+, -, *, /],
                unary_operators=[exp, log, sqrt],

                # Apply grid parameters
                niterations=params[:niterations],
                populations=params[:populations],
                population_size=params[:population_size],
                parsimony=params[:parsimony],
                maxsize=params[:maxsize],

                # Fixed efficiency settings
                turbo=true,
                random_state=i * 1000,

                # Timeout for this configuration
                timeout_in_seconds=Int(minutes_per_config * 60)
            )

            # Fit and evaluate
            mach = machine(model, X_train, y_train)
            fit!(mach)

            # Validation metrics
            y_pred = predict(mach, X_val)
            val_rmse = sqrt(mean((y_val .- y_pred).^2))

            # Model characteristics
            r = report(mach)
            best_eq = r.equations[r.best_idx]

            result = Dict(
                :config => i,
                :params => params,
                :val_rmse => val_rmse,
                :train_loss => best_eq.loss,
                :complexity => best_eq.complexity,
                :expression => string(best_eq),
                :runtime_minutes => (time() - config_start) / 60
            )

            push!(results, result)

            println("      Val RMSE: $(round(val_rmse, digits=6))")
            println("      Complexity: $(best_eq.complexity)")
            println("      Runtime: $(round(result[:runtime_minutes], digits=1)) min")

        catch e
            println("      Failed: $e")
        end

        # Check if we're running out of time
        elapsed_minutes = (time() - start_time) / 60
        if elapsed_minutes > tuning_budget_minutes * 0.9
            println("\n   Stopping early due to time budget")
            break
        end
    end

    # Analyze results
    if !isempty(results)
        println("\n📊 Parameter Tuning Results")

        # Sort by validation performance
        sorted_results = sort(results, by=r -> r[:val_rmse])

        println("\n🏆 Top 3 Configurations:")
        for (i, result) in enumerate(sorted_results[1:min(3, length(sorted_results))])
            println("\n   Rank $i:")
            println("     Parameters: ", result[:params])
            println("     Val RMSE: $(round(result[:val_rmse], digits=6))")
            println("     Complexity: $(result[:complexity])")
            println("     Runtime: $(round(result[:runtime_minutes], digits=1)) min")
            println("     Expression: $(result[:expression])")
        end

        return sorted_results[1][:params]  # Return best parameters
    else
        println("❌ No successful configurations")
        return nothing
    end
end

# Usage example
best_params = systematic_parameter_tuning(X, y, tuning_budget_minutes=120)

if best_params !== nothing
    # Use optimized parameters for final model
    optimized_model = SRRegressor(
        binary_operators=[+, -, *, /],
        unary_operators=[exp, log, sqrt],

        # Apply tuned parameters
        niterations=best_params[:niterations],
        populations=best_params[:populations],
        population_size=best_params[:population_size],
        parsimony=best_params[:parsimony],
        maxsize=best_params[:maxsize],

        # Enhanced settings for final run
        turbo=true,
        optimizer_nrestarts=3,
        deterministic=true,
        random_state=12345
    )

    final_mach = machine(optimized_model, X, y)
    fit!(final_mach)

    println("\n🎯 Final optimized model trained successfully!")
end
```

---

## 9. Domain-Specific Advanced Workflows

### Time Series and Dynamical Systems

Community patterns for temporal data and dynamical systems discovery.

#### Time Series Feature Engineering Workflow

```julia
# Community approach for time series symbolic regression
using DSP: conv  # For sliding window operations

function prepare_timeseries_features(y_timeseries;
                                   max_lags=5,
                                   include_derivatives=true,
                                   include_integrals=true,
                                   dt=1.0)

    n = length(y_timeseries)
    features = []
    feature_names = String[]

    # Lagged values (community standard)
    for lag in 1:max_lags
        if lag < n
            lagged = vcat(fill(y_timeseries[1], lag), y_timeseries[1:(end-lag)])
            push!(features, lagged)
            push!(feature_names, "y_lag_$lag")
        end
    end

    # Derivatives (finite differences)
    if include_derivatives && n > 1
        # First derivative
        dy_dt = vcat(0.0, diff(y_timeseries) ./ dt)
        push!(features, dy_dt)
        push!(feature_names, "dy_dt")

        # Second derivative (if enough points)
        if n > 2
            d2y_dt2 = vcat([0.0, 0.0], diff(diff(y_timeseries)) ./ dt^2)
            push!(features, d2y_dt2)
            push!(feature_names, "d2y_dt2")
        end
    end

    # Integrals (cumulative sums)
    if include_integrals
        integral_y = cumsum(y_timeseries) .* dt
        push!(features, integral_y)
        push!(feature_names, "integral_y")
    end

    # Moving averages (community insight)
    for window in [3, 5]
        if window < n
            # Simple moving average
            ma = copy(y_timeseries)
            for i in window:n
                ma[i] = mean(y_timeseries[(i-window+1):i])
            end
            push!(features, ma)
            push!(feature_names, "ma_$window")
        end
    end

    # Combine all features
    X_features = hcat(features...)

    return X_features, feature_names
end

# Dynamical system discovery workflow
function discover_dynamical_system(y_timeseries, t;
                                 max_lags=3,
                                 physics_informed=true)

    println("🔄 Discovering dynamical system from time series...")

    # Prepare features
    X_features, feature_names = prepare_timeseries_features(
        y_timeseries,
        max_lags=max_lags,
        dt=length(t) > 1 ? t[2] - t[1] : 1.0
    )

    # Target is the next time step (prediction)
    y_target = vcat(y_timeseries[2:end], y_timeseries[end])

    # Physics-informed operators
    if physics_informed
        binary_ops = [+, -, *, /]
        unary_ops = [exp, log, sin, cos, sqrt, abs]

        # Physics constraints
        constraints_dict = [
            (exp,) => 3,  # Exponential growth common in dynamics
            (sin,) => 2,  # Oscillatory behavior
            (cos,) => 2,
            (/,) => 4     # Rational functions in dynamics
        ]
    else
        binary_ops = [+, -, *]
        unary_ops = []
        constraints_dict = []
    end

    # Dynamical systems model
    dynamics_model = SRRegressor(
        binary_operators=binary_ops,
        unary_operators=unary_ops,

        # Search parameters tuned for dynamics
        niterations=150,
        populations=25,
        population_size=40,

        # Favor interpretable dynamics
        maxsize=20,
        parsimony=0.008,
        adaptive_parsimony_scaling=100.0,

        # Physics constraints
        constraints=constraints_dict,

        # Stability for dynamics
        turbo=true,
        optimizer_nrestarts=3,
        deterministic=true,
        random_state=2024
    )

    # Fit the model
    println("   Fitting dynamical model...")
    mach = machine(dynamics_model, X_features, y_target)
    fit!(mach)

    # Analyze results
    r = report(mach)
    best_eq = r.equations[r.best_idx]

    println("\n📈 Discovered Dynamical Equation:")
    println("   $(string(best_eq))")
    println("   Features: ", feature_names)
    println("   Loss: $(round(best_eq.loss, digits=6))")
    println("   Complexity: $(best_eq.complexity)")

    # Validate with simulation
    println("\n🔍 Validating with forward simulation...")

    # Simulate using discovered equation
    y_sim = simulate_discovered_dynamics(best_eq, y_timeseries[1:max_lags],
                                       length(y_timeseries) - max_lags,
                                       feature_names, r)

    # Compare with original
    simulation_error = sqrt(mean((y_timeseries[(max_lags+1):end] .- y_sim).^2))
    println("   Simulation RMSE: $(round(simulation_error, digits=6))")

    return mach, feature_names, y_sim
end

# Helper function for simulation
function simulate_discovered_dynamics(equation, initial_conditions, n_steps, feature_names, report)
    # This would need to be implemented based on the specific equation structure
    # For now, return a placeholder
    println("   (Simulation implementation depends on discovered equation structure)")
    return zeros(n_steps)  # Placeholder
end

# Example usage
t = 0:0.1:10
y_ts = sin.(2π * 0.3 * t) .+ 0.1 * randn(length(t))  # Noisy sine wave

dynamics_mach, features, y_sim = discover_dynamical_system(y_ts, t)
```

### Economics and Social Sciences Workflow

```julia
# Community patterns for economics/social science data
function economics_sr_workflow(X, y;
                             include_interaction_terms=true,
                             log_transform_skewed=true,
                             handle_heteroscedasticity=true)

    println("💰 Economics-focused symbolic regression workflow...")

    # Step 1: Data preprocessing (economics-specific)
    X_processed = copy(X)
    y_processed = copy(y)
    feature_transformations = []

    # Log transformation for heavily skewed variables (common in economics)
    if log_transform_skewed
        for col in 1:size(X, 2)
            feature = X[:, col]
            if all(feature .> 0)  # Only positive values
                skewness_val = skewness(feature)
                if abs(skewness_val) > 2.0  # Highly skewed
                    X_processed[:, col] = log.(feature)
                    push!(feature_transformations, "log(x$col)")
                else
                    push!(feature_transformations, "x$col")
                end
            else
                push!(feature_transformations, "x$col")
            end
        end
    end

    # Interaction terms (common in economics)
    if include_interaction_terms && size(X, 2) <= 10  # Avoid explosion
        interactions = []
        interaction_names = []

        for i in 1:size(X_processed, 2)
            for j in (i+1):size(X_processed, 2)
                interaction = X_processed[:, i] .* X_processed[:, j]
                push!(interactions, interaction)
                push!(interaction_names, "$(feature_transformations[i]) * $(feature_transformations[j])")
            end
        end

        if !isempty(interactions)
            X_extended = hcat(X_processed, hcat(interactions...))
            extended_names = vcat(feature_transformations, interaction_names)
        else
            X_extended = X_processed
            extended_names = feature_transformations
        end
    else
        X_extended = X_processed
        extended_names = feature_transformations
    end

    # Step 2: Economics-appropriate operators
    econ_model = SRRegressor(
        # Economics functions
        binary_operators=[+, -, *, /],
        unary_operators=[log, sqrt, exp],  # Common in utility functions, growth models

        # Economics-motivated constraints
        constraints=[
            (log,) => 3,    # Log utility, log production functions
            (exp,) => 2,    # Exponential growth (but limited)
            (/,) => 6,      # Ratios common in economics
            (sqrt,) => 2    # Square root utility functions
        ],

        # Moderate search (economics models often parsimonious)
        niterations=120,
        populations=20,
        population_size=35,

        # Favor simpler models (interpretability crucial in economics)
        maxsize=18,
        parsimony=0.01,
        adaptive_parsimony_scaling=80.0,

        # Robust optimization
        turbo=true,
        optimizer_nrestarts=3
    )

    # Step 3: Heteroscedasticity-robust fitting
    if handle_heteroscedasticity
        # Custom loss function for heteroscedasticity
        robust_loss = """
        function robust_loss(tree, dataset::Dataset{T,L}, options) where {T,L}
            prediction, completed = eval_tree_array(tree, dataset.X, options)
            if !completed
                return L(Inf)
            end

            residuals = prediction .- dataset.y

            # Weighted by inverse of predicted variance (heteroscedasticity adjustment)
            weights = 1.0 ./ (0.1 .+ abs.(prediction))  # Avoid division by zero

            weighted_sse = sum(weights .* residuals.^2)
            return L(weighted_sse / length(prediction))
        end
        """

        econ_model = SRRegressor(
            econ_model.binary_operators, econ_model.unary_operators,
            niterations=econ_model.niterations,
            populations=econ_model.populations,
            population_size=econ_model.population_size,
            maxsize=econ_model.maxsize,
            parsimony=econ_model.parsimony,
            adaptive_parsimony_scaling=econ_model.adaptive_parsimony_scaling,
            constraints=econ_model.constraints,
            turbo=econ_model.turbo,
            optimizer_nrestarts=econ_model.optimizer_nrestarts,

            # Add robust loss
            loss_function=robust_loss
        )
    end

    # Step 4: Fit model
    println("   Fitting economics model...")
    mach = machine(econ_model, X_extended, y_processed)
    fit!(mach)

    # Step 5: Economics-specific interpretation
    r = report(mach)
    best_eq = r.equations[r.best_idx]

    println("\n📊 Economics Model Results:")
    println("   Equation: $(string(best_eq))")
    println("   Feature mapping: ", extended_names)
    println("   Loss: $(round(best_eq.loss, digits=6))")
    println("   Complexity: $(best_eq.complexity)")

    # Elasticity analysis (common in economics)
    println("\n📈 Economic Insights:")

    # Simple elasticity approximation for interpretable models
    if best_eq.complexity < 15
        println("   Model complexity suitable for elasticity analysis")
        # This would require more sophisticated analysis in practice
    else
        println("   Model may be too complex for direct economic interpretation")
    end

    return mach, extended_names
end

# Example usage
# X_econ = economic_data_features  # e.g., income, price, education, etc.
# y_econ = economic_outcome        # e.g., consumption, demand, etc.
# econ_mach, econ_features = economics_sr_workflow(X_econ, y_econ)
```

---

## 10. Troubleshooting and Recovery Workflows

### Systematic Diagnostic and Recovery Patterns

Community-developed approaches for diagnosing and fixing common problems.

#### When Search Stagnates (Community Solution)

```julia
# Community pattern for when search gets stuck
function diagnose_stagnation(model, X, y; min_improvement_threshold=1e-6)

    println("🔧 Diagnosing search stagnation...")

    # Run a diagnostic search to understand the problem
    diagnostic_model = SRRegressor(
        model.binary_operators, model.unary_operators,

        # Shorter run for diagnosis
        niterations=20,
        populations=10,
        population_size=20,

        # Same complexity constraints
        maxsize=model.maxsize,
        parsimony=model.parsimony,

        # Enable detailed logging
        verbosity=1,

        # Fresh random seed
        random_state=rand(1:10000)
    )

    mach = machine(diagnostic_model, X, y)
    fit!(mach)

    r = report(mach)

    # Analyze the results
    issues = String[]
    solutions = String[]

    # Check 1: Are any reasonable expressions found?
    if length(r.equations) < 5
        push!(issues, "Very few expressions discovered")
        push!(solutions, "Try: Increase niterations, reduce maxsize, simplify operators")
    end

    # Check 2: Loss improvement pattern
    losses = [eq.loss for eq in r.equations]
    if length(losses) > 1
        min_loss, max_loss = extrema(losses)
        loss_range = max_loss - min_loss

        if loss_range < min_improvement_threshold
            push!(issues, "Minimal loss variation across complexity levels")
            push!(solutions, "Try: Increase populations, change parsimony, add/remove operators")
        end
    end

    # Check 3: Complexity distribution
    complexities = [eq.complexity for eq in r.equations]
    unique_complexities = length(unique(complexities))

    if unique_complexities < 3
        push!(issues, "Poor exploration of complexity space")
        push!(solutions, "Try: Adjust adaptive_parsimony_scaling, modify maxsize")
    end

    # Check 4: Expression diversity
    expressions = [string(eq) for eq in r.equations]
    unique_expressions = length(unique(expressions))

    if unique_expressions < length(expressions) * 0.7
        push!(issues, "Low expression diversity (many duplicates)")
        push!(solutions, "Try: Increase populations, add mutation types, change temperature")
    end

    # Print diagnosis
    println("\n🔍 Diagnostic Results:")
    if isempty(issues)
        println("   ✅ No obvious issues detected")
        println("   Consider: Longer search time, ensemble methods")
    else
        for (issue, solution) in zip(issues, solutions)
            println("   ❌ Issue: $issue")
            println("      💡 $solution")
        end
    end

    return issues, solutions
end

# Recovery strategies based on diagnosis
function apply_recovery_strategy(original_model, X, y, issues)

    println("\n🚀 Applying recovery strategies...")

    recovery_models = []

    # Strategy 1: Simplification approach
    if "Very few expressions discovered" in issues ||
       "Poor exploration of complexity space" in issues

        simple_model = SRRegressor(
            # Reduce operator complexity
            binary_operators=[+, -, *],
            unary_operators=[],

            # Increase search intensity
            niterations=original_model.niterations * 2,
            populations=original_model.populations,
            population_size=original_model.population_size,

            # Lower complexity ceiling
            maxsize=max(8, original_model.maxsize ÷ 2),

            # Reduced parsimony
            parsimony=original_model.parsimony * 0.1,
            adaptive_parsimony_scaling=20.0,

            turbo=true
        )

        push!(recovery_models, ("Simplification", simple_model))
    end

    # Strategy 2: Diversification approach
    if "Low expression diversity" in issues ||
       "Minimal loss variation across complexity levels" in issues

        diverse_model = SRRegressor(
            original_model.binary_operators, original_model.unary_operators,

            # Increase population diversity
            niterations=original_model.niterations,
            populations=original_model.populations * 2,
            population_size=original_model.population_size,

            # Encourage exploration
            parsimony=0.0,  # No parsimony initially
            adaptive_parsimony_scaling=200.0,  # But scale up quickly

            # Different selection pressure
            tournament_selection_n=8,  # Larger tournaments

            # Enhanced mutation
            perturbation_factor=0.2,  # Higher mutation rates

            maxsize=original_model.maxsize,
            turbo=true
        )

        push!(recovery_models, ("Diversification", diverse_model))
    end

    # Strategy 3: Staged complexity approach
    staged_model = SRRegressor(
        original_model.binary_operators, original_model.unary_operators,

        # Moderate settings
        niterations=original_model.niterations,
        populations=original_model.populations,
        population_size=original_model.population_size,

        # Start with moderate complexity
        maxsize=min(15, original_model.maxsize),

        # Dynamic parsimony
        parsimony=0.01,
        adaptive_parsimony_scaling=100.0,

        turbo=true,
        deterministic=false  # Allow randomness
    )

    push!(recovery_models, ("Staged", staged_model))

    # Run recovery strategies
    recovery_results = []

    for (name, model) in recovery_models
        println("\n   Trying $name recovery...")

        try
            mach = machine(model, X, y)
            fit!(mach)

            r = report(mach)
            best_eq = r.equations[r.best_idx]

            result = (
                strategy=name,
                loss=best_eq.loss,
                complexity=best_eq.complexity,
                expression=string(best_eq),
                n_equations=length(r.equations)
            )

            push!(recovery_results, result)

            println("      ✅ Success: Loss=$(round(best_eq.loss, digits=6)), " *
                   "Complexity=$(best_eq.complexity), Found=$(length(r.equations)) equations")

        catch e
            println("      ❌ Failed: $e")
        end
    end

    # Select best recovery result
    if !isempty(recovery_results)
        best_recovery = argmin([r.loss for r in recovery_results])
        winner = recovery_results[best_recovery]

        println("\n🏆 Best Recovery Strategy: $(winner.strategy)")
        println("   Expression: $(winner.expression)")

        return winner.strategy, recovery_models[best_recovery][2]
    else
        println("\n❌ All recovery strategies failed")
        return nothing, nothing
    end
end

# Complete stagnation recovery workflow
function recover_from_stagnation(model, X, y)

    # Step 1: Diagnose the problem
    issues, solutions = diagnose_stagnation(model, X, y)

    # Step 2: Apply recovery strategies
    if !isempty(issues)
        best_strategy, recovery_model = apply_recovery_strategy(model, X, y, issues)

        if recovery_model !== nothing
            # Step 3: Run recovered model for full search
            println("\n🔄 Running full search with recovered model...")

            final_mach = machine(recovery_model, X, y)
            fit!(final_mach)

            return final_mach, best_strategy
        end
    end

    return nothing, nothing
end

# Example usage:
# recovered_mach, strategy = recover_from_stagnation(stuck_model, X, y)
```

#### Version Compatibility and Migration Patterns

```julia
# Community solution for version compatibility issues
function migrate_to_current_version(old_options_dict)

    println("🔄 Migrating parameters to current version...")

    # Map old parameter names to new ones (community knowledge)
    parameter_mapping = Dict(
        # Common renames
        "npopulations" => "populations",
        "npop" => "populations",
        "hofMigration" => "hof_migration",
        "shouldOptimizeConstants" => "optimize_constants",
        "optimizer_options" => "optimizer_params",

        # Value changes
        "adaptive_parsimony_scaling" => function(old_val)
            # Version 0.24.5 -> 1.0 scaling change
            if old_val == 20.0
                return 20.0  # Keep v0.24.5 behavior
            else
                return old_val
            end
        end
    )

    # Default value migrations
    version_defaults = Dict(
        # Restore v0.24.5 behavior (community preference)
        "adaptive_parsimony_scaling" => 20.0,
        "parsimony" => 0.0032,
        "population_size" => 33,
        "ncyclesperiteration" => 550
    )

    migrated_options = copy(old_options_dict)

    # Apply parameter name mapping
    for (old_name, new_name_or_func) in parameter_mapping
        if haskey(migrated_options, old_name)
            old_value = migrated_options[old_name]
            delete!(migrated_options, old_name)

            if isa(new_name_or_func, Function)
                migrated_options[old_name] = new_name_or_func(old_value)
            else
                migrated_options[new_name_or_func] = old_value
            end
        end
    end

    # Apply version-specific defaults
    for (param, default_value) in version_defaults
        if !haskey(migrated_options, param)
            migrated_options[param] = default_value
            println("   Added v0.24.5 compatible default: $param = $default_value")
        end
    end

    # Create migrated model
    migrated_model = SRRegressor(; migrated_options...)

    println("✅ Migration completed")

    return migrated_model
end

# Example usage:
# old_params = Dict("npopulations" => 20, "npop" => 15, "adaptive_parsimony_scaling" => 1040)
# new_model = migrate_to_current_version(old_params)
```

---

## Summary

These workflows provide a comprehensive guide for using SymbolicRegression.jl effectively across different domains and scales. Key takeaways:

1. **Start Simple**: Begin with conservative parameters and simple operators, then increase complexity as needed.

2. **Validate Thoroughly**: Always use cross-validation and stability testing before deploying models.

3. **Domain Knowledge**: Incorporate domain-specific constraints and operator choices for better results.

4. **Iterative Refinement**: Use diagnostic tools to systematically improve performance.

5. **Production Ready**: Plan for model persistence, version management, and production deployment from the start.

6. **Community Wisdom**: Leverage community-tested parameter combinations and troubleshooting patterns.

7. **Scale Appropriately**: Use specialized workflows for large datasets, high-dimensional data, and domain-specific requirements.

8. **Robust Validation**: Employ comprehensive validation strategies including stability analysis, noise robustness, and extrapolation testing.

9. **Systematic Tuning**: Use systematic approaches to parameter optimization and ensemble methods for improved reliability.

10. **Recovery Strategies**: Have diagnostic and recovery workflows ready for when standard approaches fail.

For additional examples and advanced techniques, see the [Examples](examples.md) and [Customization](customization.md) sections of the documentation.
