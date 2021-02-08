# [SymbolicRegression.jl](https://github.com/MilesCranmer/SymbolicRegression.jl)

[![.github/workflows/CI.yml](https://github.com/MilesCranmer/SymbolicRegression.jl/workflows/.github/workflows/CI.yml/badge.svg)](.github/workflows/CI.yml)
[![Coverage Status](https://coveralls.io/repos/github/MilesCranmer/SymbolicRegression.jl/badge.svg?branch=master)](https://coveralls.io/github/MilesCranmer/SymbolicRegression.jl?branch=master)

Distributed High-Performance symbolic regression in Julia.

Check out [PySR](https://github.com/MilesCranmer/PySR) for
a Python frontend.

[Cite this software](https://github.com/MilesCranmer/PySR/blob/master/CITATION.md)

[Python documentation](https://pysr.readthedocs.io/)


# Quickstart

Install in Julia with:
```julia
using Pkg
Pkg.add("SymbolicRegression")
```

The heart of this package is the
`EquationSearch` function, which takes
a 2D array (shape [features, rows]) and attempts
to model a 1D array (shape [rows])
using analytic functional forms.

Run distributed on four processes with:
```julia
using SymbolicRegression

X = randn(Float32, 5, 100)
y = 2 * cos.(X[4, :]) + X[1, :] .^ 2 .- 2

options = SymbolicRegression.Options(
    binary_operators=(+, *, /, -),
    unary_operators=(cos, exp),
    npopulations=20
)

hallOfFame = EquationSearch(X, y, niterations=5, options=options, numprocs=4)
```
We can view the equations in the dominating
Pareto frontier with:
```julia
dominating = calculateParetoFrontier(X, y, hallOfFame, options)
```
We can convert the best equation
to [SymbolicUtils.jl](https://github.com/JuliaSymbolics/SymbolicUtils.jl)
with the following function:
```julia
eqn = node_to_symbolic(dominating[end].tree, options)
println(simplify(eqn*5 + 3))
```

We can also print out the full pareto frontier like so:
```julia
println("Complexity\tMSE\tEquation")

for member in dominating
    size = countNodes(member.tree)
    score = member.score
    string = stringTree(member.tree, options)

    println("$(size)\t$(score)\t$(string)")
end
```



# Options

- `binary_operators` **tuple** of Julia operators taking two scalar reals
    as arguments. Some are pre-defined in `operator.jl`.
- `unary_operators` Same but for operators taking a single real as
    input.
- `npopulations` int, Number of populations running; by default=procs.
- `niterations` int, Number of iterations of the algorithm to run. The best
    equations are printed, and migrate between populations, at the
    end of each.
- `ncyclesperiteration` int, Number of total mutations to run, per 10
    samples of the population, per iteration.
- `alpha` float, Initial temperature.
- `annealing` bool, Whether to use annealing. You should (and it is default).
- `fractionReplaced` float, How much of population to replace with migrating
    equations from other populations.
- `fractionReplacedHof` float, How much of population to replace with migrating
    equations from hall of fame.
- `npop` int, Number of individuals in each population
- `parsimony` float, Multiplicative factor for how much to punish complexity.
- `migration` bool, Whether to migrate.
- `hofMigration` bool, Whether to have the hall of fame migrate.
- `shouldOptimizeConstants` bool, Whether to numerically optimize
    constants (Nelder-Mead/Newton) at the end of each iteration.
- `topn` int, How many top individuals migrate from each population.
- `nrestarts` int, Number of times to restart the constant optimizer
- `perturbationFactor` float, Constants are perturbed by a max
    factor of (perturbationFactor*T + 1). Either multiplied by this
    or divided by this.
- `mutationWeights` list:
    - `weightMutateConstant`
    - `weightMutateOperator`
    - `weightAddNode`
    - `weightInsertNode`
    - `weightDeleteNode`
    - `weightSimplify`
    - `weightRandomize`
    - `weightDoNothing`
- `hofFile` str, Where to save the files (.csv separated by |)
- `maxsize` int, Max size of an equation.
- `maxdepth` int, Max depth of an equation. You can use both maxsize and maxdepth.
    maxdepth is by default set to = maxsize, which means that it is redundant.
- `fast_cycle` bool, (experimental) - batch over population subsamples. This
    is a slightly different algorithm than regularized evolution, but does cycles
    15% faster. May be algorithmically less efficient.
- `batching` bool, whether to compare population members on small batches
    during evolution. Still uses full dataset for comparing against
    hall of fame.
- `batchSize` int, the amount of data to use if doing batching.
- `warmupMaxsize` int, whether to slowly increase max size from
    a small number up to the maxsize (if greater than 0).
    If greater than 0, says how many cycles before the maxsize
    is increased.
- `useFrequency` bool, whether to measure the frequency of complexities,
    and use that instead of parsimony to explore equation space. Will
    naturally find equations of all complexities.

Default options:

```julia
    binary_operators=(div, plus, mult),
    unary_operators=(exp, cos),
    una_constraints=nothing,
    bin_constraints=nothing,
    ns=10,
    parsimony=0.000100f0,
    alpha=0.100000f0,
    maxsize=20,
    maxdepth=nothing,
    fast_cycle=false,
    migration=true,
    hofMigration=true,
    fractionReplacedHof=0.1f0,
    shouldOptimizeConstants=true,
    hofFile=nothing,
    npopulations=nothing,
    nrestarts=3,
    perturbationFactor=1.000000f0,
    annealing=true,
    weighted=false,
    batching=false,
    batchSize=50,
    useVarMap=false,
    mutationWeights=[10.000000, 1.000000, 1.000000, 3.000000, 3.000000, 0.010000, 1.000000, 1.000000],
    warmupMaxsize=0,
    limitPowComplexity=false,
    useFrequency=false,
    npop=1000,
    ncyclesperiteration=300,
    fractionReplaced=0.1f0,
    topn=10,
    verbosity=convert(Int, 1e9),
    probNegate=0.01f0,
    printZeroIndex=false
```
