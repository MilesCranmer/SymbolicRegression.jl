The file system is structured as follows. Indentation
shows dependencies.

```
==============================================
ProgramConstants.jl (`maxdegree, CONST_TYPE`)
Operators.jl
Equation.jl (`Node`)
Dataset.jl (`Dataset`)
    Options.jl
=============================================/ Core.jl
Core.jl
Utils.jl
        EquationUtils.jl
        EvaluateEquation.jl
            CheckConstraints.jl
            MutationFunctions.jl
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
