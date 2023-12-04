using SymbolicRegression
using Test

options = Options(; binary_operators=[+, -, *, /], unary_operators=[cos, sin])

x1, x2, x3 = [GraphNode(Float64; feature=i) for i in 1:3]

base_tree = cos(x1 - 3.2) * x2 - x3 * copy(x3)
tree = sin(base_tree) + base_tree

dataset = Dataset(randn(3, 50), randn(50))

tree(dataset.X, options)

eval_tree_array(tree, dataset.X, options)

@test compute_complexity(tree, options) == 12
@test compute_complexity(tree, options; break_sharing=Val(true)) == 22

pop = Population(
    dataset; nlength=3, options, nfeatures=3, node_type=GraphNode, population_size=100
)

equation_search([dataset]; options, node_type=GraphNode)
