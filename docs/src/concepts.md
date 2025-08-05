# Foundational Concepts

This page introduces the fundamental concepts underlying SymbolicRegression.jl. Understanding these ideas will help you use the library effectively and interpret its results meaningfully.

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
- **Internal nodes** contain operators (`+`, `*`, `sin`, `exp`)
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

### Why Trees Matter

Trees naturally capture the compositional structure of mathematics - complex expressions are built from simpler parts. This structure:

- Enables efficient evaluation and manipulation
- Allows for meaningful mutations (changing parts of expressions)
- Provides a natural complexity measure (tree size)
- Makes simplification and optimization possible

### Expression Complexity

By default, complexity equals the number of nodes in the tree. A constant like `2.1` has complexity 1, while `sin(x * 2.1) + y` has complexity 5. This simple measure captures intuitive notions of expression complexity, though you can define custom complexity metrics for your domain.

## The Pareto Frontier: Balancing Accuracy vs Simplicity

### Multi-Objective Optimization

Rather than optimizing a single metric, symbolic regression treats equation discovery as a multi-objective problem:

- **Minimize prediction error** (maximize accuracy)
- **Minimize complexity** (maximize interpretability)

These objectives often conflict - more complex expressions can fit data better but are harder to interpret and may overfit.

### What is a Pareto Frontier?

The Pareto frontier (or Pareto front) is the set of expressions where you cannot improve accuracy without increasing complexity, or reduce complexity without sacrificing accuracy. These are the "non-dominated" solutions.

For example, if you have:

- Expression A: complexity 3, error 0.1
- Expression B: complexity 5, error 0.05
- Expression C: complexity 4, error 0.08

Then A and B are on the Pareto frontier (A is simpler, B is more accurate), but C is dominated by B (B is both simpler and more accurate than C).

### Hall of Fame

The "Hall of Fame" maintains the best expression found at each complexity level. This creates a Pareto frontier where you can choose your preferred trade-off between simplicity and accuracy. The Hall of Fame persists the best discoveries throughout the search, ensuring good solutions aren't lost.

### Why This Matters

The Pareto frontier gives you choices rather than a single answer. You might prefer a simple expression that's "good enough" over a complex one that's slightly more accurate, or vice versa. This flexibility is crucial for scientific applications where interpretability often matters more than perfect accuracy.

## Population-Based Evolution

### Evolutionary Algorithm Basics

SymbolicRegression.jl uses evolutionary algorithms inspired by biological evolution:

1. **Population**: A collection of candidate expressions (typically 1000)
2. **Selection**: Choose the fittest expressions to "breed"
3. **Variation**: Create new expressions through mutation and crossover
4. **Replacement**: New expressions replace older/weaker ones

### Tournament Selection

Rather than always selecting the best expressions, the algorithm uses tournament selection:

1. Randomly sample a small subset (e.g., 12 expressions)
2. Rank them by fitness (accuracy + complexity penalty)
3. Select the best with high probability (~90%), but sometimes choose others

This maintains diversity and prevents premature convergence to local optima.

### Multiple Populations (Island Model)

The search runs multiple independent populations in parallel. This provides:

- **Massive parallelization**: Each population can evolve on separate CPU cores
- **Diversity preservation**: Different populations can explore different regions
- **Migration**: Good expressions occasionally migrate between populations

Periodically, the best expressions from each population migrate to others, sharing discoveries while maintaining diversity.

### Age-Based Replacement

Instead of always replacing the worst expression, the algorithm sometimes replaces the oldest. This prevents the population from prematurely converging and ensures newer ideas get a chance to develop.

## Search Dynamics and Temperature

### The Exploration-Exploitation Trade-off

Successful symbolic regression requires balancing:

- **Exploration**: Trying diverse, potentially radical new expressions
- **Exploitation**: Refining promising expressions found so far

### Simulated Annealing

The algorithm uses "temperature" to control this balance:

- **High temperature**: Accept many mutations, even ones that worsen fitness (exploration)
- **Low temperature**: Only accept improvements (exploitation)
- **Cooling schedule**: Temperature decreases over time, shifting from exploration to exploitation

### Evolve-Simplify-Optimize Loop

Each evolutionary cycle consists of three phases:

