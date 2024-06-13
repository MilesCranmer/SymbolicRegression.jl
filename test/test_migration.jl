using SymbolicRegression
using DynamicExpressions: get_tree
using Test
using Random: seed!

seed!(0)

X = randn(5, 100);
y = X[2, :] .* 3.2 .+ X[3, :] .+ 2.0;

options = Options();
population1 = Population(
    X, y; population_size=100, options=options, nfeatures=5, nlength=10
)

tree = Node(1, Node(; val=1.0), Node(; feature=2) * 3.2)

@test !(hash(tree) in [hash(p.tree) for p in population1.members])

ex = @parse_expression($tree, operators = options.operators, variable_names = [:x1, :x2],)

SymbolicRegression.MigrationModule.migrate!(
    [PopMember(ex, 0.0, Inf, options)] => population1, options; frac=0.5
)

# Now we see that the tree is in the population:
@test tree in [get_tree(p.tree) for p in population1.members]
