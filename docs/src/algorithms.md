# Advanced Algorithmic Details

This document provides deep technical details about the algorithms implemented in SymbolicRegression.jl. It is intended for advanced users who want to understand the algorithmic foundations and make informed decisions about parameters and customizations.

## Overview: Multi-Population Evolutionary Algorithm

SymbolicRegression.jl implements a sophisticated multi-population evolutionary algorithm with several key components beyond standard genetic programming:

1. **Age-regularized evolution** replacing fitness-based selection
2. **Adaptive parsimony** with frequency-based complexity penalties
3. **Evolve-simplify-optimize loop** integrating constant optimization
4. **Multi-population architecture** with migration strategies
5. **Simulated annealing** with temperature scheduling
6. **Tournament selection** with adaptive penalties

These components work together to balance exploration and exploitation while maintaining diversity in the search process.

## High-Level Algorithm Structure

### Multi-Population Coordination

The algorithm runs multiple populations (configurable, default: 15) that evolve independently. Each population contains a configurable number of members (default: 33) that represent candidate mathematical expressions.

**Population initialization pseudocode:**

```
for each output in outputs:
    for each population in populations:
        population = create_new_population(
            size = population_size,
            initial_complexity = 3,
            features = dataset_features
        )
```

**Main evolution loop:**

```
while cycles_remaining > 0:
    select next population in round-robin order

    if population_ready:
        process completed population
        update hall of fame with best expressions
        perform migration between populations
        dispatch next evolution cycle
```

### Key Design Principles

- **Asynchronous execution**: Populations evolve independently without blocking
- **Load balancing**: Work is distributed efficiently across available processors
- **Diversity preservation**: Multiple populations explore different regions of solution space

## Age-Regularized Evolution

### Core Mechanism

Traditional genetic programming replaces the worst-performing members. This algorithm instead always replaces the **oldest** member in the population, regardless of fitness.

**Age-based replacement pseudocode:**

```
for mutation:
    oldest_member = find_oldest_in_population(population)
    population.replace(oldest_member, new_mutated_expression)

for crossover:
    oldest_member_1 = find_oldest_in_population(population)
    oldest_member_2 = find_second_oldest_in_population(population)
    population.replace(oldest_member_1, child_1)
    population.replace(oldest_member_2, child_2)
```

### Why Age-Based Replacement Works

- **Prevents premature convergence**: Avoids getting stuck in local optima
- **Maintains diversity**: Ensures new ideas get time to develop
- **Balances exploration/exploitation**: Selection pressure comes from tournament selection, not replacement

Each expression tracks its "birth time" when created, enabling precise age comparison.

## Tournament Selection with Adaptive Parsimony

### Tournament Mechanics

Selection uses tournaments rather than pure fitness ranking. A tournament samples a subset of the population (configurable, default: 12 members) and selects the best with high probability (configurable, default: 0.9).

**Tournament selection pseudocode:**

```
function select_parent(population):
    tournament_sample = randomly_sample(population, tournament_size)

    if random() < selection_probability:
        return fittest_member(tournament_sample)
    else:
        return random_member(tournament_sample)
```

### Adaptive Parsimony Integration

The key innovation is **frequency-based complexity penalties** that adapt based on population composition:

**Adaptive cost calculation:**

```
for each member in tournament:
    base_cost = member.prediction_error
    complexity = count_nodes(member.expression)
    frequency = normalized_frequency[complexity] in population

    # Apply exponential penalty for overrepresented complexities
    adjusted_cost = base_cost × exp(parsimony_scaling × frequency)
```

**Mathematical effect**: If 100% of population has the same complexity, the penalty factor is approximately `exp(20×1) ≈ 5×10⁸`, providing strong pressure against homogenization.

This prevents the population from converging to a single complexity level and encourages exploration across the complexity spectrum.

## Mutation System

### Mutation Type Portfolio

The algorithm uses 14 distinct mutation types, each serving a specific purpose:

**Expression modification mutations:**

