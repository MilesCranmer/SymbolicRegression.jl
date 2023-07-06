<div align="center">

SymbolicRegression.jl searches for symbolic expressions which optimize a particular objective.

https://github.com/MilesCranmer/SymbolicRegression.jl/assets/7593028/f5b68f1f-9830-497f-a197-6ae332c94ee0

| Latest release | Documentation | Forums | Paper |
| :---: | :---: | :---: | :---: |
| [![version](https://juliahub.com/docs/SymbolicRegression/version.svg)](https://juliahub.com/ui/Packages/SymbolicRegression/X2eIS) | [![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://astroautomata.com/SymbolicRegression.jl/dev/) | [![Discussions](https://img.shields.io/badge/discussions-github-informational)](https://github.com/MilesCranmer/PySR/discussions) | [![Paper](https://img.shields.io/badge/arXiv-2305.01582-b31b1b)](https://arxiv.org/abs/2305.01582) |

| Build status | Coverage |
| :---: | :---: |
| [![CI](https://github.com/MilesCranmer/SymbolicRegression.jl/workflows/CI/badge.svg)](.github/workflows/CI.yml) | [![Coverage Status](https://coveralls.io/repos/github/MilesCranmer/SymbolicRegression.jl/badge.svg?branch=master)](https://coveralls.io/github/MilesCranmer/SymbolicRegression.jl?branch=master) |


Check out [PySR](https://github.com/MilesCranmer/PySR) for
a Python frontend.
[Cite this software](https://arxiv.org/abs/2305.01582)

</div>

## Quickstart

Install in Julia with:
```julia
using Pkg
Pkg.add("SymbolicRegression")
```

### MLJ Interface

The easiest way to use SymbolicRegression.jl
is with [MLJ](https://github.com/alan-turing-institute/MLJ.jl).
Let's see an example:

```julia
import SymbolicRegression: SRRegressor
import MLJ: machine, fit!, predict, report

# Create dataset with three features and one target:
X = (;
        a = rand(500) * 20,
        b = rand(500) * 3,
    gamma = randn(500)
)
y = [2 * cos(X.a[i]) - X.b[i] ^ 2 + 0.9 * X.gamma[i] for i=1:500]

# Add some noise:
y = y + randn(500) * 1e-3

model = SRRegressor(
    niterations=50,
    binary_operators=[+, -, *],
    unary_operators=[cos],
)
```

Now, let's create and train a machine on our data:

```julia
mach = machine(model, X, y)

fit!(mach)
```

You will notice that expressions are printed
using the column names of our table. If
a simple array is passed instead (e.g., `X=randn(100, 2)`),
`x1, ..., xn` will be used for variable names.

Let's look at the expressions discovered:

```julia
report(mach)
```

Finally, we can make predictions with the expressions
on new data:

```julia
predict(mach, X)
```

This will make predictions using the expression
selected using the function passed to `selection_method`.
By default this selection is made a mix of accuracy and complexity.
For example, we can make predictions using expression 2 with:

```julia
mach.model.selection_method = Returns(2)
predict(mach, X)
```

For fitting multiple outputs, one can use `MultitargetSRRegressor`.
For a full list of options available to each regressor, see the [API page](https://astroautomata.com/SymbolicRegression.jl/dev/api/).

### Low-Level Interface

The heart of SymbolicRegression.jl is the
`equation_search` function.
This takes a 2D array and attempts
to model a 1D array using analytic functional forms.
**Note:** unlike the MLJ interface,
this assumes column-major input of shape [features, rows].

```julia
import SymbolicRegression: Options, equation_search

X = randn(2, 100)
y = 2 * cos.(X[2, :]) + X[1, :] .^ 2 .- 2

options = Options(
    binary_operators=[+, *, /, -],
    unary_operators=[cos, exp],
    npopulations=20
)

hall_of_fame = equation_search(
    X, y, niterations=40, options=options,
    parallelism=:multithreading
)
```
You can view the resultant equations in the dominating Pareto front (best expression
seen at each complexity) with:
```julia
import SymbolicRegression: calculate_pareto_frontier

dominating = calculate_pareto_frontier(hall_of_fame)
```
This is a vector of `PopMember` type - which contains the expression along with the score.
We can get the expressions with:
```julia
trees = [member.tree for member in dominating]
```
Each of these equations is a `Node{T}` type for some constant type `T` (like `Float32`).

You can evaluate a given tree with:
```julia
import SymbolicRegression: eval_tree_array

tree = trees[end]
output, did_succeed = eval_tree_array(tree, X, options)
```
The `output` array will contain the result of the tree at each of the 100 rows.
This `did_succeed` flag detects whether an evaluation was successful, or whether
encountered any NaNs or Infs during calculation (such as, e.g., `sqrt(-1)`).


## Constructing trees

You can also manipulate and construct trees directly. For example:

```julia
import SymbolicRegression: Options, Node, eval_tree_array

options = Options(;
    binary_operators=[+, -, *, ^, /], unary_operators=[cos, exp, sin]
)
x1, x2, x3 = [Node(; feature=i) for i=1:3]
tree = cos(x1 - 3.2 * x2) - x1^3.2
```
This tree has `Float64` constants, so the type of the entire tree
will be promoted to `Node{Float64}`.

We can convert all constants (recursively) to `Float32`:
```julia
float32_tree = convert(Node{Float32}, tree)
```
We can then evaluate this tree on a dataset:
```julia
X = rand(Float32, 3, 100)
output, did_succeed = eval_tree_array(tree, X, options)
```

## Exporting to SymbolicUtils.jl

We can view the equations in the dominating
Pareto frontier with:
```julia
dominating = calculate_pareto_frontier(hall_of_fame)
```
We can convert the best equation
to [SymbolicUtils.jl](https://github.com/JuliaSymbolics/SymbolicUtils.jl)
with the following function:
```julia
import SymbolicRegression: node_to_symbolic

eqn = node_to_symbolic(dominating[end].tree, options)
println(simplify(eqn*5 + 3))
```

We can also print out the full pareto frontier like so:
```julia
import SymbolicRegression: compute_complexity, string_tree

println("Complexity\tMSE\tEquation")

for member in dominating
    complexity = compute_complexity(member, options)
    loss = member.loss
    string = string_tree(member.tree, options)

    println("$(complexity)\t$(loss)\t$(string)")
end
```

## Code structure

SymbolicRegression.jl is organized roughly as follows.
Rounded rectangles indicate objects, and rectangles indicate functions.
> (if you can't see this diagram being rendered, try pasting it into [mermaid-js.github.io/mermaid-live-editor](https://mermaid-js.github.io/mermaid-live-editor))

```mermaid
flowchart TB
    op([Options])
    d([Dataset])
    op --> ES
    d --> ES
    subgraph ES[equation_search]
        direction TB
        IP[sr_spawner]
        IP --> p1
        IP --> p2
        subgraph p1[Thread 1]
            direction LR
            pop1([Population])
            pop1 --> src[s_r_cycle]
            src --> opt[optimize_and_simplify_population]
            opt --> pop1
        end
        subgraph p2[Thread 2]
            direction LR
            pop2([Population])
            pop2 --> src2[s_r_cycle]
            src2 --> opt2[optimize_and_simplify_population]
            opt2 --> pop2
        end
        pop1 --> hof
        pop2 --> hof
        hof([HallOfFame])
        hof --> migration
        pop1 <-.-> migration
        pop2 <-.-> migration
        migration[migrate!]
    end
    ES --> output([HallOfFame])
```

The `HallOfFame` objects store the expressions with the lowest loss seen at each complexity.

The dependency structure of the code itself is as follows:

```mermaid
stateDiagram-v2
    AdaptiveParsimony --> Mutate
    AdaptiveParsimony --> Population
    AdaptiveParsimony --> RegularizedEvolution
    AdaptiveParsimony --> SingleIteration
    AdaptiveParsimony --> SymbolicRegression
    CheckConstraints --> Mutate
    CheckConstraints --> SymbolicRegression
    Complexity --> CheckConstraints
    Complexity --> HallOfFame
    Complexity --> LossFunctions
    Complexity --> Mutate
    Complexity --> Population
    Complexity --> SearchUtils
    Complexity --> SingleIteration
    Complexity --> SymbolicRegression
    ConstantOptimization --> Mutate
    ConstantOptimization --> SingleIteration
    Core --> AdaptiveParsimony
    Core --> CheckConstraints
    Core --> Complexity
    Core --> ConstantOptimization
    Core --> HallOfFame
    Core --> InterfaceDynamicExpressions
    Core --> LossFunctions
    Core --> Migration
    Core --> Mutate
    Core --> MutationFunctions
    Core --> PopMember
    Core --> Population
    Core --> Recorder
    Core --> RegularizedEvolution
    Core --> SearchUtils
    Core --> SingleIteration
    Core --> SymbolicRegression
    Dataset --> Core
    HallOfFame --> SearchUtils
    HallOfFame --> SingleIteration
    HallOfFame --> SymbolicRegression
    InterfaceDynamicExpressions --> LossFunctions
    InterfaceDynamicExpressions --> SymbolicRegression
    LossFunctions --> ConstantOptimization
    LossFunctions --> HallOfFame
    LossFunctions --> Mutate
    LossFunctions --> PopMember
    LossFunctions --> Population
    LossFunctions --> SymbolicRegression
    Migration --> SymbolicRegression
    Mutate --> RegularizedEvolution
    MutationFunctions --> Mutate
    MutationFunctions --> Population
    MutationFunctions --> SymbolicRegression
    Operators --> Core
    Operators --> Options
    Options --> Core
    OptionsStruct --> Core
    OptionsStruct --> Options
    PopMember --> ConstantOptimization
    PopMember --> HallOfFame
    PopMember --> Migration
    PopMember --> Mutate
    PopMember --> Population
    PopMember --> RegularizedEvolution
    PopMember --> SingleIteration
    PopMember --> SymbolicRegression
    Population --> Migration
    Population --> RegularizedEvolution
    Population --> SearchUtils
    Population --> SingleIteration
    Population --> SymbolicRegression
    ProgramConstants --> Core
    ProgramConstants --> Dataset
    ProgressBars --> SearchUtils
    ProgressBars --> SymbolicRegression
    Recorder --> Mutate
    Recorder --> RegularizedEvolution
    Recorder --> SingleIteration
    Recorder --> SymbolicRegression
    RegularizedEvolution --> SingleIteration
    SearchUtils --> SymbolicRegression
    SingleIteration --> SymbolicRegression
    Utils --> CheckConstraints
    Utils --> ConstantOptimization
    Utils --> Options
    Utils --> PopMember
    Utils --> SingleIteration
    Utils --> SymbolicRegression
```


Bash command to generate dependency structure from `src` directory (requires `vim-stream`):
```bash
echo 'stateDiagram-v2'
IFS=$'\n'
for f in *.jl; do
    for line in $(cat $f | grep -e 'import \.\.' -e 'import \.'); do
        echo $(echo $line | vims -s 'dwf:d$' -t '%s/^\.*//g' '%s/Module//g') $(basename "$f" .jl);
    done;
done | vims -l 'f a--> ' | sort
```



## Search options

See https://astroautomata.com/SymbolicRegression.jl/stable/api/#Options

