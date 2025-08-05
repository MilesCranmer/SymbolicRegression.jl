# Advanced Algorithmic Details

This document provides deep technical details about the algorithms implemented in SymbolicRegression.jl, verified against the actual codebase. It is intended for advanced users who want to understand, modify, or contribute to the algorithmic core.

## Overview: Multi-Population Evolutionary Algorithm

SymbolicRegression.jl implements a sophisticated multi-population evolutionary algorithm with several key innovations beyond standard genetic programming:

1. **Age-regularized evolution** replacing fitness-based selection
2. **Adaptive parsimony** with frequency-based complexity penalties
3. **Evolve-simplify-optimize loop** integrating constant optimization
4. **Multi-population architecture** with migration strategies
5. **Simulated annealing** with temperature scheduling
6. **Tournament selection** with adaptive penalties

## Multi-Population Architecture

### Population Structure

Each search runs multiple populations (default: `populations=15`) that evolve independently and asynchronously. Each population contains `population_size=33` members by default.

**Implementation location**: `/src/SymbolicRegression.jl:567-708`

```julia
# Population initialization (lines 667-687)
for j in 1:nout, i in 1:(options.populations)
    new_pop = Population(
        datasets[j];
        population_size=options.population_size,
        nlength=3,  # Initial expression size
        options=options,
        nfeatures=max_features(datasets[j], options),
    )
end
```

### Multi-Population Evolution Loop

The outer algorithm (Algorithm 1 in the PySR paper) coordinates multiple populations:

**Main loop implementation**: `/src/SymbolicRegression.jl:842-1091`

```julia
while sum(state.cycles_remaining) > 0
    kappa += 1
    if kappa > options.populations * nout
        kappa = 1
    end
    j, i = state.task_order[kappa]  # Round-robin population selection

    if population_ready
        # Process completed population
        # Update hall of fame
        # Perform migration
        # Dispatch next evolution cycle
    end
end
```

Key aspects:

- **Round-robin scheduling**: Populations are processed in shuffled order for load balancing
- **Asynchronous execution**: Populations evolve independently without blocking
- **Adaptive work distribution**: Task assignment accounts for worker availability

## Age-Regularized Evolution

### Core Principle

Instead of replacing the worst-performing member, the algorithm always replaces the **oldest** member in the population. This prevents premature convergence by maintaining age diversity.

**Implementation**: `/src/RegularizedEvolution.jl:45,99-103`

```julia
# For mutations (line 45):
oldest = argmin_fast([pop.members[member].birth for member in 1:(pop.n)])
pop.members[oldest] = baby

# For crossover (lines 99-103):
oldest1 = argmin_fast([pop.members[member].birth for member in 1:(pop.n)])
oldest2 = argmin_fast([
    i == oldest1 ? typemax(BT) : pop.members[i].birth for i in 1:(pop.n)
])
```

### Birth Time Tracking

Each `PopMember` gets a birth time from `time()` when created, enabling precise age tracking:

**Birth assignment**: `/src/PopMember.jl` (birth time set during construction)

This approach, inspired by Neural Architecture Search results, prevents early specialization in local minima while maintaining selection pressure through tournament selection.

## Tournament Selection with Adaptive Parsimony

### Tournament Mechanics

Tournament selection samples `tournament_selection_n=12` members and selects the best with probability `tournament_selection_p=0.9`.

**Implementation**: `/src/Population.jl:109-155`

```julia
function best_of_sample(pop, running_search_statistics, options)
    sample = sample_pop(pop, options)  # Sample 12 members
    return copy(_best_of_sample(sample.members, running_search_statistics, options))
end

function _best_of_sample(members, running_search_statistics, options)
    # Tournament with probability p=0.9 for fittest
    chosen_idx = if p == 1.0
        argmin_fast(adjusted_costs)
    else
        tournament_winner = StatsBase.sample(get_tournament_selection_weights(options))
        # Select member that won that tournament position
    end
end
```

### Adaptive Parsimony Integration

The key innovation is **frequency-based complexity penalties** that adaptively adjust based on population composition:

**Implementation**: `/src/Population.jl:124-142`

```julia
if options.use_frequency_in_tournament
    adaptive_parsimony_scaling = L(options.adaptive_parsimony_scaling)  # Default: 20.0

    for i in 1:n
        member = members[i]
        size = compute_complexity(member, options)
        frequency = if (0 < size <= options.maxsize)
            L(running_search_statistics.normalized_frequencies[size])
        else
            L(0)
        end
        # Apply exponential penalty based on frequency
        adjusted_costs[i] = member.cost * exp(adaptive_parsimony_scaling * frequency)
    end
end
```