- `mutate_constant`: Adjust numerical values (e.g., `2.1` → `2.3`)
- `mutate_operator`: Change operators (e.g., `+` → `*`)
- `mutate_feature`: Change input variables (e.g., `x₁` → `x₂`)

**Structural mutations:**

- `add_node`: Insert new operation (e.g., `x` → `sin(x)`)
- `insert_node`: Add operation with random branch (e.g., `x+y` → `x+y*z`)
- `delete_node`: Remove operation (e.g., `sin(x+y)` → `x+y`)
- `swap_operands`: Reorder arguments (e.g., `x-y` → `y-x`)

**Tree-level mutations:**

- `simplify`: Apply algebraic rules (e.g., `x*x-x*x+y` → `y`)
- `optimize`: Tune constants using gradient methods
- `randomize`: Replace with completely random expression
- `rotate_tree`: Restructure expression tree
- `do_nothing`: Identity operation (maintains diversity)

**Graph-specific mutations** (for GraphNode expressions):

- `form_connection`: Add edge between nodes
- `break_connection`: Remove edge between nodes

### Dynamic Weight Conditioning

Mutation weights are dynamically adjusted based on expression properties:

**Weight conditioning pseudocode:**

```
function condition_weights(expression, current_weights):
    if expression.is_leaf_node:
        disable weights: mutate_operator, swap_operands, delete_node

    if expression.complexity >= max_allowed_size:
        disable weights: add_node, insert_node

    if dataset.num_features <= 1:
        disable weights: mutate_feature

    return adjusted_weights
```

This ensures all mutations are valid and appropriate for the current expression state.

## Simulated Annealing Integration

### Temperature Scheduling

The algorithm uses temperature to control the exploration-exploitation balance. Temperature decreases linearly over each evolution cycle (configurable duration, default: 550 cycles).

**Temperature schedule:**

```
max_temperature = 1.0
min_temperature = 0.0 (configurable: can disable annealing)
temperatures = linear_schedule(max_temp, min_temp, num_cycles)
```

### Mutation Acceptance

Mutations are accepted probabilistically based on their impact on fitness:

**Acceptance probability**: `P(accept) = exp(-(loss_new - loss_old)/(α × T))`

Where:

- `α` = parsimony scaling factor (configurable, default: 0.1)
- `T` = current temperature ∈ [0,1]
- `loss_new`, `loss_old` = prediction errors before/after mutation

**Behavioral phases:**

- **High temperature**: Accept many mutations, even harmful ones (exploration)
- **Low temperature**: Only accept improving mutations (exploitation)

## Evolve-Simplify-Optimize Loop

### Three-Stage Process

Each population evolution cycle consists of three distinct stages:

**Stage 1: Evolution with annealing**

```
for temperature in temperature_schedule:
    apply mutations and crossovers to population
    accept/reject changes based on temperature and fitness change
    track best expressions discovered
```

**Stage 2: Simplification**

```
for each expression in population:
    apply algebraic simplification rules
    combine redundant operators
    canonicalize expression structure
```

**Stage 3: Constant optimization**

```
for selected expressions (probabilistic):
    optimize numerical constants using gradient methods
    perform multiple random restarts for robustness
    use automatic differentiation for gradients
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

1. **Population-to-population migration** (configurable rate, default: 5%):
   - Source: Best members from other populations (configurable count, default: 12)
   - Target: Random positions in current population
   - Effect: Spreads good discoveries across populations

2. **Hall of Fame migration** (configurable rate, default: 0.5%):
   - Source: Pareto frontier (best at each complexity level)
   - Target: Random positions in current population
   - Effect: Injects globally best solutions

3. **Seed expression migration** (if provided, rate: 10%):
   - Source: User-provided initial guesses
   - Target: Random positions in current population
   - Effect: Incorporates domain knowledge

**Migration pseudocode:**

```
function migrate(source_population, target_population, migration_rate):
    num_migrants = poisson_sample(population_size × migration_rate)
    migrant_positions = random_sample(1:population_size, num_migrants)
    migrants = select_best(source_population, num_migrants)

    for position, migrant in zip(migrant_positions, migrants):
        target_population[position] = copy(migrant)
        reset_birth_time(target_population[position])
