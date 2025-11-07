using SymbolicRegression

# Deprecated kwargs should still work:
options = Options(;
    mutationWeights=MutationWeights(; mutate_constant=0.0),
    fractionReplacedHof=0.01f0,
    shouldOptimizeConstants=true,
    loss=L2DistLoss(),
)

@test options.mutation_weights.mutate_constant == 0.0
@test options.fraction_replaced_hof == 0.01f0
@test options.should_optimize_constants == true
@test options.elementwise_loss == L2DistLoss()

options = Options(; mutationWeights=[1.0 for i in 1:8])
@test options.mutation_weights.add_node == 1.0

# Test score_func deprecation
X = randn(3, 5)
y = randn(5)
dataset = Dataset(X, y)
options = Options()
tree = Node(; val=1.0)

using SymbolicRegression: score_func, eval_cost

@test_deprecated score_func(dataset, tree, options) == eval_cost(dataset, tree, options)

# Test PopMember score deprecation warnings
X = randn(3, 5)
y = randn(5)
dataset = Dataset(X, y)
options = Options()
tree = Node(; val=1.0)
member = PopMember(dataset, tree, options; deterministic=true)

# Test that accessing .score triggers deprecation warning
@test_deprecated member.score
@test (@test_deprecated member.score) == member.cost

# Test that setting .score triggers deprecation warning
@test_deprecated member.score = 0.5
@test member.cost == 0.5