**Mathematical formula**: `adjusted_cost = base_cost × exp(20.0 × normalized_frequency)`

For 100% population at one complexity: `exp(-20×1) ≈ 2×10⁻⁹`, providing strong pressure against homogenization.

## Frequency Tracking and Normalization

### Running Statistics

**Implementation**: `/src/AdaptiveParsimony.jl:20-32`

```julia
struct RunningSearchStatistics
    window_size::Int            # Default: 100000
    frequencies::Vector{Float64}        # Raw counts
    normalized_frequencies::Vector{Float64}  # Normalized to sum=1
end
```

### Window Management

The frequency window prevents unbounded growth:

**Implementation**: `/src/AdaptiveParsimony.jl:55-87`

```julia
function move_window!(running_search_statistics::RunningSearchStatistics)
    frequencies = running_search_statistics.frequencies
    window_size = running_search_statistics.window_size

    cur_size_frequency_complexities = sum(frequencies)
    if cur_size_frequency_complexities > window_size
        # Proportionally reduce all frequencies to maintain window size
        # while preserving relative relationships
    end
end
```

This maintains a sliding window of complexity frequencies, ensuring recent patterns have more influence than distant history.

## Mutation System

### Mutation Type Distribution

The algorithm uses 14 distinct mutation types with adaptive weighting:

**Base weights** (from `/src/MutationWeights.jl`):

- `mutate_constant: 0.048`
- `mutate_operator: 0.47`
- `add_node: 0.79`
- `insert_node: 5.1`
- `delete_node: 1.7`
- `simplify: 0.0020`
- `randomize: 0.00023`
- `optimize: 0.0020`
- `do_nothing: 0.21`
- `mutate_feature: 0.048`
- `swap_operands: 0.23`
- `rotate_tree: 0.0020`
- `form_connection: 0.0020` (GraphNode only)
- `break_connection: 0.0020` (GraphNode only)

### Constraint-Based Weight Conditioning

Weights are dynamically adjusted based on expression properties:

**Implementation**: `/src/Mutate.jl:101-157`

```julia
function condition_mutation_weights!(weights, member, options, curmaxsize, nfeatures)
    tree = get_tree(member.tree)

    if tree.degree == 0  # Leaf node
        weights.mutate_operator = 0.0
        weights.swap_operands = 0.0
        weights.delete_node = 0.0
        weights.simplify = 0.0
        # Additional constraints based on constant vs variable
    end

    if complexity >= curmaxsize  # Size limit reached
        weights.add_node = 0.0
        weights.insert_node = 0.0
    end

    if nfeatures <= 1  # Single feature
        weights.mutate_feature = 0.0
    end
end
```

This ensures mutations are always valid and appropriate for the current expression state.

## Simulated Annealing Integration

### Temperature Scheduling

**Implementation**: `/src/SingleIteration.jl:31-36`

```julia
max_temp = 1.0
min_temp = 0.0
if !options.annealing
    min_temp = max_temp  # Constant temperature
end
all_temperatures = ncycles > 1 ? LinRange(max_temp, min_temp, ncycles) : [max_temp]
```

Temperature decreases linearly from 1.0 to 0.0 over `ncycles_per_iteration=550` cycles.

### Mutation Acceptance

**Acceptance probability**: `/src/Mutate.jl` (in mutation functions)

The acceptance probability for mutations follows: `P(accept) = exp(-(L_new - L_old)/(α × T))`

Where:

- `α = 0.1` (adaptive parsimony scaling)
- `T` = current temperature ∈ [0,1]
- `L_new`, `L_old` = losses before/after mutation

This allows the algorithm to alternate between:

- **High temperature phases**: Accept suboptimal mutations, explore broadly
- **Low temperature phases**: Only accept improving mutations, exploit locally

## Evolve-Simplify-Optimize Loop

### Three-Stage Process

Each population evolution cycle consists of three stages:

**Implementation**: `/src/SingleIteration.jl:19-66, 68-110`

```julia
function s_r_cycle(dataset, pop, ncycles, curmaxsize, running_search_statistics; options)
    # Stage 1: Evolution with simulated annealing
    for temperature in all_temperatures
        pop, tmp_num_evals = reg_evol_cycle(
            batched_dataset, pop, temperature, curmaxsize,
            running_search_statistics, options, record
        )
    end

    # Return best examples seen during evolution
    return (pop, best_examples_seen, num_evals)
end

function optimize_and_simplify_population(dataset, pop, options, curmaxsize, record)
    # Stage 2: Simplification
    if options.should_simplify
        tree = simplify_tree!(tree, options.operators)
        tree = combine_operators(tree, options.operators)
    end

    # Stage 3: Constant optimization
    if options.should_optimize_constants && do_optimization[j]
        pop.members[j], array_num_evals[j] = optimize_constants(
            batched_dataset, pop.members[j], options
        )
    end
end
```

