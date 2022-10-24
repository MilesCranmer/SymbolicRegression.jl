using SymbolicRegression
using Test

# Deprecated kwargs should still work:
options = Options(;
    mutationWeights=MutationWeights(; mutate_constant=0.0),
    fractionReplacedHof=0.01f0,
    shouldOptimizeConstants=true,
)

@test options.mutation_weights.mutate_constant == 0.0
@test options.fraction_replaced_hof == 0.01f0
@test options.should_optimize_constants == true

options = Options(; mutationWeights=[1.0 for i in 1:8])
@test options.mutation_weights.add_node == 0.0
