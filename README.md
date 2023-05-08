

## Search options

# Clone and Package Instalation
To use this code, the modified SymbolicRegression has to be installed in order to used the modified loss functions. 
Open a Julia terminal and install the package as:

```
(@v1.8) pkg> add('https://github.com/Jgmedina95/SRwPhysConsWL.git)

```
This is essentialy the same program as Miles' SymbolicRegression.jl https://github.com/MilesCranmer/SymbolicRegression.jl. I strongly recommend going through the repo. 

Clone the repo
'''
git clone https://github.com/Jgmedina95/SRwPhysConsWL.git

cd /SRwPhysConsWL/paper/

'''


# Example

Include dependencies to maka easier Extract the features and labels from the dataset. In this example we use Equation I.13.4. $1/2 m *(u^2 + v^2 + w^2)$ from the Feynman dataset. This equation is nice as it has four features and theres symmetry between three of them. Which means you could permute u, v and w and the function would not change.

```
julia> include("QBC.jl")
julia> include("PhConstraints.jl")
julia> include("CommitteeEval.jl")

julia> data = QBC.load_data("I.13.4")
```
This will have X features and y labels in data.X and data.y
In this example we will only use 15 to start and then add one point at a time with Query By Committee.

#Setting up physical constraints:

To set symmetry loss the "select_constraint" function is used. The hyperparameter lambda can be changed (lambda = 0 will results in the MRSE loss function). The vars parameter is to select which variables should have symmetry. (e.g. [[1,2],[3,4]] indicates theres symmetry with features 1-2 and 3-4). 
```
Symm_loss = ConstrainsData.select_constraint("symmetry",lambda=20,vars=[[2,3,4]])
```
With the loss function ready, now we can use the symbolic regression package normally, setting options
```
options = SymbolicRegression.Options(
           binary_operators=[+, *, /, -],
           unary_operators = [inv,square],
           npopulations=100,
           custom_loss_function = sym_loss)
```

Unless lambda is small, in my experience the constraint doesnt allow for easy convergence. Therefore, I recommend to do a two step optimization. First with the constraint and then freely (only guided by MRSE). For this ive set a simple framework using the function  ``` regression_with_constraints```


#Functions Description
### Regression_with_constraints

The ```regression_with_constraints``` function is a Julia implementation for performing symbolic regression with a two-phase optimization process. The function helps to guide the search for an appropriate symbolic expression that models the data by iteratively running the symbolic regression with two sets of options and a split value that determines the proportion of iterations for each phase.

Function signature
```function regression_with_constraints(train_X, train_y, niterations, options_constraints, options_without_constraints, split; max_loops=nothing, target_error=nothing, convergence_jump = nothing)
```

Arguments

* *train_X*: The input data matrix, where each row represents a sample and each column represents a feature.
* train_y: The target values (output) for each sample in the input data matrix.
* niterations: The total number of iterations for the optimization process.
* options_with_constraints: A set of options for the first phase of the optimization process.
* options_without_constraints: A set of options for the second phase of the optimization process.
* split: A value between 0 and 1 (exclusive) representing the proportion of iterations allocated to the first phase of the optimization process.

See https://astroautomata.com/SymbolicRegression.jl/stable/api/#Options

