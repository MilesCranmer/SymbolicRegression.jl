# Seed Expressions Feature Implementation

## Overview

I have successfully implemented a feature that allows users to provide "guesses" for seeding the search population in SymbolicRegression.jl. This feature enables users to provide string expressions that are parsed, optimized, and added to the hall of fame to guide the search.

## Key Implementation Details

### 1. New Parameter: `seed_expressions`

Added a new parameter `seed_expressions` to the `Options` struct:
- **Type**: `Union{Nothing,Vector{String}}`
- **Default**: `nothing` (no seeding)
- **Purpose**: Accept user-provided string expressions as initial guesses

### 2. New Module: `SeedExpressionsModule`

Created `src/SeedExpressions.jl` with the main function:

```julia
function process_seed_expressions!(
    hall_of_fame::HallOfFame{T,L,N},
    dataset::Dataset{T,L},
    options::AbstractOptions
) where {T<:DATA_TYPE,L<:LOSS_TYPE,N<:AbstractExpression{T}}
```

**Key Features:**
- **String Parsing**: Uses `DynamicExpressions.parse_expression` to convert user strings into expression trees
- **Variable Name Mapping**: Uses the same variable names as provided in the dataset
- **Constant Optimization**: Runs the parsed expressions through constant optimization to tune parameters
- **Hall of Fame Integration**: Adds optimized expressions directly to the hall of fame
- **Error Handling**: Gracefully handles parsing errors and continues with valid expressions
- **Verbosity Support**: Provides detailed logging when verbosity > 0

### 3. Integration Points

**Options Structure:**
- Added `seed_expressions` field to `Options` struct in `src/OptionsStruct.jl`
- Added parameter to Options constructor in `src/Options.jl` 
- Added documentation for the new parameter

**Search Process:**
- Integrated into `_initialize_search!` function in `src/SymbolicRegression.jl`
- Called immediately after hall of fame initialization
- Processes seed expressions for all output datasets

**Module System:**
- Added `include("SeedExpressions.jl")` to the module loading section
- Added `using .SeedExpressionsModule: process_seed_expressions!` import

### 4. Usage Example

```julia
using SymbolicRegression

# Create test data
X = [1.0 2.0 3.0 4.0 5.0; 
     0.5 1.0 1.5 2.0 2.5]'
y = X[:, 1] .* 2.0 .+ X[:, 2]

# Set up options with seed expressions
options = Options(
    binary_operators=[+, -, *, /],
    unary_operators=[sin, cos, exp, log],
    seed_expressions=["x1 + x2", "2.0 * x1", "x1 * 2.0 + x2"],
    verbosity=1
)

# Run symbolic regression
hall_of_fame = equation_search(
    X, y; 
    options=options,
    variable_names=["x1", "x2"]
)
```

### 5. Workflow

1. **User provides seed expressions**: As strings in the `seed_expressions` parameter
2. **Parsing**: Each string is parsed using `parse_expression` with the same operators and variable names
3. **Expression creation**: Parsed expressions are converted to the appropriate expression type for the codebase
4. **Population member creation**: Each expression becomes a `PopMember` with computed loss and cost
5. **Constant optimization**: If enabled, constants in the expressions are optimized using the existing optimization pipeline
6. **Hall of fame insertion**: Optimized expressions are added to the hall of fame using `update_hall_of_fame!`
7. **Natural migration**: Good seed expressions will naturally migrate into populations during the search process

### 6. Benefits

- **Domain Knowledge Integration**: Users can incorporate known functional forms or physical laws
- **Faster Convergence**: Good initial guesses can significantly speed up search
- **Improved Results**: Seeds provide a starting point for further optimization
- **Flexibility**: Accepts any valid mathematical expression using the defined operators
- **Robustness**: Graceful error handling for invalid expressions

### 7. Technical Features

- **Type Safety**: Full type parameter support for different data and loss types
- **Memory Efficient**: Only processes expressions when provided (no overhead when unused)
- **Operator Compatibility**: Uses the same operators defined in the Options
- **Variable Name Consistency**: Automatically uses dataset variable names
- **Complexity Aware**: Integrates with the existing complexity calculation system
- **Optimization Pipeline**: Leverages existing constant optimization infrastructure

## Documentation

Added comprehensive documentation including:
- Parameter description in the Options docstring
- Function-level documentation with examples
- Clear usage patterns and expected inputs

## Future Enhancements

Potential improvements that could be added:
1. **Expression validation**: Pre-validate expressions before parsing
2. **Batch processing**: More efficient handling of large numbers of seed expressions  
3. **Priority weighting**: Allow users to specify importance of different seeds
4. **Format flexibility**: Support for alternative input formats (LaTeX, etc.)

## Conclusion

This implementation provides a powerful and flexible way for users to seed the symbolic regression search with domain knowledge, while maintaining full compatibility with the existing SymbolicRegression.jl architecture and optimization pipeline.