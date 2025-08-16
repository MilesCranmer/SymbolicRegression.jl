# Foundational Concepts

This page introduces various fundamental concepts and terminology used throughout SymbolicRegression.jl, both internally and in the API.

## What is Symbolic Regression?

Symbolic regression is a machine learning task where the goal is to find simple mathematical expressions that optimize some objective. This differs from much of modern deep learning workflows that tend to focus on fitting parameters in an overparametrized flexible black box model.

`y = 2.1 * sin(x^2) + 0.3 * x`

Another difference is that symbolic regression has two objectives. We want to search through the space of all possible mathematical expressions to find ones that balance _two_ competing goals:

- **Accuracy**: How well does the expression fit your data or otherwise optimize your objective?
- **Simplicity**: How small is the expression tree?

This trade-off is fundamental to symbolic regression and drives many of the algorithmic decisions described below.

## Expression Trees: The Building Blocks

### Tree Structure

Mathematical expressions are represented in SymbolicRegression.jl as tree data structures where:

- **Leaf nodes** contain variables (`x`, `y`) or constants (`2.1`, `-0.5`)
- **Operator nodes** contain operators (`+`, `*`, `sin`, `exp`) and have a **degree** (number of arguments)
  - Unary operators like `sin`, `exp` have degree 1
  - Binary operators like `+`, `*` have degree 2

Tree evaluation, and many other operations, happen bottom-up (depth-first traversal): evaluate leaves first, then combine using operators.

For example, the expression `sin(x * 2.1) + y` becomes:

```
     +
   /   \
  sin   y
   |
   *
  / \
 x  2.1
```

### Expression Complexity

By default, complexity is the number of nodes in the tree. A constant like `2.1` has complexity 1, while `sin(x * 2.1) + y` has complexity 6 (one node each for: `sin`, `*`, `x`, `2.1`, `+`, `y`). This default can be customized via `Options` using operator-specific weights, constant/variable weights, or a custom `complexity_mapping` function.

## The Pareto Frontier: Balancing Accuracy vs Simplicity

The two objectives in symbolic regression conflict - more complexity can almost always achieve lower or equal loss (think of it like a Taylor polynomial expansion - higher complexity is like higher order).

### What is a Pareto Frontier?

The Pareto frontier (or Pareto front) is the set of expressions we found where you cannot improve loss without increasing complexity, or reduce complexity without increasing loss. These are the "non-dominated" solutions among those discovered by the search.

For example, if you have:

- Expression A: complexity 3, loss 0.1
- Expression B: complexity 4, loss 0.05
- Expression C: complexity 6, loss 0.08

Then A and B are on the Pareto frontier (A is simpler, B has lower loss), but C is _dominated_ by B (B has both lower loss and lower complexity than C), and so is not included.

### Hall of Fame

The **Hall of Fame** tracks the best expression found at each complexity level throughout the entire search. The Hall of Fame preserves discoveries - even if a good expression is later replaced in the population, it remains in the Hall of Fame.

The Pareto frontier is computed from the Hall of Fame by selecting expressions that are non-dominated.

The Pareto frontier gives you choices rather than a single answer. You might prefer a simple expression with acceptable loss over a complex one with slightly lower loss, or vice versa.

By default, SymbolicRegression.jl uses a heuristic to pick one expression from this Pareto frontier, but this is purely for convenience and compatibility with tools that expect a single prediction. In practice, you should think deeply about this and select an expression based on personal preference or some heuristic of your choosing.

## Population-Based Evolution

### Evolutionary Algorithm Basics

SymbolicRegression.jl uses evolutionary algorithms inspired by biological evolution. The algorithm maintains a **population** - a collection of candidate expressions. Through **selection**, the algorithm chooses expressions to modify. **Mutation and crossover** create new expressions from the selection in creating the next **generation**. **Replacement** determines which expressions remain in the population for the next generation, and which to replace with the new generation.

### Tournament Selection

