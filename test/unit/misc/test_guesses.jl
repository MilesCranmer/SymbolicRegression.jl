@testitem "Single output, single guess" begin
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

@testitem "parse_guesses with NamedTuple" begin
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

@testitem "parse_guesses with NamedTuple and parameters" begin
    using SymbolicRegression
    using SymbolicRegression: parse_guesses, Dataset, PopMember
    using Test

    # Create test data
    X = Float64[1.0 2.0; 3.0 4.0]
    y = Float64[5.0, 6.0]
    dataset = Dataset(X, y)

    # Create template with parameters
    operators = OperatorEnum(; binary_operators=[+, -, *], unary_operators=[])
    template = @template_spec(expressions = (f,), parameters = (p=2,)) do x1, x2
        f(x1, x2) + p[1] * x1 + p[2]
    end
    options = Options(; operators=operators, expression_spec=template)

    # Test NamedTuple guess - should auto-initialize parameters
    namedtuple_guess = (; f="#1 * #2")

    parsed_members = parse_guesses(
        PopMember{Float64,Float64}, [namedtuple_guess], [dataset], options
    )

    member = parsed_members[1][1]
    @test member.tree isa TemplateExpression
    @test haskey(get_metadata(member.tree).parameters, :p)
    @test length(get_metadata(member.tree).parameters.p._data) == 2
end

@testitem "NamedTuple guesses with different variable names" begin
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

@testitem "Float32 dataset with Float64 guess literals" begin
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

@testitem "Custom operators in string guesses" begin
    using SymbolicRegression
    using SymbolicRegression: parse_guesses, Dataset, PopMember, calculate_pareto_frontier
    using Test

    # Define custom operators
    pythag_pos(x, y) = sqrt(x^2 + y^2)
    pythag_neg(x, y) = (d = x^2 - y^2) < 0 ? typeof(x)(NaN) : typeof(x)(sqrt(d))
    custom_sin(x) = sin(x) + 0.1

    # Test with binary custom operators
    X = Float64[1.0 2.0 3.0; 4.0 5.0 6.0]
    y = Float64[7.0, 8.0, 9.0]
    dataset = Dataset(X, y)

    options = Options(;
        binary_operators=[+, -, *, /, pythag_pos, pythag_neg],
        unary_operators=[sin, cos, custom_sin],
        verbosity=0,
        progress=false,
    )

    # Test that custom operators work in string guesses
    custom_guess = "pythag_pos(x1, x2) + custom_sin(x1)"
    parsed_members = parse_guesses(
        PopMember{Float64,Float64}, [custom_guess], [dataset], options
    )

    @test length(parsed_members) == 1
    @test length(parsed_members[1]) == 1
    @test parsed_members[1][1] isa PopMember{Float64,Float64}

    # Test with complex expression like the original failing case
    complex_guess = "pythag_pos(x1, 4.51352 - ((x2 - x1) * 0.07425507))"
    parsed_complex = parse_guesses(
        PopMember{Float64,Float64}, [complex_guess], [dataset], options
    )

    @test length(parsed_complex) == 1
    @test length(parsed_complex[1]) == 1
    @test parsed_complex[1][1] isa PopMember{Float64,Float64}

    # Test multiple custom operator guesses
    multiple_custom_guesses = [
        "pythag_pos(x1, x2)", "pythag_neg(x1, x2) + 0.5", "custom_sin(x1) * x2"
    ]
    parsed_multiple = parse_guesses(
        PopMember{Float64,Float64}, multiple_custom_guesses, [dataset], options
    )

    @test length(parsed_multiple) == 1
    @test length(parsed_multiple[1]) == 3
    @test all(m -> m isa PopMember{Float64,Float64}, parsed_multiple[1])
end

@testitem "Custom operators in equation_search guesses" begin
    using SymbolicRegression
    using SymbolicRegression: calculate_pareto_frontier
    using Test

    # Define custom operators
    pythag_pos(x, y) = sqrt(x^2 + y^2)
    pythag_neg(x, y) = (d = x^2 - y^2) < 0 ? typeof(x)(NaN) : typeof(x)(sqrt(d))

    # Create synthetic data where custom operator is the true function
    X = randn(2, 30)
    y = pythag_pos.(X[1, :], X[2, :]) .+ 0.01 .* randn(30)  # Add small noise

    options = Options(;
        binary_operators=[+, -, *, /, pythag_pos, pythag_neg],
        unary_operators=[sin, cos],
        verbosity=0,
        progress=false,
    )

    # Test that custom operator guess works in equation_search
    custom_guess = "pythag_pos(x1, x2)"
    hof = equation_search(X, y; niterations=0, options, guesses=[custom_guess])
    dominating = calculate_pareto_frontier(hof)

    # Should find a good solution since we gave it the exact function
    @test any(m -> m.loss < 1e-2, dominating)

    # Test more complex custom operator expression
    complex_guess = "pythag_pos(x1, x2) + 0.0"
    hof_complex = equation_search(X, y; niterations=0, options, guesses=[complex_guess])
    dominating_complex = calculate_pareto_frontier(hof_complex)

    @test any(m -> m.loss < 1e-2, dominating_complex)
