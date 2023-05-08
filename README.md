

# Symbolic Regression with physical constraints

Symbolic Regression is a multi-objective optimization machine learning technique used to fit tabular data to symbolic equations, trying to find the most fit equation while mainting low complexity. In this repository Evolutionary Symbolic Regression is performed. 

This repository provides a modified version of the [SymbolicRegression.jl](https://github.com/MilesCranmer/SymbolicRegression.jl) package to incorporate physical constraints in the search process, as well as implementing a Query by Committee (QBC) approach to improve the model's performance. The modified SymbolicRegression package must be installed to use the modified loss functions. Visit the original repository for more information: [SymbolicRegression.jl](https://github.com/MilesCranmer/SymbolicRegression.jl). Changes are based on the topics discussed at: [Issue#92](https://github.com/MilesCranmer/SymbolicRegression.jl/issues/92#issue-1208837650) and 
[Issue#162](https://github.com/MilesCranmer/SymbolicRegression.jl/issues/162#issuecomment-1340173784)



To install the modified version and the dependencies, open a Julia terminal and with the package manager enter:

```
(@v1.8) pkg> add 'https://github.com/Jgmedina95/SRwPhysConsWL.git'
(@v1.8) pkg> add Statistics,StatsBase,Combinatorics,Random,InvertedIndices,Noise,Distributions,DataFrames,LinearAlgebra,CSV,


```
Clone this repository and navigate to the `paper` directory:

```
shell> git clone https://github.com/Jgmedina95/SRwPhysConsWL.git

shell> cd SRwPhysConsWL/paper/
```


## Quick Start

This example demonstrates how to use the modified package for Equation I.13.4 from the [Feynman dataset](https://space.mit.edu/home/tegmark/aifeynman.html).

$$ \frac{1}{2} m *(u^2 + v^2 + w^2) $$
 
1.- Include necessary dependencies:
```
include("QBC.jl")
include("PhConstraints.jl")
include("CommitteeEval.jl")
include("SR_with_constraints.jl")

using .QBC: load_data, samplenewdata
using .ConstraintsModule: select_constraint 
using .SRwithConstraints: regression_with_constraints, regression_with_qbc

using SymbolicRegression
```
2.- Load the dataset. Equation I.13.4 is used because it has a nice symmetry between features `u`, `v` and `w`. 
```
data = load_data("I.13.4")
```
```data.X``` contains the features and ```data.y``` contains the labels.

3.- Set up physical constraints:
```
sym_loss = select_constraint("symmetry", lambda=20, vars=[[2,3,4]])
```

4.-Configure the symbolic regression package:

```
options_with_constraints = SymbolicRegression.Options(
           binary_operators=[+, *, /, -],
           unary_operators = [inv,square],
           npopulations=100,
           custom_loss_function = sym_loss,
           stateReturn = true
           )
```
```
options_without_constraints = SymbolicRegression.Options(
           binary_operators=[+, *, /, -],
           unary_operators = [inv,square],
           npopulations=100,
           stateReturn = false
           )
```

5.- Perform two-phase optimization with the modified package using the provided framework:


I will sample 15 datapoints randomly as the original dataset has 1,000,000 points.
```
train_X, train_y, index = samplenewdata(data,15)
```
Then we can run the process with 100 iterations. The `split=0.1` indicates that 10 iterations will be with our custom `sym_loss` and the rest with the default loss. It will run until the error is 1e-5 or 5 iterations are completed. 

```
hof = regression_with_constraints(train_X,train_Y,100,options_with_constraints,options_without_constraints,0.1,max_loops=5,target_error = 1e-6,convergence_jump = 1e-4)
```
Of course, we are only using 15 out of 10e6 points so we can model a 'real' experiment where we decide what point to experiment next. This continues until `max_qbc_iterations` are reached or until convergence is found.

```
hof = regression_with_qbc(train_X,train_y,data.X,data.y,100,options_with_constraints,options_without_constraints,0.1;target_error = 1e-6, convergence_jump=1e-4, max_qbc_iterations = 5)
```

## Functions Description

Unless lambda is small, in my experience, the constraint doesnt allow for easy convergence. Therefore, I recommend to do a two step optimization. First with the constraint and then freely (only guided by MRSE). For this i've set a simple framework using the functions  `regression_with_constraints`
or `regression_with_qbc`

`regression_with_constraints` will operate on the specified data for as many loops as specified in `max_loops`, or until convergence is achieved.

On the other hand, `regression_with_qbc` works similarly to `regression_with_constraints`, but with an additional feature. If the algorithm does not converge during a run, a new point is added to the dataset from the sample pool using the Query by Committee (QBC) active learning strategy. This can potentially help in achieving better convergence and model performance or helps to determine what new point will bring more information. 


### Regression_with_constraints

The ```regression_with_constraints``` function is a Julia implementation for performing symbolic regression with a two-phase optimization process. The function helps to guide the search for an appropriate symbolic expression that models the data by iteratively running the symbolic regression with two sets of options and a split value that determines the proportion of iterations for each phase.

Function signature
```

function regression_with_constraints(train_X, train_y, niterations, options_with_constraints, options_without_constraints, split; max_loops=nothing, target_error=nothing, convergence_jump = nothing)

```

Arguments

* train_X: The input data matrix, where each row represents a sample and each column represents a feature.
* train_y: The target values (output) for each sample in the input data matrix.
* niterations: The total number of iterations for the optimization process.
* options_with_constraints: A set of options for the first phase of the optimization process.
* options_without_constraints: A set of options for the second phase of the optimization process.
* split: A value between 0 and 1 (exclusive) representing the proportion of iterations allocated to the first phase of the optimization process.

### Regression_with_qbc
The `regression_with_qbc` function is a Julia implementation for performing symbolic regression with a two-phase optimization process and QBC active learning. The function iteratively runs the symbolic regression with two sets of options and a split value that determines the proportion of iterations for each phase, and selects new data points to be added to the training set based on the committee's disagreement measure.

Function signature
```
function regression_with_qbc(train_X, train_y, sample_X, sample_y, niterations, options_with_constraints, options_without_constraints, split; max_loops=nothing, target_error=nothing, convergence_jump = nothing, max_qbc_iterations=nothing, disagreement_measure = "IBMD")

```
Arguments

* train_X: The input data matrix for training, where each row represents a sample and each column represents a feature.
* train_y: The target values (output) for each sample in the input data matrix for training.
* sample_X: The input data matrix for the sample points considered by the QBC.
* sample_y: The target values (output) for each sample in the input data matrix for the sample points.
* niterations: The total number of iterations for the optimization process.
* options_with_constraints: A set of options for the first phase of the optimization process.
* options_without_constraints: A set of options for the second phase of the optimization process.
* split: A value between 0 and 1 (exclusive) representing the proportion of iterations allocated to the first phase of the optimization process.

Optional arguments

* max_loops: Maximum number of loops for the iterative process (default: no limit).
* target_error: Target error value to stop the iterative process when reached (default: no target error specified).
* convergence_jump: The jump in the error ratio that, when reached, indicates the search process has converged (default: no convergence jump specified).
* max_qbc_iterations: Maximum number of QBC iterations (default: no limit).
* disagreement_measure: The disagreement measure used in QBC (default: "IBMD").

Returns

The function returns the Hall of Fame (hof) object after it converges or the max number of iterations are done. 

### Select Constraint

The `custom_loss`, can be defined with the function ```select_constraint```. The select_constraint function allows users to select a specific type of constraint to be applied in the symbolic regression process. The function currently supports three constraint types: "symmetry", "divergency1", and "divergencya-b".
```
function select_constraint(typeofconstraint::AbstractString; lambda=100, vars)
```
Parameters

* typeofconstraint: A string representing the type of constraint to be applied. It can be one of the following:
  - "symmetry"
  - "divergency1"
  - "divergencya-b"
* lambda: A regularization hyperparameter to control the balance between the predictive loss and constraint loss. Default is 100.
* vars: A list of lists containing variables or pairs/groups of variables that should be considered in the constraint application.

#### Example
```
Symm_loss = select_constraint("symmetry", lambda=100, vars=[[1,2],[3,4]])

```
Will define the function Symm_loss, with a hyperparameter value = 100. If lambda =0 it will be as the RMSE loss.  The vars arguments state that features 1-2 and 3-4 are considered to have symmetry between them (e.g. swapping them in the equation should yield an equivalent equation)

For even more information on the original package this changes are built upon see [documentation](https://astroautomata.com/SymbolicRegression.jl/stable/api/#Options)
