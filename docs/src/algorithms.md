# Advanced Algorithmic Details

This document provides deep technical details about the algorithms implemented in SymbolicRegression.jl. It is intended for advanced users who want to understand the algorithmic foundations and make informed decisions about parameters and customizations.

## Overview: Multi-Population Evolutionary Algorithm

SymbolicRegression.jl implements a sophisticated multi-population evolutionary algorithm that goes beyond standard genetic programming. The system replaces traditional fitness-based selection with **age-regularized evolution**, which prevents premature convergence by always replacing the oldest population members rather than the worst-performing ones. **Adaptive parsimony** adjusts complexity penalties based on population composition, while an **evolve-simplify-optimize loop** integrates constant optimization with expression discovery. The **multi-population architecture** enables parallel exploration of different solution regions, coordinated through migration strategies and **temperature scheduling** that balances exploration and exploitation over time.

## High-Level Algorithm Structure

### Multi-Population Coordination

The algorithm runs multiple populations (configurable, default: 31) that evolve independently. Each population contains a configurable number of members (default: 27) that represent candidate mathematical expressions.

**Population initialization pseudocode:**

```julia
for output ∈ outputs
    for population ∈ populations
        population ← create_new_population(
            size=population_size,
            initial_complexity=3,
            features=dataset_features
        )
    end
end
```

**Main evolution loop:**

```julia
while cycles_remaining > 0
    next_population ← select_round_robin(populations)

    if is_population_ready(next_population)
        process_completed_population(next_population)
        update_hall_of_fame(best_expressions)
        perform_migration(populations)
        dispatch_evolution_cycle(next_population)
    end

    cycles_remaining ← cycles_remaining - 1
end
```

### Key Design Principles

The system uses asynchronous execution so populations evolve independently without blocking, enabling efficient load balancing across available processors. Multiple populations preserve diversity by exploring different regions of the solution space simultaneously.

## Age-Regularized Evolution

### Core Mechanism

Traditional genetic programming replaces the worst-performing members. This algorithm instead always replaces the **oldest** member in the population, regardless of fitness.

**Age-based replacement pseudocode:**

```julia
// For mutation
oldest_member ← find_oldest_in_population(population)
replace_member(population, oldest_member, new_mutated_expression)

// For crossover
oldest_member_1 ← find_oldest_in_population(population)
oldest_member_2 ← find_second_oldest_in_population(population)
replace_member(population, oldest_member_1, child_1)
replace_member(population, oldest_member_2, child_2)
```

### Why Age-Based Replacement Works

- **Prevents premature convergence**: Avoids getting stuck in local optima
- **Maintains diversity**: Ensures new ideas get time to develop
- **Balances exploration/exploitation**: Selection pressure comes from tournament selection, not replacement

Each expression tracks its "birth time" when created, enabling precise age comparison.

## Tournament Selection with Adaptive Parsimony

### Tournament Mechanics

Selection uses tournaments rather than pure fitness ranking. A tournament samples a subset of the population (configurable, default: 15 members) and selects using a geometric distribution with parameter p (configurable, default: 0.982).

**Tournament selection pseudocode:**

**Tournament selection process:**

1. **Sample** tournament_selection_n members randomly from population
2. **Adjust costs** for each member: `adjusted_cost = base_cost × exp(adaptive_parsimony_scaling × frequency)`
3. **Rank** members by adjusted cost (lowest = rank 1, next lowest = rank 2, etc.)
4. **Select rank** using geometric weights: rank k gets weight `p × (1-p)^(k-1)`
5. **Return** the member at the selected rank

The geometric weighting means rank 1 has the highest selection weight, rank 2 has weight `p(1-p)`, rank 3 has weight `p(1-p)²`, and so on. Higher values of p increase selection pressure toward the best member.

### Adaptive Parsimony Integration

The key innovation is **frequency-based complexity penalties** that adapt based on population composition:

**Adaptive cost calculation:**

```julia
for member ∈ tournament
    base_cost ← member.cost
    complexity ← count_nodes(member.expression)
    frequency ← normalized_frequency[complexity]  // in population

    // Apply exponential penalty for overrepresented complexities
    adjusted_cost ← base_cost × exp(parsimony_scaling × frequency)
end
```

