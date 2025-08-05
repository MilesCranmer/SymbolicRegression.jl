# Foundational Concepts

This page introduces the fundamental concepts underlying SymbolicRegression.jl.

## What is Symbolic Regression?

Symbolic regression is a machine learning approach that searches for mathematical expressions (rather than just fitting parameters) to model your data. Unlike neural networks that create black-box models, symbolic regression discovers interpretable equations like `y = 2.1 * sin(x^2) + 0.3 * x`.

The key insight is that we're searching through the space of all possible mathematical expressions to find ones that balance two competing goals:

- **Accuracy**: How well does the expression fit your data?
- **Simplicity**: How interpretable and generalizable is the expression?

This trade-off is fundamental to symbolic regression and drives all the algorithmic decisions described below.

## Expression Trees: The Building Blocks

### Tree Structure

Mathematical expressions are represented as tree data structures where:

- **Leaf nodes** contain variables (`x`, `y`) or constants (`2.1`, `-0.5`)
- **Operator nodes** contain operators (`+`, `*`, `sin`, `exp`) and have a **degree** (number of arguments)
  - Unary operators like `sin`, `exp` have degree 1
  - Binary operators like `+`, `*` have degree 2
- **Tree evaluation** happens bottom-up: evaluate leaves first, then combine using operators

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

The concept of complexity is somewhat arbitrary, but the library defines it by default as counting the number of nodes in the tree. A constant like `2.1` has complexity 1, while `sin(x * 2.1) + y` has complexity 6 (one node each for: `sin`, `*`, `x`, `2.1`, `+`, `y`). This simple measure captures intuitive notions of expression complexity, though you can define custom complexity metrics for your domain.

## The Pareto Frontier: Balancing Accuracy vs Simplicity

These objectives often conflict - more complex expressions can fit data better but are harder to interpret and may overfit.

### What is a Pareto Frontier?

The Pareto frontier (or Pareto front) is the set of expressions we found where you cannot improve accuracy without increasing complexity, or reduce complexity without sacrificing accuracy. These are the "non-dominated" solutions among those discovered by the search.

For example, if you have:

- Expression A: complexity 3, error 0.1
- Expression B: complexity 5, error 0.05
- Expression C: complexity 4, error 0.08

Then A and B are on the Pareto frontier (A is simpler, B is more accurate), but C is dominated by B (B is both more accurate and simpler than C).

### Hall of Fame

The "Hall of Fame" maintains the best expression found at each complexity level. This creates a Pareto frontier where you can choose your preferred trade-off between simplicity and accuracy. The Hall of Fame persists the best discoveries throughout the search, ensuring good solutions aren't lost.

The Pareto frontier gives you choices rather than a single answer. You might prefer a simple expression that's "good enough" over a complex one that's slightly more accurate, or vice versa.

## Population-Based Evolution

### Evolutionary Algorithm Basics

SymbolicRegression.jl uses evolutionary algorithms inspired by biological evolution. The algorithm maintains a **population** - a collection of candidate expressions. Through **selection**, the algorithm chooses expressions to modify. **Variation** creates new expressions through mutation and crossover. **Replacement** determines which expressions remain in the population for the next generation.

### Tournament Selection

Rather than always selecting the best expressions, the algorithm uses tournament selection. It randomly samples a small subset (parameter: `tournament_selection_n`, default 12 expressions), ranks them by cost, and selects the best with probability `tournament_selection_p` (default: 0.86), but sometimes chooses others. This maintains diversity and prevents premature convergence to local optima.

The cost function is: `cost = (loss / normalization) + (complexity × parsimony)` where normalization is typically the baseline loss or 0.01 as fallback. In some papers this is called "fitness," but the library calls it "cost."

### Multiple Populations (Island Model)

The search runs multiple independent populations in parallel. This enables massive parallelization where each population can evolve on separate CPU cores, while different populations explore different regions of the solution space. Periodically, good expressions migrate between populations, sharing discoveries while maintaining diversity.

### Age-Based Replacement

Instead of always replacing the worst expression, the algorithm always replaces the oldest. This prevents the population from prematurely converging and ensures newer ideas get a chance to develop.

## Search Dynamics and Temperature

### The Exploration-Exploitation Trade-off

Successful symbolic regression requires balancing exploration (trying diverse, potentially radical new expressions) and exploitation (refining promising expressions found so far).

### Simulated Annealing

The algorithm uses "temperature" to control this balance. High temperature means accepting many mutations, even ones that worsen the cost (exploration). Low temperature means only accepting improvements (exploitation). The cooling schedule decreases temperature over time, shifting from exploration to exploitation.

### Evolve-Simplify-Optimize Loop

The algorithm follows an evolve-simplify-optimize loop. First, it applies mutations and crossovers to generate new expressions. Then it applies algebraic simplifications using SymbolicUtils.jl (like converting `sin(3.0)` to its numerical value). Finally, it uses gradient-based methods to optimize numerical constants. This loop is crucial for finding expressions with real-valued constants, which are essential for scientific applications.

### Adaptive Parsimony

Rather than using a fixed complexity penalty, the algorithm adapts the penalty based on the current population. If too many expressions have the same complexity, that complexity is penalized more heavily using the parameter `adaptive_parsimony_scaling`. This encourages exploration across different complexity levels.

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

## Expressions and Expression Objects

An **expression object** in SymbolicRegression.jl contains more than just the tree structure. It holds the tree (which is an `AbstractExpressionNode`) along with metadata. A **PopMember** contains the expression tree plus additional fields like `cost`, `loss`, `birth` (age), `complexity`, and parent reference. This distinction is important when working with the library's API.

## Understanding the Search Process

### Why Search is Hard

The space of mathematical expressions presents several challenges: it's infinite (no upper bound on complexity), discrete (small changes like `x*y` to `x/y` can have huge effects), non-smooth (similar expressions can behave very differently), and multimodal (many local optima separated by valleys of poor solutions).

### How the Algorithm Addresses These Challenges

The algorithm uses multi-population search to explore multiple regions simultaneously, temperature control to balance exploration and exploitation, Pareto optimization to avoid getting stuck on accuracy alone, constant optimization to handle the continuous aspects efficiently, and simplification to reduce redundancy.

This conceptual foundation covers the key ideas underlying SymbolicRegression.jl. The algorithm provides a principled way to search the vast space of mathematical expressions, balancing the competing demands of accuracy and interpretability that are central to scientific modeling.