1. **Evolve**: Apply mutations and crossovers to generate new expressions
2. **Simplify**: Apply algebraic simplifications (e.g., `x + x` → `2*x`)
3. **Optimize**: Use gradient-based methods to optimize numerical constants

This loop is crucial for finding expressions with real-valued constants, which are essential for scientific applications.

### Adaptive Parsimony

Rather than using a fixed complexity penalty, the algorithm adapts the penalty based on the current population. If too many expressions have the same complexity, that complexity is penalized more heavily. This encourages exploration across different complexity levels.

## Constraint Systems

### Hard vs Soft Constraints

- **Hard constraints**: Violations make expressions invalid and rejected immediately
- **Soft constraints**: Violations are penalized but expressions remain valid

### Types of Constraints

#### Size and Structure Constraints

- **Maximum size**: Limit total number of nodes
- **Maximum depth**: Prevent deeply nested expressions
- **Operator-specific size limits**: E.g., exponent in `x^n` must be small

#### Domain-Specific Constraints

- **Dimensional analysis**: Ensure expressions have correct physical units
- **Nested operator limits**: Prevent pathological cases like `sin(sin(sin(...)))`
- **Custom validity checks**: Domain-specific rules about valid expressions

### Why Constraints Matter

Constraints dramatically reduce the search space and prevent the algorithm from wasting time on obviously invalid expressions. They encode domain knowledge and physical laws, guiding the search toward meaningful solutions.

## Template Expressions: Structured Search

### Beyond Free-Form Search

Sometimes you know the general structure of the solution but not the details. Template expressions let you specify partial structure while allowing the algorithm to fill in the gaps.

### The #N Placeholder System

Template expressions use placeholders like `#1`, `#2`, etc. to represent sub-expressions that the algorithm will discover:

```julia
# Template: a * #1 + b * #2
# The algorithm searches for expressions to substitute for #1 and #2
# while optimizing constants a and b
```

### When to Use Templates

Templates are powerful when you have:

- **Theoretical insights**: You know the equation should have a certain form
- **Partial knowledge**: You know some terms but not others
- **Computational constraints**: Free-form search is too expensive
- **Domain structure**: Your field has common expression patterns

### Template Design Philosophy

Templates should capture essential structure while leaving room for discovery. Too restrictive and you might miss the true solution; too loose and you lose the benefits of structure.

## Understanding the Search Process

### Why Search is Hard

The space of mathematical expressions is:

- **Infinite**: There's no upper bound on expression complexity
- **Discrete**: Small changes (like `x*y` to `x/y`) can have huge effects
- **Non-smooth**: Similar expressions can have very different behaviors
- **Multimodal**: Many local optima separated by valleys of poor solutions

### How the Algorithm Addresses These Challenges

1. **Multi-population search**: Explores multiple regions simultaneously
2. **Temperature control**: Balances exploration and exploitation
3. **Pareto optimization**: Avoids getting stuck on accuracy alone
4. **Constant optimization**: Handles the continuous aspects efficiently
5. **Simplification**: Reduces redundancy and canonicalizes expressions

### Success Factors

Symbolic regression works best when:

- **Data is relatively clean**: Extreme noise can mislead the search
- **True relationships exist**: The algorithm finds patterns that are actually there
- **Complexity is reasonable**: Extremely complex relationships are hard to discover
- **Domain knowledge is used**: Appropriate operators, constraints, and templates help
- **Sufficient computation**: More time and cores generally improve results

## Practical Implications

### Interpreting Results

- The Pareto frontier gives you choices, not a single answer
- Simpler expressions on the frontier often generalize better
- Multiple runs may find different valid solutions
- Domain expertise is crucial for choosing among candidates

### Common Pitfalls

- Overfitting to noise in the data
- Using inappropriate operators for your domain
- Not running long enough to find good solutions
- Ignoring simpler expressions in favor of complex ones
- Misunderstanding the complexity-accuracy trade-off

### Best Practices

- Start with simple operators and gradually add complexity
- Use domain knowledge to set appropriate constraints
- Run multiple independent searches
- Validate results on held-out data
- Consider the entire Pareto frontier, not just the "best" expression

This conceptual foundation prepares you to use SymbolicRegression.jl effectively. The algorithm provides a principled way to search the vast space of mathematical expressions, balancing the competing demands of accuracy and interpretability that are central to scientific modeling.