**Mathematical effect**: If 100% of population has the same complexity, the penalty factor is approximately `exp(1040×1) ≈ 10⁴⁵²`, providing extremely strong pressure against homogenization.

This prevents the population from converging to a single complexity level and encourages exploration across the complexity spectrum.

## Mutation System

### Mutation Type Portfolio

The algorithm uses 14 distinct mutation types, each serving a specific purpose:

**Expression modification mutations:**

- `mutate_constant`: Adjust numerical values (e.g., `2.1` → `2.3`), with `probability_negate_constant` (default: 0.00743) chance of sign flip
- `mutate_operator`: Change operators (e.g., `+` → `*`)
- `mutate_feature`: Change input variables (e.g., `x₁` → `x₂`)

**Structural mutations:**

- `add_node`: Add new operation by either appending to a leaf or prepending to the root (e.g., `x` → `sin(x)` or `x` → `x+c`)
- `insert_node`: Add operation with random branch (e.g., `x+y` → `x+y*z`)
- `delete_node`: Remove operation (e.g., `sin(x+y)` → `x+y`)
- `swap_operands`: Reorder arguments (e.g., `x-y` → `y-x`)

**Tree-level mutations:**

- `simplify`: Apply algebraic rules using DynamicExpressions.jl's built-in simplification methods (e.g., `sin(3.0)` → `0.141...`)
- `optimize`: Tune constants using gradient methods
- `randomize`: Replace with completely random expression
- `rotate_tree`: Restructure expression tree
- `do_nothing`: Identity operation (maintains diversity)

**Graph-specific mutations** (for `GraphNode` expressions; experimental interface):

- `form_connection`: Add edge between nodes
- `break_connection`: Remove edge between nodes

### Dynamic Weight Conditioning

Mutation weights are dynamically adjusted based on expression properties:

**Weight conditioning pseudocode:**

```julia
function condition_weights(expression, current_weights)
    adjusted_weights ← copy(current_weights)

    if is_leaf_node(expression)
        disable_weights(adjusted_weights, [mutate_operator, swap_operands, delete_node])
    end

    if complexity(expression) >= max_allowed_size
        disable_weights(adjusted_weights, [add_node, insert_node])
    end

    if num_features(dataset) <= 1
        disable_weights(adjusted_weights, [mutate_feature])
    end

    return adjusted_weights
end
```

This ensures all mutations are valid and appropriate for the current expression state. Conditioning includes simple rules such as: disabling `mutate_feature` when there is only one feature in the dataset, turning off `swap_operands` when all the operators are unary, and propagating `should_simplify`.

### Default Mutation Weights

The algorithm uses the following default relative weights for mutation operations (effective defaults when constructing `Options()`; weights are used proportionally and may be conditioned at runtime):

- `mutate_constant`: 0.0353
- `mutate_operator`: 3.63 (highest weight - most common mutation)
- `mutate_feature`: 0.1
- `swap_operands`: 0.00608
- `rotate_tree`: 1.42
- `add_node`: 0.0771
- `insert_node`: 2.44 (second highest weight)
- `delete_node`: 0.369
- `simplify`: 0.00148
- `randomize`: 0.00695
- `do_nothing`: 0.431
- `optimize`: 0.0 (disabled by default)

These weights were optimized using a simple dataset of synthetic expressions, but users should consider optimizing them for a particular problem.

## Simulated Annealing Integration

### Temperature Scheduling

The algorithm uses temperature to control the exploration-exploitation balance. Temperature decreases linearly over each evolution cycle (configurable duration, default: 380 cycles).

**Temperature schedule:**

```julia
max_temperature ← 1.0
min_temperature ← 0.0  // configurable: can disable annealing
temperatures ← linear_schedule(max_temp, min_temp, num_cycles)
```

### Mutation Acceptance

Mutations are accepted probabilistically based on their impact on the equation score (cost):

**Acceptance probability**: `P(accept) = exp(-(cost_new - cost_old)/(α × T))`

Where:

- `α` = annealing scale (configurable, default: 3.17)
- `T` = current temperature ∈ [0,1]
- `cost_new`, `cost_old` = costs before/after mutation (includes loss normalization and any fixed parsimony term)

If adaptive parsimony is enabled (`use_frequency = true`, default), the acceptance probability is additionally scaled by the ratio of frequencies of the old vs new complexities:

`P(accept) ← P(accept) × (freq_old / freq_new)`

This discourages transitions into overrepresented complexity levels and encourages movement toward underexplored sizes.

**Behavioral phases:**

- **High temperature**: Accept many mutations, even harmful ones (exploration)
- **Low temperature**: Only accept improving mutations (exploitation)

## Evolve-Simplify-Optimize Loop

### Three-Stage Process

Each population evolution cycle consists of three distinct stages:

**Stage 1: Evolution with annealing**

```julia
for temperature ∈ temperature_schedule
    apply_mutations_and_crossovers(population)
    accept_reject_changes(population, temperature)
    track_best_expressions(population)
end
```

**Stage 2: Simplification**

```julia
for expression ∈ population
    simplified_expression ← simplify_tree!(expression)
    combined_expression ← combine_operators(simplified_expression)
    update_member(population, expression, combined_expression)
end
```

**Stage 3: Constant optimization**

```julia
for member ∈ population
    if random() < optimizer_probability
        optimized_expression ← optimize_constants_with_restarts(member.expression)
        update_member(population, member, optimized_expression)
    end
end
```

### Rationale for Separation

1. **Evolution generates diversity**: Mutations create varied expressions, some temporarily redundant
2. **Simplification cleans structure**: Removes redundancy while preserving function
3. **Optimization fine-tunes accuracy**: Adjusts constants for optimal fit

This separation allows beneficial mutations that create temporary redundancy while ensuring final expressions are clean and optimal.

## Migration Strategies

### Inter-Population Communication

Populations periodically share their best discoveries through migration:

**Migration types:**

1. **Population-to-population migration** (configurable rate, default: 0.036%):
   - Source: Best members from other populations (configurable count, default: 12)
   - Target: Random positions in current population
   - Effect: Spreads good discoveries across populations

2. **Hall of Fame migration** (configurable rate, default: 6.14%):
   - Source: Pareto frontier (best at each complexity level)
   - Target: Random positions in current population
   - Effect: Injects globally best solutions

3. **Seed expression migration** (if provided, rate: 0.1%):
   - Source: User-provided initial guesses
   - Target: Random positions in current population
   - Effect: Incorporates domain knowledge

**Migration pseudocode:**

```julia
function migrate(source_population, target_population, migration_rate)
    num_migrants ← poisson_sample(population_size × migration_rate)
    migrant_positions ← random_sample(1:population_size, num_migrants)
    migrants ← select_best(source_population, num_migrants)

    for (position, migrant) ∈ zip(migrant_positions, migrants)
        target_population[position] ← copy(migrant)
        reset_birth_time(target_population[position])
    end
end
```

Migration uses Poisson sampling for natural stochasticity in migration intensity.

## Hall of Fame and Pareto Management

### Pareto Frontier Calculation

The Hall of Fame maintains the best expression found at each complexity level, forming a Pareto frontier.

**Domination rules:**

```julia
function is_dominating(candidate, hall_of_fame)
    candidate_complexity ← count_nodes(candidate.expression)
    candidate_error ← candidate.prediction_error

    for complexity = 1:(candidate_complexity-1)
        if exists(hall_of_fame[complexity])
            simpler_member ← hall_of_fame[complexity]
            if candidate_error >= simpler_member.error
                return false  // Candidate doesn't improve on simpler expression
            end
        end
    end

    return true  // Candidate dominates all simpler expressions
end
```

### Pareto Frontier Properties

- **Monotonic accuracy**: Higher complexity expressions must have lower error
- **Unique representatives**: At most one expression per complexity level
- **Trade-off visualization**: Shows accuracy vs complexity choices
- **Persistent memory**: Best discoveries are never lost

## Parallelization Architecture

### Parallel Execution Modes

The algorithm supports three parallelization strategies (configurable):

