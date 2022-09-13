
If you are looking for the main loop, start with `function _EquationSearch` in `SymbolicRegression.jl`. You can proceed from there.
All functions are imported at the top using `import {filename}Module` syntax, which should help you navigate the codebase.

The dependency structure is as follows:

```mermaid
stateDiagram-v2
Core --> CheckConstraints
EquationUtils --> CheckConstraints
Core --> ConstantOptimization
Utils --> ConstantOptimization
EquationUtils --> ConstantOptimization
LossFunctions --> ConstantOptimization
PopMember --> ConstantOptimization
ProgramConstants --> Core
Dataset --> Core
OptionsStruct --> Core
Equation --> Core
Options --> Core
Operators --> Core
ProgramConstants --> Dataset
ProgramConstants --> Equation
OptionsStruct --> Equation
Core --> EquationUtils
Core --> EvaluateEquation
Utils --> EvaluateEquation
EquationUtils --> EvaluateEquation
Core --> EvaluateEquationDerivative
Utils --> EvaluateEquationDerivative
EquationUtils --> EvaluateEquationDerivative
EvaluateEquation --> EvaluateEquationDerivative
Core --> HallOfFame
EquationUtils --> HallOfFame
PopMember --> HallOfFame
LossFunctions --> HallOfFame
Core --> InterfaceSymbolicUtils
Utils --> InterfaceSymbolicUtils
Core --> LossFunctions
EquationUtils --> LossFunctions
EvaluateEquation --> LossFunctions
Core --> Mutate
EquationUtils --> Mutate
LossFunctions --> Mutate
CheckConstraints --> Mutate
PopMember --> Mutate
MutationFunctions --> Mutate
SimplifyEquation --> Mutate
Recorder --> Mutate
Core --> MutationFunctions
EquationUtils --> MutationFunctions
Operators --> Options
Equation --> Options
OptionsStruct --> Options
Core --> PopMember
Utils --> PopMember
LossFunctions --> PopMember
Core --> Population
EquationUtils --> Population
LossFunctions --> Population
MutationFunctions --> Population
PopMember --> Population
Core --> Recorder
Core --> RegularizedEvolution
PopMember --> RegularizedEvolution
Population --> RegularizedEvolution
Mutate --> RegularizedEvolution
Recorder --> RegularizedEvolution
Core --> SimplifyEquation
CheckConstraints --> SimplifyEquation
Utils --> SimplifyEquation
Core --> SingleIteration
EquationUtils --> SingleIteration
Utils --> SingleIteration
SimplifyEquation --> SingleIteration
PopMember --> SingleIteration
Population --> SingleIteration
HallOfFame --> SingleIteration
RegularizedEvolution --> SingleIteration
ConstantOptimization --> SingleIteration
Recorder --> SingleIteration
Core --> SymbolicRegression
Utils --> SymbolicRegression
EquationUtils --> SymbolicRegression
EvaluateEquation --> SymbolicRegression
EvaluateEquationDerivative --> SymbolicRegression
CheckConstraints --> SymbolicRegression
MutationFunctions --> SymbolicRegression
LossFunctions --> SymbolicRegression
PopMember --> SymbolicRegression
Population --> SymbolicRegression
HallOfFame --> SymbolicRegression
SingleIteration --> SymbolicRegression
InterfaceSymbolicUtils --> SymbolicRegression
SimplifyEquation --> SymbolicRegression
ProgressBars --> SymbolicRegression
Recorder --> SymbolicRegression
Core --> Utils
```


Bash command to generate dependency structure from `src` directory (requires `vim-stream`):
```bash
echo 'stateDiagram-v2'
IFS=$'\n'
for f in *.jl; do
    for line in $(cat $f | grep -e 'import \.\.' -e 'import \.'); do
        echo $(echo $line | vims -s 'dwf:d$' -t '%s/^\.*//g' '%s/Module//g') $(basename "$f" .jl);
    done;
done | vims -l 'f a-->
```