```

Migration uses Poisson sampling for natural stochasticity in migration intensity.

## Hall of Fame and Pareto Management

### Pareto Frontier Calculation

The Hall of Fame maintains the best expression found at each complexity level, forming a Pareto frontier.

**Domination rules:**

```
function is_dominating(candidate, hall_of_fame):
    candidate_complexity = count_nodes(candidate.expression)
    candidate_error = candidate.prediction_error

    for complexity = 1 to candidate_complexity-1:
        if hall_of_fame.exists[complexity]:
            simpler_member = hall_of_fame[complexity]
            if candidate_error >= simpler_member.error:
                return false  # Candidate doesn't improve on simpler expression

    return true  # Candidate dominates all simpler expressions
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

```
function dispatch_evolution(population, dataset):
    # Send population to available worker
    worker_task = spawn_on_worker(evolve_population, population, dataset)

    # Set up asynchronous communication
    result_channel = create_async_channel()
    setup_result_handler(worker_task, result_channel)

    return worker_task, result_channel
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

```
function optimize_constants(expression, dataset, num_restarts):
    best_result = current_expression

    for restart = 1 to num_restarts:
        # Perturb constants randomly
        perturbed_constants = constants × (1 + 0.5 × random_noise)

        # Optimize using gradient methods
        result = gradient_optimize(expression, perturbed_constants, dataset)

        if result.error < best_result.error:
            best_result = result

    return best_result
```

### Automatic Differentiation Integration

Constants are optimized using automatic differentiation for exact gradients:

- **Backend**: Uses Enzyme.jl when available for reverse-mode AD
- **Fallback**: Forward-mode differentiation for compatibility
- **Optimization target**: Minimize prediction error on dataset

## Algorithm Parameters and Tuning

### Population Dynamics (all configurable)

- `populations`: Number of independent populations (default: 15)
  - More populations → better exploration, higher compute cost
- `population_size`: Members per population (default: 33)
  - Larger populations → better diversity, slower convergence
- `tournament_selection_n`: Tournament size (default: 12)
  - Larger tournaments → stronger selection pressure
- `tournament_selection_p`: Selection probability (default: 0.9)
  - Higher probability → more exploitation vs exploration

### Evolution Control (all configurable)

- `ncycles_per_iteration`: Evolution cycles per iteration (default: 550)
  - More cycles → more thorough search per iteration
- `crossover_probability`: Rate of crossover vs mutation (default: 0.01)
  - Higher values → more recombination between expressions
- `annealing`: Enable temperature scheduling (default: true)
  - Controls exploration-exploitation balance over time

### Complexity Management (all configurable)

- `adaptive_parsimony_scaling`: Strength of complexity penalties (default: 20.0)
  - Higher values → stronger pressure against overrepresented complexities
- `use_frequency_in_tournament`: Enable adaptive parsimony (default: true)
  - Controls whether complexity penalties adapt to population composition

### Migration Control (all configurable)

- `fraction_replaced`: Population migration rate (default: 0.05)
- `fraction_replaced_hof`: Hall of Fame migration rate (default: 0.005)
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

### Convergence Patterns

**Early phase**: High diversity, rapid improvement in best solutions, temperature-driven exploration

**Middle phase**: Population specialization, refinement of promising solution families

**Late phase**: Fine-tuning of constants, exploitation of best-known solutions

### Success Indicators

- **Hall of Fame updates**: New entries indicate algorithmic progress
- **Population diversity**: Variety in expression complexities and structures
- **Pareto frontier growth**: Expansion of accuracy-complexity trade-offs
- **Convergence stability**: Consistent best solutions across runs

This algorithmic framework provides a robust foundation for discovering interpretable mathematical expressions from data, balancing the competing demands of accuracy, simplicity, and computational efficiency through carefully coordinated evolutionary processes.
