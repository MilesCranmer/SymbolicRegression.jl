# SymbolicRegression.jl

| Latest release | Documentation | Build status | Coverage |
| --- | --- | --- | --- |
| [![version](https://juliahub.com/docs/SymbolicRegression/version.svg)](https://juliahub.com/ui/Packages/SymbolicRegression/X2eIS) | [![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://milescranmer.github.io/SymbolicRegression.jl/dev/) | [![CI](https://github.com/MilesCranmer/SymbolicRegression.jl/workflows/CI/badge.svg)](.github/workflows/CI.yml) | [![Coverage Status](https://coveralls.io/repos/github/MilesCranmer/SymbolicRegression.jl/badge.svg?branch=master)](https://coveralls.io/github/MilesCranmer/SymbolicRegression.jl?branch=master) |

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

# Contents

```@contents
Pages = ["api.md", "types.md"]
```
