using SymbolicRegression
using Test
using Random: seed!

seed!(0)

X = randn(5, 100);
y = X[2, :] .* 3.2 .+ X[3, :] .+ 2.0;

options = Options();
population1 = Population(X, y; npop=100, options=options, nfeatures=5, nlength=10)

tree = Node(1, Node(; val=1.0), Node(; feature=2) * 3.2)

@test !(hash(tree) in [hash(p.tree) for p in population1.members])

SymbolicRegression.MigrationModule.migrate!(
    [PopMember(tree, 0.0, Inf)] => population1, options; frac=0.5
)

# Now we see that the tree is in the population:
@test tree in [p.tree for p in population1.members]