end

@testitem "Custom operators error handling in guesses" begin
    using SymbolicRegression
    using SymbolicRegression: parse_guesses, Dataset, PopMember
    using Test

    # Define custom operator
    pythag_pos(x, y) = sqrt(x^2 + y^2)

    X = Float64[1.0 2.0; 3.0 4.0]
    y = Float64[5.0, 6.0]
    dataset = Dataset(X, y)

    options = Options(;
        binary_operators=[+, -, *, /, pythag_pos], verbosity=0, progress=false
    )

    # Test wrong arity error
    @test_throws ArgumentError parse_guesses(
        PopMember{Float64,Float64}, ["pythag_pos(x1)"], [dataset], options
    )

    # Test non-existent operator error
    @test_throws ArgumentError parse_guesses(
        PopMember{Float64,Float64}, ["nonexistent_op(x1, x2)"], [dataset], options
    )
end

@testitem "Custom operators with NamedTuple guesses" begin
    using SymbolicRegression
    using SymbolicRegression: parse_guesses, Dataset, PopMember
    using Test

    # Define custom operators
    pythag_pos(x, y) = sqrt(x^2 + y^2)
    custom_mul(x, y) = x * y * 1.1

    X = Float64[1.0 2.0; 3.0 4.0]
    y = Float64[5.0, 6.0]
    dataset = Dataset(X, y)

    # Create template options with custom operators
    operators = OperatorEnum(;
        binary_operators=[+, -, *, pythag_pos, custom_mul], unary_operators=[]
    )
    template = @template_spec(expressions = (f, g)) do x1, x2
        f(x1, x2) + g(x1, x2)
    end
    options = Options(; operators=operators, expression_spec=template)

    # Test NamedTuple guess with custom operators using #N placeholder syntax
    namedtuple_guess = (; f="pythag_pos(#1, #2)", g="custom_mul(#1, #2)")

    parsed_members = parse_guesses(
        PopMember{Float64,Float64}, [namedtuple_guess], [dataset], options
    )

    @test length(parsed_members) == 1
    @test length(parsed_members[1]) == 1

    member = parsed_members[1][1]
    @test member isa PopMember
    @test member.tree isa TemplateExpression
    @test haskey(member.tree.trees, :f)
    @test haskey(member.tree.trees, :g)
end

@testitem "Smoke test migration with multiple outputs and templates" begin
    using SymbolicRegression
    using SymbolicRegression: calculate_pareto_frontier
    using Test

    # Multi-output data
    X = randn(2, 20)
    y1 = @. 2.0 * X[1, :] + X[2, :]
    y2 = @. X[1, :] - X[2, :]
    Y = [y1 y2]'

    # Template expressions
    operators = OperatorEnum(; binary_operators=[+, -, *], unary_operators=[])
    template = @template_spec(expressions = (f,)) do x1, x2
        f(x1, x2)
    end
    options = Options(;
        operators=operators,
        expression_spec=template,
        fraction_replaced_guesses=0.5,
        verbosity=0,
        progress=false,
    )
    guesses = [[(; f="1.9 * #1 + #2")], [(; f="#1 - #2")]]
    hof = equation_search(X, Y; niterations=1, options, guesses)

    @test all(h -> any(m -> m.loss < 0.01, calculate_pareto_frontier(h)), hof)
end

@testitem "parse_guesses with mix of strings and expression objects" begin
    using SymbolicRegression
    using SymbolicRegression: parse_guesses, Dataset, PopMember
    using Test
    using DynamicExpressions: @parse_expression

    X = Float64[1.0 2.0; 3.0 4.0]
    y = Float64[5.0, 6.0]
    dataset = Dataset(X, y)
    options = Options(; binary_operators=[+, -, *, /], unary_operators=[sin, cos])
    expr1 = Expression(
        Node{Float64}(; feature=1); operators=nothing, variable_names=nothing
    )
    expr2 = "x1 - x2"
    expr3 = Expression(Node{Float64}(; val=1.0); operators=nothing, variable_names=nothing)
    mixed_guesses = [expr1, expr2, expr3]

    # Test parse_guesses with mixed input types
    parsed_members = parse_guesses(
        PopMember{Float64,Float64}, mixed_guesses, [dataset], options
    )

    # Should return a vector of vectors (one per output dataset)
    @test length(parsed_members) == 1
    @test length(parsed_members[1]) == 3

    # Check that all parsed members are correct type
    for member in parsed_members[1]
        @test member isa PopMember{Float64,Float64}
        @test member.tree !== nothing
        @test member.tree isa Expression
    end

    # No constant optimization happens yet
    @test parsed_members[1][1].tree == expr1
    @test string_tree(with_metadata(parsed_members[1][2].tree; options.operators)) ==
        "x1 - x2"

    # However, this one does get optimized
    @test parsed_members[1][3].tree != expr3
    @test parsed_members[1][3].tree.tree.val != 1.0
