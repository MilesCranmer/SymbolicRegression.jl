@testitem "Single output, single guess" tags = [:part1] begin
    using SymbolicRegression
    using SymbolicRegression: calculate_pareto_frontier
    using Test

    X = randn(2, 50)
    y = @. 2.0 * X[1, :]^2 + 3.0 * X[2, :] + 0.5

    options = Options(;
        binary_operators=(+, *), unary_operators=(), verbosity=0, progress=false
    )

    # See if a good guess helps the search
    good_guess = "2.0*x1*x1 + 3.0*x2 + 0.5"
    hof = equation_search(X, y; niterations=0, options, guesses=[good_guess])
    dominating = calculate_pareto_frontier(hof)

    @test any(m -> m.loss < 1e-10, dominating)

    # We also test that this test correctly measures the behavior
    bad_guess = "1.0*x1 + 1.0*x2 + 0.0"
    hof = equation_search(X, y; niterations=0, options, guesses=[bad_guess])
    dominating = calculate_pareto_frontier(hof)

    @test !any(m -> m.loss < 1e-10, dominating)
end

@testitem "Unit test: parse_guesses with NamedTuple" tags = [:part1] begin
    using SymbolicRegression
    using SymbolicRegression: parse_guesses, Dataset, PopMember
    using Test

    # Create test data
    X = Float64[1.0 2.0; 3.0 4.0]
    y = Float64[5.0, 6.0]
    dataset = Dataset(X, y)

    # Create template options
    operators = OperatorEnum(; binary_operators=[+, -, *], unary_operators=[])
    template = @template_spec(expressions = (f, g)) do x1, x2
        f(x1, x2) + g(x1, x2)
    end
    options = Options(; operators=operators, expression_spec=template)

    # Test NamedTuple guess with #N placeholder syntax
    namedtuple_guess = (; f="2.0 * #1", g="1.5 * #2")

    # Test parse_guesses function directly
    parsed_members = parse_guesses(
        PopMember{Float64,Float64}, [namedtuple_guess], [dataset], options
    )

    # Should return a vector of vectors (one per output dataset)
    @test length(parsed_members) == 1
    @test length(parsed_members[1]) == 1

    # Check that the parsed member is correct type
    member = parsed_members[1][1]
    @test member isa PopMember
    @test member.tree isa TemplateExpression

    # Check that the template expression has the right structure
    @test haskey(member.tree.trees, :f)
    @test haskey(member.tree.trees, :g)
    @test member.tree.trees.f isa ComposableExpression
    @test member.tree.trees.g isa ComposableExpression

    # Test multiple NamedTuple guesses
    multiple_guesses = [(; f="#1", g="#2"), (; f="2.0 * #1", g="1.5 * #2")]

    parsed_multiple = parse_guesses(
        PopMember{Float64,Float64}, multiple_guesses, [dataset], options
    )

    @test length(parsed_multiple) == 1
    @test length(parsed_multiple[1]) == 2
    @test all(m -> m.tree isa TemplateExpression, parsed_multiple[1])
end

@testitem "NamedTuple guesses with different variable names" tags = [:part1] begin
    using SymbolicRegression
    using SymbolicRegression: calculate_pareto_frontier
    using Test

    X = randn(3, 20)
    y = @. X[1, :] + 2.0 * X[2, :] - X[3, :]

    operators = OperatorEnum(; binary_operators=[+, -, *], unary_operators=[])
    variable_names = ["input1", "input2", "input3"]

    # Create template using @template_spec macro
    template = @template_spec(expressions = (term1, term2)) do input1, input2, input3
        term1(input1, input2, input3) + term2(input1, input2, input3)
    end

    options = Options(;
        operators=operators, expression_spec=template, verbosity=0, progress=false
    )

    # Test NamedTuple guess with custom variable names using #N placeholder syntax
    guess_with_custom_names = (; term1="#1 + 2.0 * #2", term2="-1.0 * #3")
    hof = equation_search(
        X,
        y;
        niterations=0,
        options,
        guesses=[guess_with_custom_names],
        variable_names=variable_names,
    )
    dominating = calculate_pareto_frontier(hof)

    @test any(m -> m.loss < 1e-8, dominating)  # Should find exact solution
    @test any(m -> m.tree isa TemplateExpression, dominating)
end

@testitem "Float32 dataset with Float64 guess literals" tags = [:part1] begin
    using SymbolicRegression
    using SymbolicRegression: parse_guesses, Dataset, PopMember
    using Test

    # Create Float32 dataset
    X = Float32[1.0 2.0; 3.0 4.0]
    y = Float32[5.0, 6.0]
    dataset = Dataset(X, y)

    options = Options(;
        binary_operators=[+, -, *, /], verbosity=0, progress=false, deterministic=true
    )

    guess_with_float64_literals = "4.561253 - ((x1 - x2) * 0.18459733)"

    parsed_members = parse_guesses(
        PopMember{Float32,Float32}, [guess_with_float64_literals], [dataset], options
    )
    @test length(parsed_members) == 1
    @test length(parsed_members[1]) == 1
    @test parsed_members[1][1] isa PopMember{Float32,Float32}

    # Test that Float32 literals work fine
    guess_with_float32_literals = "4.561253f0 - ((x1 - x2) * 0.18459733f0)"
    parsed_members = parse_guesses(
        PopMember{Float32,Float32}, [guess_with_float32_literals], [dataset], options
    )
    @test length(parsed_members) == 1
    @test length(parsed_members[1]) == 1
    @test parsed_members[1][1] isa PopMember{Float32,Float32}
end

# TODO: Multiple outputs
# TODO: User-defined operators