### Rationale for Staged Approach

1. **Evolution first**: Generate diverse expressions through mutations/crossover
2. **Simplification**: Reduce redundant expressions (e.g., `x*x - x*x + y → y`)
3. **Optimization**: Fine-tune numerical constants for final accuracy

The separation allows intermediate redundant states (necessary for some mutations) while ensuring final expressions are clean and optimized.

## Constant Optimization Details

### Multi-Restart Gradient-Based Optimization

**Implementation**: `/src/ConstantOptimization.jl:29-59, 88-100`

```julia
function optimize_constants(dataset, member, options; rng)
    nconst = count_constants_for_optimization(member.tree)

    if nconst == 1 && !(T <: Complex)
        algorithm = Optim.Newton(; linesearch=LineSearches.BackTracking())
    else
        algorithm = options.optimizer_algorithm  # Default: BFGS
    end

    # Multiple random restarts for robustness
    for _ in 1:(options.optimizer_nrestarts)  # Default: 2
        eps = randn(rng, T, size(x0)...)
        xt = @. x0 * (T(1) + T(1//2) * eps)  # Perturb initial guess
        tmpresult = Optim.optimize(obj, xt, algorithm, optimizer_options)

        if tmpresult.minimum < result.minimum
            result = tmpresult
        end
    end
end
```

### Automatic Differentiation

Constants are optimized using automatic differentiation:

- **Single constant**: Newton's method with line search
- **Multiple constants**: BFGS with gradient computation
- **Backend**: Enzyme.jl for reverse-mode AD when available

## Migration Strategies

### Inter-Population Migration

**Implementation**: `/src/Migration.jl:15-37`

```julia
function migrate!(migration::Pair{Vector{PM},P}, options; frac::AbstractFloat)
    population_size = length(base_pop.members)
    mean_number_replaced = population_size * frac
    num_replace = poisson_sample(mean_number_replaced)  # Stochastic replacement count

    locations = rand(1:population_size, num_replace)  # Random positions
    migrants = rand(migrant_candidates, num_replace)  # Random migrants

    for (i, migrant) in zip(locations, migrants)
        base_pop.members[i] = copy(migrant)
        reset_birth!(base_pop.members[i]; options.deterministic)  # Reset age
    end
end
```

### Migration Types

**In main search loop** (`/src/SymbolicRegression.jl:946-963`):

1. **Population-to-population migration** (`migration=true`):
   - Source: Best `topn=12` members from each population
   - Target: Random positions in current population
   - Rate: `fraction_replaced=0.05` (5% replacement)

2. **Hall of Fame migration** (`hof_migration=true`):
   - Source: Pareto frontier (dominating expressions at each complexity)
   - Target: Random positions in current population
   - Rate: `fraction_replaced_hof=0.005` (0.5% replacement)

3. **Guess seeding** (if initial guesses provided):
   - Source: Parsed seed expressions
   - Target: Random positions in current population
   - Rate: `fraction_replaced_guesses=0.1` (10% replacement)

Migration uses **Poisson sampling** for replacement counts, creating natural stochasticity in migration intensity.

## Hall of Fame and Pareto Management

### Pareto Frontier Calculation

**Implementation**: `/src/HallOfFame.jl:94-120`

```julia
function calculate_pareto_frontier(hallOfFame::HallOfFame{T,L,N})
    dominating = PopMember{T,L,N}[]

    for size in 1:(length(hallOfFame.members))
        if hallOfFame.exists[size]
            member = hallOfFame.members[size]

            # Check if this member dominates all simpler expressions
            is_dominating = true
            for i in 1:(size-1)
                if hallOfFame.exists[i]
                    simpler_member = hallOfFame.members[i]
                    if member.cost >= simpler_member.cost
                        is_dominating = false
                        break
                    end
                end
            end

            if is_dominating
                push!(dominating, member)
            end
        end
    end

    return dominating
end
```

### Domination Rules

An expression dominates if it is **strictly better** (lower cost) than **all** simpler expressions. This creates a Pareto frontier where:

- Each complexity level has at most one representative
- Higher complexity is only accepted if it provides better accuracy
- The frontier represents the optimal accuracy-complexity trade-offs

## Parallelization Architecture

### Worker Management

**Implementation**: `/src/SymbolicRegression.jl:617-708`

The algorithm supports three parallelization modes:

