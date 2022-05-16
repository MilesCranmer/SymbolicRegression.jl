println("Testing NaN detection.")

# Creating a NaN via computation.
tree = cos(exp(exp(exp(exp(Node("x1"))))))
X = randn(MersenneTwister(0), Float32, 1, 100) * 100.0f0
output, flag = eval_tree_array(tree, X, options)
@test !flag

# Creating a NaN/Inf via division by constant zero.
tree = cos(Node("x1") / 0.0f0)
output, flag = eval_tree_array(tree, X, options)
@test !flag

# Having a NaN/Inf constants:
tree = cos(Node("x1") + Inf)
output, flag = eval_tree_array(tree, X, options)
@test !flag
tree = cos(Node("x1") + NaN)
output, flag = eval_tree_array(tree, X, options)
@test !flag

println("Passed.")