end

@testitem "maxsize warning" begin
    using SymbolicRegression
    using SymbolicRegression: parse_guesses, Dataset, PopMember
    using Test
    using Logging

    X = Float64[1.0 2.0; 3.0 4.0]
    y = Float64[5.0, 6.0]
    dataset = Dataset(X, y)
    options = Options(; binary_operators=[+, -, *, /], maxsize=7)

    # Test complex guess triggers warning
    io = IOBuffer()
    with_logger(Logging.SimpleLogger(io, Logging.Warn)) do
        parse_guesses(
            PopMember{Float64,Float64},
            ["x1 * x2 + x1 * x2 + x1 * x2 + x1 * x2 + x1 * x2"],
            [dataset],
            options,
        )
    end
    log_output = String(take!(io))
    @test contains(log_output, "complexity") && contains(log_output, "maxsize")

    # Test simple guess doesn't trigger warning
    io = IOBuffer()
    with_logger(Logging.SimpleLogger(io, Logging.Warn)) do
        parse_guesses(PopMember{Float64,Float64}, ["x1 + x2"], [dataset], options)
    end
    @test !contains(String(take!(io)), "maxsize")
end

@testitem "Vector of vectors input for single output" begin
    using SymbolicRegression
    using SymbolicRegression: parse_guesses, Dataset, PopMember
    using Test

    X = Float64[1.0 2.0; 3.0 4.0]
    y = Float64[5.0, 6.0]
    dataset = Dataset(X, y)
    options = Options(; binary_operators=[+, -])

    # Single output (nout=1) with vector-of-vectors format
    guesses_vector_of_vectors = [["x1 + x2", "x1 - x2"]]
    parsed_members = parse_guesses(
        PopMember{Float64,Float64}, guesses_vector_of_vectors, [dataset], options
    )
    @test length(parsed_members) == 1  # One output
    @test length(parsed_members[1]) == 2  # Two guesses for that output
end

@testitem "Multiple outputs guesses format validation" begin
    using SymbolicRegression
    using SymbolicRegression: parse_guesses, Dataset, PopMember
    using Test

    datasets = [Dataset(randn(2, 10), randn(10)) for _ in 1:2]
    options = Options()

    @test_throws(
        ArgumentError("`guesses` must be a vector of vectors when `nout > 1`"),
        parse_guesses(
            PopMember{Float64,Float64}, ["x1 + x2", "x1 - x2"], datasets, options
        )
    )
end

@testitem "File saving with niterations=0" begin
    using SymbolicRegression
    using Test
    using Random: MersenneTwister

    # Create test data
    rng = MersenneTwister(0)
    X = randn(rng, 2, 30)
    y = @. 2.0 * X[1, :]^2 + 3.0 * X[2, :] + 0.5

    tmpdir = mktempdir()
    options = Options(;
        binary_operators=(+, *),
        unary_operators=(),
        verbosity=0,
        progress=false,
        save_to_file=true,
        seed=0,
        deterministic=true,
        output_directory=tmpdir,
    )

    # Test that files are saved even when niterations=0, including guesses
    good_guess = "2.0*x1*x1 + 3.0*x2 + 0.5"
    hof = equation_search(
        X, y; niterations=0, options=options, parallelism=:serial, guesses=[good_guess]
    )

    output_files = []
    for (root, dirs, files) in walkdir(tmpdir)
        for file in files
            if endswith(file, ".csv") && contains(file, "hall_of_fame")
                push!(output_files, joinpath(root, file))
            end
        end
    end
    @test length(output_files) == 1

    expected_file = only(output_files)
    content = read(expected_file, String)
    @test !isempty(content)
    @test contains(content, "Complexity")
    @test contains(content, "Loss")
    @test contains(content, "x1")

    lines = split(content, '\n')
    equation_lines = filter(
        line -> !startswith(line, "Complexity") && !isempty(strip(line)), lines
    )
    @test length(equation_lines) > 0

    # Check that one equation matches our guess: "2.0*x1*x1 + 3.0*x2 + 0.5"
    @test any(equation_lines) do line
        parts = split(line, ',')
        if length(parts) >= 3
            equation_part = strip(parts[end])
            equation_part = strip(equation_part, '"')
            if equation_part == "(((2.0 * x1) * x1) + (3.0 * x2)) + 0.5"
                return true
            end
        end
        return false
    end
end
