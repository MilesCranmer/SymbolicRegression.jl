@testitem "GraphNode evaluation" tags = [:part1] begin
    using SymbolicRegression

    options = Options(;
        binary_operators=[+, -, *, /], unary_operators=[cos, sin], maxsize=30
    )

    x1, x2, x3 = [GraphNode(Float64; feature=i) for i in 1:3]

    base_tree = cos(x1 - 3.2) * x2 - x3 * copy(x3)
    tree = sin(base_tree) + base_tree

    X = randn(3, 50)
    z = @. cos(X[1, :] - 3.2) * X[2, :] - X[3, :] * X[3, :]
    y = @. sin(z) + z
    dataset = Dataset(X, y)

    tree(dataset.X, options)

    eval_tree_array(tree, dataset.X, options)
end

@testitem "GraphNode complexity" tags = [:part1] begin
    using SymbolicRegression

    options = Options(;
        binary_operators=[+, -, *, /], unary_operators=[cos, sin], maxsize=30
    )
    x1, x2, x3 = [GraphNode(Float64; feature=i) for i in 1:3]

    base_tree = cos(x1 - 3.2) * x2 - x3 * copy(x3)
    tree = sin(base_tree) + base_tree

    @test compute_complexity(tree, options) == 12
    @test compute_complexity(tree, options; break_sharing=Val(true)) == 22
end

@testitem "GraphNode population" tags = [:part1] begin
    using SymbolicRegression

    options = Options(;
        binary_operators=[+, -, *, /],
        unary_operators=[cos, sin],
        maxsize=30,
        node_type=GraphNode,
    )

    X = randn(3, 50)
    z = @. cos(X[1, :] - 3.2) * X[2, :] - X[3, :] * X[3, :]
    y = @. sin(z) + z
    dataset = Dataset(X, y)

    pop = Population(dataset; options, nlength=3, nfeatures=3, population_size=100)
    @test pop isa Population{T,T,<:Expression{T,<:GraphNode{T}}} where {T}

    # Seems to not work yet:
    # equation_search([dataset]; niterations=10, options)
end

@testitem "GraphNode break connection mutation" tags = [:part1] begin
    using SymbolicRegression
    using SymbolicRegression.MutationFunctionsModule: break_random_connection!
    using Random: MersenneTwister

    options = Options(;
        binary_operators=[+, -, *, /],
        unary_operators=[cos, sin],
        maxsize=30,
        node_type=GraphNode,
    )

    x1, x2, x3 = [GraphNode(Float64; feature=i) for i in 1:3]
    base_tree = cos(x1 - 3.2) * x2
    tree = sin(base_tree) + base_tree

    ex = Expression(tree; operators=options.operators, variable_names=["x1", "x2", "x3"])

    s = strip(sprint(print_tree, ex))
    @test s == "sin(cos(x1 - 3.2) * x2) + {(cos(x1 - 3.2) * x2)}"

    rng = MersenneTwister(0)
    expressions = [copy(ex) for _ in 1:1000]
    expressions = [break_random_connection!(ex, rng) for ex in expressions]
    strings = [strip(sprint(print_tree, ex)) for ex in expressions]
    strings = unique(strings)
    @test Set(strings) == Set([
        "sin(cos(x1 - 3.2) * x2) + {(cos(x1 - 3.2) * x2)}",
        "sin(cos(x1 - 3.2) * x2) + (cos(x1 - 3.2) * x2)",
    ])
    # Either it breaks the connection or not
end

@testitem "GraphNode form connection mutation" tags = [:part1] begin
    using SymbolicRegression
    using SymbolicRegression.MutationFunctionsModule: form_random_connection!
    using Random: MersenneTwister

    options = Options(;
        binary_operators=[+, -, *, /],
        unary_operators=[cos, sin],
        maxsize=30,
        node_type=GraphNode,
    )

    x1, x2 = [GraphNode{Float64}(; feature=i) for i in 1:2]

    tree = cos(x1 * x2 + 1.5)
    ex = Expression(tree; operators=options.operators, variable_names=["x1", "x2"])
    rng = MersenneTwister(0)
    expressions = [copy(ex) for _ in 1:3_000]
    expressions = [form_random_connection!(ex, rng) for ex in expressions]
    strings = [strip(sprint(print_tree, ex)) for ex in expressions]
    strings = sort(unique(strings); by=length)

    # All possible connections that can be made
    @test Set(strings) == Set([
        "cos(x1)",
        "cos(x2)",
        "cos(1.5)",
        "cos(x1 * x2)",
        "cos(x2 + 1.5)",
        "cos(x1 + 1.5)",
        "cos(1.5 + {1.5})",
        "cos((x1 * x2) + 1.5)",
        "cos((x1 * x2) + {x2})",
        "cos((x1 * x2) + {x1})",
        "cos((x2 * {x2}) + 1.5)",
        "cos((x1 * {x1}) + 1.5)",
        "cos((x1 * 1.5) + {1.5})",
        "cos((1.5 * x2) + {1.5})",
        "cos((x1 * x2) + {(x1 * x2)})",
    ])
end