Rather than always selecting the best expressions from an entire population, the algorithm uses tournament selection. It randomly samples a small subset (`tournament_selection_n`, default 15), computes an adjusted cost per member, and then selects a rank with some probability (`tournament_selection_p`, default 0.982 for the 1st rank). The adjusted cost applies adaptive parsimony when enabled (`use_frequency_in_tournament = true`), multiplying the cost by `exp(adaptive_parsimony_scaling × frequency_at_complexity)` where the frequency is tracked during the search.

The base cost is derived from the predictive loss, normalized by a baseline, plus a fixed parsimony term when `parsimony > 0`:

`cost = (loss / normalization) + (complexity × parsimony)`

Normalization uses the dataset baseline loss if finite, else a fallback of 0.01.

### Multiple Populations (Island Model)

The search runs multiple independent populations in parallel. This enables massive parallelization where each population can evolve on separate CPU cores, while different populations explore different regions of the solution space. Periodically, good expressions migrate between populations, sharing discoveries while maintaining diversity.

### Age-Based Replacement

Instead of replacing the worst expression, the algorithm replaces the oldest member of the population (or the two oldest for crossover). This "age-regularized" evolution prevents premature convergence and helps newer ideas get a chance to develop.

## Search Dynamics and Temperature

### The Exploration-Exploitation Trade-off

Successful symbolic regression requires balancing exploration (trying diverse, potentially radical new expressions) and exploitation (refining promising expressions found so far).

### Simulated Annealing

The algorithm uses a temperature to control this balance. Acceptance probability is `exp(-(cost_new - cost_old)/(α × T))`, optionally scaled by an adaptive parsimony frequency ratio when enabled. Temperature decreases linearly over a cycle, shifting from exploration to exploitation.

### Evolve-Simplify-Optimize Loop

The algorithm follows an evolve-simplify-optimize loop. First, it applies mutations and crossovers to generate new expressions. Then it applies algebraic simplifications using DynamicExpressions.jl’s `simplify_tree!` and `combine_operators`. Finally, it uses Optim.jl-based methods to optimize numerical constants (with AD backend specified in `Options`).

### Adaptive Parsimony

Rather than using only a fixed complexity penalty, the algorithm can adapt a per-complexity penalty based on population composition. By default, `parsimony = 0.0` and `use_frequency = true` together with `adaptive_parsimony_scaling = 1040` encourage a balanced distribution over sizes: overrepresented complexities see higher effective costs in tournaments, and acceptance is biased away from them.

## Constraint Systems

### Hard vs Soft Constraints

- **Hard constraints**: Violations make expressions invalid and rejected immediately
- **Soft constraints**: Violations are penalized but expressions remain valid

### Types of Constraints

#### Size and Structure Constraints

- **Maximum size**: Limit total number of nodes
- **Maximum depth**: Prevent deeply nested expressions
- **Operator-specific constraints**: E.g., expressions in `x^n` must be simple

#### Domain-Specific Constraints

- **Dimensional analysis**: Ensure expressions have correct physical units
- **Nested operator limits**: Prevent pathological cases like `sin(sin(sin(...)))`
  - Nested constraints can be specified per-operator (e.g., limit how many times `cos` may be nested within another `cos`).

## Expressions and Expression Objects

An **expression object** in SymbolicRegression.jl contains more than just the tree structure. It holds the tree (which is an `AbstractExpressionNode`) along with metadata. A **PopMember** contains the expression tree plus additional fields like `cost`, `loss`, `birth` (age), `complexity`, and parent reference. This distinction is important when working with the library's API.

## Understanding the Search Process

### Why Search is Hard

The space of mathematical expressions presents several challenges: it's infinite (no upper bound on complexity), discrete (small changes like `x*y` to `x/y` can have huge effects), non-smooth (similar expressions can behave very differently), and multimodal (many local optima separated by valleys of poor solutions).

### How the Algorithm Addresses These Challenges

The algorithm uses multi-population search to explore multiple regions simultaneously, temperature control to balance exploration and exploitation, Pareto optimization to avoid getting stuck on accuracy alone, constant optimization to handle the continuous aspects efficiently, and simplification to reduce redundancy.
