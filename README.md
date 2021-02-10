# SymbolicRegression.jl

| Latest release | Documentation | Build status | Coverage |
| --- | --- | --- | --- |
| [![version](https://juliahub.com/docs/SymbolicRegression/version.svg)](https://juliahub.com/ui/Packages/SymbolicRegression/X2eIS) | [![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://milescranmer.github.io/SymbolicRegression.jl/dev/) [![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://milescranmer.github.io/SymbolicRegression.jl/stable/)  | [![CI](https://github.com/MilesCranmer/SymbolicRegression.jl/workflows/CI/badge.svg)](.github/workflows/CI.yml) | [![Coverage Status](https://coveralls.io/repos/github/MilesCranmer/SymbolicRegression.jl/badge.svg?branch=master)](https://coveralls.io/github/MilesCranmer/SymbolicRegression.jl?branch=master) |

Distributed High-Performance symbolic regression in Julia.

Check out [PySR](https://github.com/MilesCranmer/PySR) for
a Python frontend.

<img src="https://astroautomata.com/data/sr_demo_image1.png" alt="demo1" width="700"/> <img src="https://astroautomata.com/data/sr_demo_image2.png" alt="demo2" width="700"/>

[Cite this software](https://github.com/MilesCranmer/PySR/blob/master/CITATION.md)

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


## Search options

See https://milescranmer.github.io/SymbolicRegression.jl/stable/api/#Options
