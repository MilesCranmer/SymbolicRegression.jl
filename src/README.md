If you are looking for the main loop, start with `function _EquationSearch` in `SymbolicRegression.jl`. You can proceed from there.
All functions are imported at the top using `import {filename}Module` syntax, which should help you navigate the codebase.

If you are looking to add a new parameter, add a new attribute to the `Options` struct in `OptionsStruct.jl`.
Then, add a new argument to the `Options` function in `Options.jl`, and pass that argument to the constructor at the bottom of the function.
That parameter will then be available any where `Options` is used.

If you are trying to pass a function as a parameter, things get a bit complicated.
Check out the function `move_functions_to_workers` in `Configure.jl` to see how functions are passed to workers.

The file system is structured as follows. Indentation
shows dependencies.

```
==============================================
ProgramConstants.jl (`maxdegree, CONST_TYPE`)
OptionsStruct.jl
Operators.jl
Dataset.jl (`Dataset`)
    Equation.jl (`Node`)
    Options.jl
=============================================/ Core.jl
Core.jl
Utils.jl
        EquationUtils.jl
        EvaluateEquation.jl
            CheckConstraints.jl
            MutationFunctions.jl
            EvaluateEquationDerivative.jl
                LossFunctions.jl
                    PopMember.jl
                        Population.jl
                        HallOfFame.jl
                        ConstantOptimization.jl

        InterfaceSymbolicUtils.jl
            CustomSymbolicUtilsSimplification.jl

                    SimplifyEquation.jl
                        Mutate.jl
                            RegularizedEvolution.jl
                                SingleIteration.jl
                                    SymbolicRegression.jl <= Deprecates.jl, Configure.jl
```
