# [SR.jl](https://github.com/MilesCranmer/SR)

Check out [PySR](https://github.com/MilesCranmer/PySR) for
a Python frontend.

[Cite this software](https://github.com/MilesCranmer/PySR/blob/master/CITATION.md)

[Python documentation](https://pysr.readthedocs.io/)


# Quickstart

Install with:
```
using Pkg
Pkg.add(url="https://github.com/MilesCranmer/SR.jl.git")
```


Run distributed on four processes with:
```
julia -p 4
```

Then,
```julia
using SR

X = randn(Float32, 100, 5)
y = 2 * cos.(X[:, 4]) + X[:, 1] .^ 2 .- 2

RunSR(X, y, 100, Options())
```

Default options:

```julia
    binops=[div, plus, mult],
    unaops=[exp, cos],
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
