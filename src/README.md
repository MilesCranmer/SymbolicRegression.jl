
If you are looking for the main loop, start with `function _EquationSearch` in `SymbolicRegression.jl`. You can proceed from there.
All functions are imported at the top using `import {filename}Module` syntax, which should help you navigate the codebase.

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

Bash command to generate dependency structure (requires `vim-stream`)
```bash
IFS=$'\n'
for f in *.jl; do
    for line in $(cat $f | grep -e 'import \.\.' -e 'import \.'); do
        echo $(basename "$f" .jl) $(echo $line | vims -s 'dwf:d$' -t '%s/^\.*//g' '%s/Module//g');
    done;
done | vims -l 'f a-> '
```