1. **Serial**: Single-threaded for debugging and development
2. **Multithreading**: Shared memory parallelism using Julia threads
3. **Multiprocessing**: Distributed memory parallelism across processes

### Asynchronous Population Management

**Key design principle**: Populations evolve asynchronously without blocking the main coordination thread.

**Asynchronous dispatch pseudocode:**

```julia
function dispatch_evolution(population, dataset)
    # Send population to available worker
    worker_task ← spawn_on_worker(evolve_population, population, dataset)

    # Set up asynchronous communication
    result_channel ← create_async_channel()
    setup_result_handler(worker_task, result_channel)

    return worker_task, result_channel
end
```

**Benefits:**

- **Load balancing**: Faster workers process more populations
- **Fault tolerance**: Failed workers don't block the search
- **Scalability**: Efficient use of hundreds to thousands of cores

## Constant Optimization Details

### Multi-Restart Gradient Optimization

Constants in expressions are optimized using gradient-based methods with multiple random restarts for robustness.

**Optimization algorithm selection:**

- **Single constant**: Newton's method with line search
- **Multiple constants**: BFGS with gradient computation (configurable)
- **Complex numbers**: Specialized algorithms for complex optimization

**Multi-restart procedure:**

```julia
function optimize_constants(expression, dataset, num_restarts)
    best_result ← current_expression

    for restart = 1:num_restarts
        # Try a new random initialization for the constants
        perturbed_constants ← constants × (1 + 0.5 × randn_like(constants))

        # Optimize using gradient methods
        result ← gradient_optimize(expression, perturbed_constants, dataset)

        if result.error < best_result.error
            best_result ← result
        end
    end

    return best_result
end
```

### Automatic Differentiation Integration

Constants are optimized with classical optimizers and automatic differentiation:

- **Backend**: Uses DifferentiationInterface/ADTypes; can leverage Enzyme.jl when selected
- **Fallback**: If no AD backend is set, Optim.jl uses gradient-free/finite-difference paths (Newton for single-constant, BFGS otherwise)
- **Target**: Minimize the predictive loss on the dataset (cost is derived from the loss)

## Algorithm Parameters and Tuning

### Population Dynamics (all configurable)

- `populations`: Number of independent populations (default: 31)
  - More populations → better exploration, higher compute cost
- `population_size`: Members per population (default: 27)
  - Larger populations → better diversity, slower convergence
- `tournament_selection_n`: Tournament size (default: 15)
  - Larger tournaments → stronger selection pressure
- `tournament_selection_p`: Selection probability (default: 0.982)
  - Higher probability → more exploitation vs exploration

### Evolution Control (all configurable)

- `ncycles_per_iteration`: Evolution cycles per iteration (default: 380)
  - More cycles → more thorough search per iteration
- `crossover_probability`: Rate of crossover vs mutation (default: 0.0259)
  - Higher values → more recombination between expressions
- `annealing`: Enable temperature scheduling (default: true)
  - Controls exploration-exploitation balance over time

### Complexity Management (all configurable)

- `adaptive_parsimony_scaling`: Strength of complexity penalties (default: 1040)
  - Higher values → stronger pressure against overrepresented complexities
- `use_frequency_in_tournament`: Enable adaptive parsimony (default: true)
  - Controls whether complexity penalties adapt to population composition

### Migration Control (all configurable)

- `fraction_replaced`: Population migration rate (default: 0.00036)
- `fraction_replaced_hof`: Hall of Fame migration rate (default: 0.0614)
- `topn`: Number of best members available for migration (default: 12)

### Optimization Settings (all configurable)

- `optimizer_probability`: Fraction of expressions to optimize per iteration (default: 0.14)
- `optimizer_nrestarts`: Random restarts for constant optimization (default: 2)
  - More restarts → more robust optimization, higher compute cost

## Understanding Algorithm Behavior

### Performance Characteristics

**Expression evaluation**: The dominant computational cost, scales with dataset size and expression complexity

**Selection and mutation**: Relatively fast operations, scale with population size

**Constant optimization**: Moderate cost, depends on number of constants and optimization accuracy requirements

**Migration**: Minimal overhead, happens infrequently
