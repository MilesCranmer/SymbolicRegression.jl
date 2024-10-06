# API

## MLJ interface

```@docs
SRRegressor
MultitargetSRRegressor
```

## equation_search

```@docs
equation_search
```

## Options

```@docs
Options
MutationWeights
```

## Printing

```@docs
string_tree
```

## Evaluation

```@docs
eval_tree_array
EvalOptions
```

## Derivatives

`SymbolicRegression.jl` can automatically and efficiently compute derivatives
of expressions with respect to variables or constants. This is done using
either `eval_diff_tree_array`, to compute derivative with respect to a single
variable, or with `eval_grad_tree_array`, to compute the gradient with respect
all variables (or, all constants). Both use forward-mode automatic, but use
`Zygote.jl` to compute derivatives of each operator, so this is very efficient.

```@docs
eval_diff_tree_array
eval_grad_tree_array
```

## SymbolicUtils.jl interface

```@docs
node_to_symbolic
```

Note that use of this function requires `SymbolicUtils.jl` to be installed and loaded.

## Pareto frontier

```@docs
calculate_pareto_frontier
```
