@testitem "Test complexity evaluation" tags = [:part3] begin
    using SymbolicRegression

    x1, x2, x3 = Node("x1"), Node("x2"), Node("x3")

    # First, test regular complexities:
    function make_options(; kw...)
        return Options(;
            binary_operators=(+, -, *, /, ^), unary_operators=(cos, sin), kw...
        )
    end
    options = make_options()
    @extend_operators options
    tree = sin((x1 + x2 + x3)^2.3)
    @test compute_complexity(tree, options) == 8

    options = make_options(; complexity_of_operators=[sin => 3])
    @test compute_complexity(tree, options) == 10
    options = make_options(; complexity_of_operators=[sin => 3, (+) => 2])
    @test compute_complexity(tree, options) == 12

    # Real numbers:
    options = make_options(; complexity_of_operators=[sin => 3, (+) => 2, (^) => 3.2])
    @test compute_complexity(tree, options) == round(Int, 12 + (3.2 - 1))
end

@testitem "Test other things about complexity" tags = [:part3] begin
    using SymbolicRegression

    x1, x2, x3 = Node("x1"), Node("x2"), Node("x3")

    function make_options(; kw...)
        return Options(;
            binary_operators=(+, -, *, /, ^), unary_operators=(cos, sin), kw...
        )
    end

    options = make_options(;
        complexity_of_operators=[sin => 3, (+) => 2], complexity_of_variables=2
    )
    tree = sin((x1 + x2 + x3)^2.3)
    @test compute_complexity(tree, options) == 12 + 3 * 1
    options = make_options(;
        complexity_of_operators=[sin => 3, (+) => 2],
        complexity_of_variables=2,
        complexity_of_constants=2,
    )
    @test compute_complexity(tree, options) == 12 + 3 * 1 + 1
    options = make_options(;
        complexity_of_operators=[sin => 3, (+) => 2],
        complexity_of_variables=2,
        complexity_of_constants=2.6,
    )
    @test compute_complexity(tree, options) == 12 + 3 * 1 + 1 + 1

    # Custom variables
    options = make_options(;
        complexity_of_variables=[1, 2, 3], complexity_of_operators=[(+) => 5, (*) => 2]
    )
    x1, x2, x3 = [Node{Float64}(; feature=i) for i in 1:3]
    tree = x1 + x2 * x3
    @test compute_complexity(tree, options) == 1 + 5 + 2 + 2 + 3
    options = make_options(;
        complexity_of_variables=2, complexity_of_operators=[(+) => 5, (*) => 2]
    )
    @test compute_complexity(tree, options) == 2 + 5 + 2 + 2 + 2
end

@testitem "Custom complexity mapping" tags = [:part3] begin
    using SymbolicRegression

    function custom_complexity(tree)
        @test tree isa AbstractExpression
        return 10
    end

    options = Options(; complexity_mapping=custom_complexity)
    variable_names = ["x1"]
    x1 = Expression(Node{Float64}(; feature=1); options.operators, variable_names)
    @test compute_complexity(x1, options) == 10
end
