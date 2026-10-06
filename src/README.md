The main search loop is `_equation_search` in `search/EquationSearch.jl`.

Each folder has an assembly file that defines its module and includes its child modules:

- `interfaces/Interfaces.jl`: shared types and extension hooks.
- `config/Config.jl`: options, operators, weights, and plugin defaults.
- `expressions/Expressions.jl`: expression construction, representations, and macros.
- `evaluation/Evaluation.jl`: losses, complexity, constraints, and inverse evaluation.
- `evolution/Evolution.jl`: populations, mutations, crossovers, and optimization.
- `search/Search.jl`: search orchestration, logging, progress, and worker setup.
- `plugins/Plugins.jl`: concrete plugin implementations.

Module paths follow this layout. For example,
`SymbolicRegression.EvolutionModule.PopMemberModule` lives in `evolution/PopMember.jl`.
Methods that connect layers live in the folder implementing those methods.
`Utils.jl` is shared across the package and is included once at the top level.
Public names such as `SymbolicRegression.Options` remain unchanged; old module
paths are deprecated aliases in `deprecates.jl`.
