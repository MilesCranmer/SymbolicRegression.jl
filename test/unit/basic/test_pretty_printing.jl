@testitem "pretty print member" tags = [:part3] begin
    using SymbolicRegression

    options = Options(; binary_operators=[+, ^])

    ex = @parse_expression(x^2.0 + 1.5, binary_operators = [+, ^], variable_names = [:x])
    shower(x) = sprint((io, e) -> show(io, MIME"text/plain"(), e), x)
    s = shower(ex)
    @test s == "(x ^ 2.0) + 1.5"

    X = [1.0 2.0 3.0]
    y = [2.0, 3.0, 4.0]
    dataset = Dataset(X, y)
    member = PopMember(dataset, ex, options; deterministic=false)
    member.cost = 1.0
    @test member isa PopMember{Float64,Float64,<:Expression{Float64,Node{Float64}}}
    s_member = shower(member)
    @test s_member == "PopMember(tree = ((x ^ 2.0) + 1.5), loss = 16.25, cost = 1.0)"

    # New options shouldn't change this
    options = Options(; binary_operators=[-, /])
    s_member = shower(member)
    @test s_member == "PopMember(tree = ((x ^ 2.0) + 1.5), loss = 16.25, cost = 1.0)"
end

@testitem "pretty print hall of fame" tags = [:part1] begin
    using SymbolicRegression
    using SymbolicRegression: embed_metadata
    using SymbolicRegression.CoreModule: safe_pow

    options = Options(; binary_operators=[+, safe_pow], maxsize=7)

    ex = @parse_expression(
        $safe_pow(x, 2.0) + 1.5, binary_operators = [+, safe_pow], variable_names = [:x]
    )
    shower(x) = sprint((io, e) -> show(io, MIME"text/plain"(), e), x)
    s = shower(ex)
    @test s == "(x ^ 2.0) + 1.5"

    X = [1.0 2.0 3.0]
    y = [2.0, 3.0, 4.0]
    dataset = Dataset(X, y)
    member = PopMember(dataset, ex, options; deterministic=false)
    member.cost = 1.0
    @test member isa PopMember{Float64,Float64,<:Expression{Float64,Node{Float64}}}

    hof = HallOfFame(options, dataset)
    hof = embed_metadata(hof, options, dataset)
    hof.members[5] = member
    hof.exists[5] = true
    s_hof = strip(shower(hof))
    true_s = "HallOfFame{...}:
    .exists[1] = false
    .members[1] = undef
    .exists[2] = false
    .members[2] = undef
    .exists[3] = false
    .members[3] = undef
    .exists[4] = false
    .members[4] = undef
    .exists[5] = true
    .members[5] = PopMember(tree = ((x ^ 2.0) + 1.5), loss = 16.25, cost = 1.0)
    .exists[6] = false
    .members[6] = undef
    .exists[7] = false
    .members[7] = undef"

    @test s_hof == true_s
end

@testitem "pretty print expression" tags = [:part2] begin
    using SymbolicRegression
    using Suppressor: @capture_out

    options = Options(; binary_operators=[+, -, *, /], unary_operators=[cos])
    ex = @parse_expression(
        cos(x) + y * y, operators = options.operators, variable_names = [:x, :y]
    )

    s = sprint((io, ex) -> print_tree(io, ex, options), ex)
    @test strip(s) == "cos(x) + (y * y)"

    s = @capture_out begin
        print_tree(ex, options)
    end
    @test strip(s) == "cos(x) + (y * y)"

    # Works with the tree itself too
    s = @capture_out begin
        print_tree(get_tree(ex), options)
    end
    @test strip(s) == "cos(x1) + (x2 * x2)"
    s = sprint((io, ex) -> print_tree(io, ex, options), get_tree(ex))
    @test strip(s) == "cos(x1) + (x2 * x2)"

    # Updating options won't change printout, UNLESS
    # we pass the options.
    options = Options(; binary_operators=[/, *, -, +], unary_operators=[sin])

    s = @capture_out begin
        print_tree(ex)
    end
    @test strip(s) == "cos(x) + (y * y)"

    s = sprint((io, ex) -> print_tree(io, ex, options), ex)
    @test strip(s) == "sin(x) / (y - y)"
end

@testitem "printing utilities" tags = [:part2] begin
    using SymbolicRegression.UtilsModule: split_string
    using SymbolicRegression.HallOfFameModule: wrap_equation_string

    @test split_string("abc\ndefg", 3) == ["abc", "\nde", "fg"]

    test_equation_string = "cos(x) + 1.5387438743 - y^2"
    @test wrap_equation_string(test_equation_string, 0, 15) == """cos(x) + 1....
    5387438743 ...
    - y^2\n"""

    # Note how we have special treatment of explicit newlines:
    test_equation_string = "(\nB = ( -0.012549, 0.0086419, 0.6175 )\nF_d = (-0.051546) * v\n)"
    @test wrap_equation_string(test_equation_string, 4, 1000) == """(
    B = ( -0.012549, 0.0086419, 0.6175 )
    F_d = (-0.051546) * v
    )
"""

    @test startswith(wrap_equation_string(test_equation_string, 0, 10), "(\n")
    @test wrap_equation_string(test_equation_string, 0, 12) == """(
B = ( -0...
.012549,...
 0.00864...
19, 0.61...
75 )
F_d = (-...
0.051546...
) * v
)
"""
end

@testitem "pretty print vs serialization for comparison operators" tags = [:part1] begin
    using SymbolicRegression
    using SymbolicRegression: greater, greater_equal, string_tree

    options = Options(; binary_operators=[greater, greater_equal])
    x1 = Expression(Node(; feature=1); operators=options.operators)
    x2 = Expression(Node(; feature=2); operators=options.operators)
    ex = x1 > x2
    ex2 = x1 >= x2

    # Pretty printing should use symbols
    pretty_str = string_tree(ex; pretty=true)
    pretty_str2 = string_tree(ex2; pretty=true)
    @test pretty_str == "x1 > x2"
    @test pretty_str2 == "x1 >= x2"

    # Serialization should use function names
    serialized_str = string_tree(ex)
    serialized_str2 = string_tree(ex2)
    @test serialized_str == "greater(x1, x2)"
    @test serialized_str2 == "greater_equal(x1, x2)"
end