1. **Serial** (`:serial`): Single-threaded for debugging
2. **Multithreading** (`:multithreading`): Julia threads, shared memory
3. **Multiprocessing** (`:multiprocessing`): Distributed processes, message passing

### Asynchronous Population Evolution

**Key insight**: Populations evolve asynchronously without blocking the main thread.

**Implementation**: `/src/SymbolicRegression.jl:986-1007`

```julia
# Dispatch evolution to worker
state.worker_output[j][i] = @sr_spawner(
    begin
        _dispatch_s_r_cycle(
            in_pop, dataset, options;
            pop=i, out=j, iteration, verbosity, cur_maxsize,
            running_search_statistics=c_rss,
        )
    end,
    parallelism = ropt.parallelism,
    worker_idx = worker_idx
)

# Set up async communication
if ropt.parallelism in (:multiprocessing, :multithreading)
    state.tasks[j][i] = @filtered_async put!(
        state.channels[j][i], fetch(state.worker_output[j][i])
    )
end
```

This architecture enables:

- **Load balancing**: Faster workers get more populations to process
- **Fault tolerance**: Failed populations don't block the entire search
- **Scalability**: Can efficiently use hundreds to thousands of cores

## Performance Optimizations

### Expression Evaluation Optimizations

1. **SIMD operator fusion**: Julia's JIT compiler automatically vectorizes and fuses operators
2. **Batching**: Evaluate expressions on data subsets when `batching=true`
3. **Constraint checking**: Fast rejection of invalid expressions before evaluation

### Memory Management

1. **Copy-on-write**: Expressions share structure until modified
2. **Birth time tracking**: Minimal overhead for age-regularized evolution
3. **Frequency windows**: Bounded memory for adaptive parsimony statistics

### Algorithmic Complexity

- **Tournament selection**: O(tournament_size × log(tournament_size)) per selection
- **Mutation**: O(tree_size) for most mutation types
- **Pareto calculation**: O(maxsize²) per update
- **Migration**: O(migration_count) with Poisson sampling

## Algorithm Parameters

### Key Parameters and Their Effects

**Population dynamics**:

- `populations=15`: More populations → better exploration, more compute
- `population_size=33`: Larger populations → better diversity, slower convergence
- `tournament_selection_n=12`: Larger tournament → stronger selection pressure
- `tournament_selection_p=0.9`: Higher probability → more exploitation

**Evolution parameters**:

- `ncycles_per_iteration=550`: More cycles → more thorough search per iteration
- `crossover_probability=0.01`: Higher → more recombination vs mutation
- `annealing=true`: Temperature scheduling vs constant temperature

**Parsimony control**:

- `adaptive_parsimony_scaling=20.0`: Higher → stronger complexity penalties
- `use_frequency_in_tournament=true`: Enable/disable adaptive parsimony

**Migration rates**:

- `fraction_replaced=0.05`: Population-to-population migration intensity
- `fraction_replaced_hof=0.005`: Hall of Fame migration intensity
- `topn=12`: Number of best members available for migration

**Optimization**:

- `optimizer_probability=0.14`: Fraction of expressions to optimize per iteration
- `optimizer_nrestarts=2`: Robustness vs compute trade-off for constant optimization

### Scaling Recommendations

**For larger datasets** (>10K points):

- Enable `batching=true` with `batch_size=50`
- Increase `population_size` to maintain diversity
- Consider higher `ncycles_per_iteration` for thorough search

**For more complex expressions**:

- Increase `maxsize` and `maxdepth` constraints
- Reduce `adaptive_parsimony_scaling` to allow complex solutions
- Increase `optimizer_nrestarts` for better constant fitting

**For parallel scaling**:

- Increase `populations` proportionally to available cores
- Use `:multithreading` for single-node, `:multiprocessing` for clusters
- Monitor `head_node_occupation` to ensure efficient worker utilization

## Conclusion

SymbolicRegression.jl implements a sophisticated evolutionary algorithm that goes far beyond standard genetic programming. The key innovations—age-regularized evolution, adaptive parsimony, evolve-simplify-optimize cycles, and multi-population architecture—work synergistically to enable robust discovery of symbolic expressions from noisy scientific data.

The algorithm's design reflects deep understanding of the symbolic regression problem, balancing exploration vs exploitation, complexity vs accuracy, and computational efficiency vs solution quality. Each component has been carefully tuned based on empirical results and theoretical insights from the broader evolutionary computation and symbolic regression literature.

For researchers and practitioners, this detailed algorithmic understanding enables informed parameter tuning, algorithmic modifications, and principled extensions to the core methodology.
