@testitem "Test migration" begin
    using SymbolicRegression
    using SymbolicRegression: strip_metadata
    using DynamicExpressions: get_tree
    using Test
    using Random: seed!

    seed!(0)

    X = randn(5, 100);
    y = X[2, :] .* 3.2 .+ X[3, :] .+ 2.0;

    options = Options();
    dataset = Dataset(X, y)
    plugin_states = SymbolicRegression.init_plugin_states(options, dataset)
    population1 = Population(
        X, y; population_size=100, options=options, nfeatures=5, nlength=10, plugin_states
    )

    tree = Node(1, Node(; val=1.0), Node(; feature=2) * 3.2)

    @test !(hash(tree) in [hash(p.tree) for p in population1.members])

    ex = @parse_expression(
        $tree, operators = options.operators, variable_names = [:x1, :x2],
    )
    ex = strip_metadata(ex, options, dataset)

    SymbolicRegression.MigrationModule.migrate!(
        [PopMember(ex, 0.0, Inf, options; deterministic=false)] => population1,
        options;
        frac=0.5,
    )

    # Now we see that the tree is in the population:
    @test tree in [get_tree(p.tree) for p in population1.members]

    # Passing populations draws exactly as passing their concatenated members.
    sources = [
        Population(X, y; population_size=4, options, nfeatures=5, nlength=3, plugin_states)
        for _ in 1:3
    ]
    destinations = [copy(population1) for _ in 1:2]
    seed!(1)
    SymbolicRegression.MigrationModule.migrate!(
        sources => destinations[1], options; frac=0.5
    )
    seed!(1)
    SymbolicRegression.MigrationModule.migrate!(
        [m for pop in sources for m in pop.members] => destinations[2], options; frac=0.5
    )
    trees(pop) = [get_tree(m.tree) for m in pop.members]
    @test trees(destinations[1]) == trees(destinations[2])
    @test trees(destinations[1]) != trees(population1)
end
