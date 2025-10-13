@testitem "HOF rows functionality" tags = [:part1] begin
    using SymbolicRegression
    using DynamicExpressions
    using Test

    # Create test data
    X = Float32[1.0 2.0 3.0; 4.0 5.0 6.0]
    y = Float32[1.0, 2.0, 3.0]

    options = Options(;
        binary_operators=[+, -],
        unary_operators=[],
        maxsize=5,
        populations=1,
        population_size=10,
        tournament_selection_n=3,
        deterministic=true,
        seed=0,
    )

    dataset = Dataset(X, y)

    @testset "compute_scores" begin
        # Create a simple HOF with multiple members
        hof = SymbolicRegression.HallOfFameModule.HallOfFame(options, dataset)

        # Add multiple members with different complexities
        for i in 1:3
            hof.exists[i] = true
        end

        members = [hof.members[i] for i in 1:3 if hof.exists[i]]

        # Test score computation
        scores = SymbolicRegression.HallOfFameModule.compute_scores(members, options)

        @test length(scores) == length(members)
        @test scores[1] == 0  # First member always has score 0
        @test all(s >= 0 for s in scores)  # Scores should be non-negative

        # Test with empty members
        empty_scores = SymbolicRegression.HallOfFameModule.compute_scores(
            typeof(members[1])[], options
        )
        @test isempty(empty_scores)
    end

    @testset "HOFRows iteration" begin
        hof = SymbolicRegression.HallOfFameModule.HallOfFame(options, dataset)
        hof.exists[1] = true
        hof.exists[2] = true

        rows = SymbolicRegression.HallOfFameModule.hof_rows(
            hof, dataset, options; pareto_only=false, include_score=true
        )

        # Test Base.length
        @test length(rows) == 2

        # Test Base.eltype
        @test eltype(rows) == NamedTuple

        # Test iteration
        collected = collect(rows)
        @test length(collected) == 2
        @test all(r isa NamedTuple for r in collected)

        # Test that scores are included by default for pareto_only=true
        @test all(haskey(r, :score) for r in collected)

        # Test equation inclusion
        @test all(haskey(r, :equation) for r in collected)
    end

    @testset "hof_rows options" begin
        hof = SymbolicRegression.HallOfFameModule.HallOfFame(options, dataset)
        for i in 1:3
            hof.exists[i] = true
        end

        # Test pareto_only=false
        rows_all = SymbolicRegression.HallOfFameModule.hof_rows(
            hof, dataset, options; pareto_only=false
        )
        # Should include all existing members (Pareto might filter some)
        @test length(rows_all) == 3

        # Test include_score=false
        rows_no_score = SymbolicRegression.HallOfFameModule.hof_rows(
            hof, dataset, options; include_score=false
        )
        for row in rows_no_score
            @test !haskey(row, :score)
        end
    end

    @testset "Empty HOF" begin
        hof = SymbolicRegression.HallOfFameModule.HallOfFame(options, dataset)
        # Don't mark any as existing

        rows = SymbolicRegression.HallOfFameModule.hof_rows(hof, dataset, options)

        @test length(rows) == 0
        @test isempty(collect(rows))
    end

    @testset "Backwards compatibility" begin
        hof = SymbolicRegression.HallOfFameModule.HallOfFame(options, dataset)
        hof.exists[1] = true
        hof.exists[2] = true

        # Test that format_hall_of_fame still works
        formatted = SymbolicRegression.HallOfFameModule.format_hall_of_fame(hof, options)

        @test haskey(formatted, :trees)
        @test haskey(formatted, :scores)
        @test haskey(formatted, :losses)
        @test haskey(formatted, :complexities)
        @test length(formatted.trees) == length(formatted.scores)
        @test length(formatted.trees) == length(formatted.losses)
        @test length(formatted.trees) == length(formatted.complexities)

        # Test that string_dominating_pareto_curve still works
        curve_string = SymbolicRegression.HallOfFameModule.string_dominating_pareto_curve(
            hof, dataset, options
        )

        @test curve_string isa AbstractString
        @test contains(curve_string, "Complexity")
        @test contains(curve_string, "Loss")
    end
end

@testitem "HOF rows with custom PopMember" tags = [:part1] begin
    using SymbolicRegression
    using DynamicExpressions
    using Test
    using DispatchDoctor: @unstable

    import SymbolicRegression.PopMemberModule: create_child
    import SymbolicRegression.HallOfFameModule: member_to_row

    # Define a custom PopMember with an extra field
    mutable struct TestCustomPopMember{T,L,N} <: SymbolicRegression.AbstractPopMember{T,L,N}
        tree::N
        cost::L
        loss::L
        birth::Int
        complexity::Int
        ref::Int
        parent::Int
        custom_field::Float64  # Extra field
    end

    # Constructor
    function TestCustomPopMember(
        tree::N,
        cost::L,
        loss::L,
        birth::Int,
        complexity::Int,
        ref::Int,
        parent::Int,
        custom_field::Float64,
    ) where {T,L,N<:AbstractExpression{T}}
        return TestCustomPopMember{T,L,N}(
            tree, cost, loss, birth, complexity, ref, parent, custom_field
        )
    end

    function TestCustomPopMember(
        tree::N,
        cost::L,
        loss::L,
        options,
        complexity::Int;
        parent=-1,
        deterministic=nothing,
        custom_field=1.0,
    ) where {T,L,N<:AbstractExpression{T}}
        return TestCustomPopMember(
            tree,
            cost,
            loss,
            SymbolicRegression.get_birth_order(; deterministic=deterministic),
            complexity,
            abs(rand(Int)),
            parent,
            custom_field,
        )
    end

    function TestCustomPopMember(
        dataset::SymbolicRegression.Dataset,
        tree,
        options;
        parent=-1,
        deterministic=nothing,
        custom_field=1.0,
    )
        ex = SymbolicRegression.create_expression(tree, options, dataset)
        complexity = SymbolicRegression.compute_complexity(ex, options)
        cost, loss = SymbolicRegression.eval_cost(dataset, ex, options; complexity)

        return TestCustomPopMember(
            ex,
            cost,
            loss,
            SymbolicRegression.get_birth_order(; deterministic=deterministic),
            complexity,
            abs(rand(Int)),
            parent,
            custom_field,
        )
    end

    @unstable DynamicExpressions.constructorof(::Type{<:TestCustomPopMember}) =
        TestCustomPopMember

    @unstable function DynamicExpressions.with_type_parameters(
        ::Type{<:TestCustomPopMember}, ::Type{T}, ::Type{L}, ::Type{N}
    ) where {T,L,N}
        return TestCustomPopMember{T,L,N}
    end

    function Base.copy(p::TestCustomPopMember)
        return TestCustomPopMember(
            copy(p.tree),
            copy(p.cost),
            copy(p.loss),
            copy(p.birth),
            copy(getfield(p, :complexity)),
            copy(p.ref),
            copy(p.parent),
            copy(p.custom_field),
        )
    end

    function create_child(
        parent::TestCustomPopMember{T,L},
        tree::AbstractExpression{T},
        cost::L,
        loss::L,
        options;
        complexity::Union{Int,Nothing}=nothing,
        parent_ref,
    ) where {T,L}
        actual_complexity = @something complexity SymbolicRegression.compute_complexity(
            tree, options
        )
        return TestCustomPopMember(
            tree,
            cost,
            loss,
            SymbolicRegression.get_birth_order(; deterministic=options.deterministic),
            actual_complexity,
            abs(rand(Int)),
            parent_ref,
            parent.custom_field * 1.1,  # Modify custom field
        )
    end

    # Extend member_to_row for custom PopMember
    function member_to_row(
        member::TestCustomPopMember,
        dataset::SymbolicRegression.Dataset,
        options::SymbolicRegression.AbstractOptions;
        kwargs...,
    )
        base = invoke(
            member_to_row,
            Tuple{
                SymbolicRegression.AbstractPopMember,
                SymbolicRegression.Dataset,
                SymbolicRegression.AbstractOptions,
            },
            member,
            dataset,
            options;
            kwargs...,
        )
        return merge(base, (custom_field=member.custom_field,))
    end

    @testset "Custom PopMember with member_to_row extension" begin
        X = Float32[1.0 2.0 3.0; 4.0 5.0 6.0]
        y = Float32[1.0, 2.0, 3.0]

        options = Options(;
            binary_operators=[+, -],
            maxsize=5,
            popmember_type=TestCustomPopMember,
            deterministic=true,
            seed=0,
        )

        dataset = Dataset(X, y)

        # Create a custom member
        tree = SymbolicRegression.create_expression(1.0f0, options, dataset)
        custom_member = TestCustomPopMember(
            dataset, tree, options; deterministic=true, custom_field=42.0
        )

        # Test that member_to_row includes custom field
        row = member_to_row(custom_member, dataset, options)

        @test haskey(row, :custom_field)
        @test row.custom_field == 42.0
        @test haskey(row, :complexity)
        @test haskey(row, :loss)
        @test haskey(row, :equation)

        # Test with HOF
        hof = SymbolicRegression.HallOfFameModule.HallOfFame(options, dataset)
        hof.members[1] = custom_member
        hof.exists[1] = true

        rows = SymbolicRegression.HallOfFameModule.hof_rows(hof, dataset, options)
        collected = collect(rows)

        @test length(collected) == 1
        @test haskey(collected[1], :custom_field)
        @test collected[1].custom_field == 42.0
    end
end

@testitem "Tables.jl extension" tags = [:part1] begin
    using SymbolicRegression
    using Test

    # Only run if Tables.jl is available
    if isdefined(Base, :get_extension)
        # Try to load Tables
        try
            @eval using Tables

            @testset "Tables.jl integration" begin
                X = Float32[1.0 2.0 3.0; 4.0 5.0 6.0]
                y = Float32[1.0, 2.0, 3.0]

                options = Options(;
                    binary_operators=[+, -], maxsize=5, deterministic=true, seed=0
                )

                dataset = Dataset(X, y)
                hof = SymbolicRegression.HallOfFameModule.HallOfFame(options, dataset)
                hof.exists[1] = true

                rows = SymbolicRegression.HallOfFameModule.hof_rows(hof, dataset, options)

                # Test Tables.jl interface
                @test Tables.istable(rows)
                @test Tables.rowaccess(rows)
                @test Tables.rows(rows) === rows  # Should return itself

                # Test that it works with Tables.columntable
                ct = Tables.columntable(rows)
                @test ct isa NamedTuple
                @test haskey(ct, :complexity)
                @test haskey(ct, :loss)
            end
        catch e
            @info "Skipping Tables.jl tests (Tables.jl not available): $e"
        end
    else
        @info "Skipping Tables.jl tests (Julia version < 1.9)"
    end
end

@testitem "Column specifications" tags = [:part1] begin
    using SymbolicRegression
    using Test
    using Printf: @sprintf

    X = Float32[1.0 2.0 3.0; 4.0 5.0 6.0]
    y = Float32[1.0, 2.0, 3.0]

    options = Options(; binary_operators=[+, -], maxsize=5, deterministic=true, seed=0)

    dataset = Dataset(X, y)

    @testset "HOFColumn basics" begin
        # Create a simple column
        col = SymbolicRegression.HallOfFameModule.HOFColumn(
            :loss, "Loss", row -> row.loss, x -> @sprintf("%.2e", x), 8, :right
        )

        @test col.name == :loss
        @test col.header == "Loss"
        @test col.width == 8
        @test col.alignment == :right

        # Test getter and formatter
        test_row = (loss=0.123456, complexity=5)
        @test col.getter(test_row) == 0.123456
        @test col.formatter(0.123456) == "1.23e-01"
    end

    @testset "default_columns" begin
        # Test default columns without score (linear loss scale)
        options_linear = Options(;
            binary_operators=[+, -], maxsize=5, loss_scale=:linear, deterministic=true
        )
        cols_linear = SymbolicRegression.HallOfFameModule.default_columns(options_linear)

        @test length(cols_linear) == 3  # complexity, loss, equation
        @test cols_linear[1].name == :complexity
        @test cols_linear[2].name == :loss
        @test cols_linear[3].name == :equation

        # Test default columns with score (log loss scale)
        options_log = Options(;
            binary_operators=[+, -], maxsize=5, loss_scale=:log, deterministic=true
        )
        cols_log = SymbolicRegression.HallOfFameModule.default_columns(options_log)

        @test length(cols_log) == 4  # complexity, loss, score, equation
        @test cols_log[1].name == :complexity
        @test cols_log[2].name == :loss
        @test cols_log[3].name == :score
        @test cols_log[4].name == :equation
    end

    @testset "Custom columns with HOFRows" begin
        hof = SymbolicRegression.HallOfFameModule.HallOfFame(options, dataset)
        hof.exists[1] = true
        hof.exists[2] = true

        # Create custom column specs
        custom_cols = [
            SymbolicRegression.HallOfFameModule.HOFColumn(
                :complexity, "C", row -> row.complexity, string, 5, :right
            ),
            SymbolicRegression.HallOfFameModule.HOFColumn(
                :loss, "L", row -> row.loss, x -> @sprintf("%.2e", x), 8, :right
            ),
        ]

        # Get rows with custom columns
        rows = SymbolicRegression.HallOfFameModule.hof_rows(
            hof, dataset, options; pareto_only=false, columns=custom_cols
        )

        # Collect and verify
        collected = collect(rows)
        @test length(collected) == 2

        # Should only have the two specified columns
        for row in collected
            @test haskey(row, :complexity)
            @test haskey(row, :loss)
            @test !haskey(row, :equation)  # Not requested
            @test !haskey(row, :cost)  # Not requested
        end
    end

    @testset "string_dominating_pareto_curve with custom columns" begin
        hof = SymbolicRegression.HallOfFameModule.HallOfFame(options, dataset)
        hof.exists[1] = true

        # Test with default columns
        str_default = SymbolicRegression.HallOfFameModule.string_dominating_pareto_curve(
            hof, dataset, options
        )
        @test str_default isa AbstractString
        @test contains(str_default, "Complexity")
        @test contains(str_default, "Loss")

        # Test with custom columns
        custom_cols = [
            SymbolicRegression.HallOfFameModule.HOFColumn(
                :complexity, "C", row -> row.complexity, string, 5, :right
            ),
            SymbolicRegression.HallOfFameModule.HOFColumn(
                :loss, "L", row -> row.loss, x -> @sprintf("%.2e", x), 8, :right
            ),
            SymbolicRegression.HallOfFameModule.HOFColumn(
                :equation, "Eq", row -> row.equation, identity, nothing, :left
            ),
        ]

        str_custom = SymbolicRegression.HallOfFameModule.string_dominating_pareto_curve(
            hof, dataset, options; columns=custom_cols
        )
        @test str_custom isa AbstractString
        @test contains(str_custom, "C")  # Custom header
        @test contains(str_custom, "L")  # Custom header
        @test !contains(str_custom, "Complexity")  # Original header should not appear
    end

    @testset "Computed columns" begin
        hof = SymbolicRegression.HallOfFameModule.HallOfFame(options, dataset)
        hof.exists[1] = true

        # Create a computed column (e.g., cost/loss ratio)
        custom_cols = [
            SymbolicRegression.HallOfFameModule.HOFColumn(
                :complexity, "C", row -> row.complexity, string, 5, :right
            ),
            SymbolicRegression.HallOfFameModule.HOFColumn(
                :ratio,
                "Cost/Loss",
                row -> row.cost / row.loss,  # Computed from multiple fields
                x -> @sprintf("%.2f", x),
                10,
                :right,
            ),
        ]

        rows = SymbolicRegression.HallOfFameModule.hof_rows(
            hof, dataset, options; pareto_only=false, columns=custom_cols
        )

        collected = collect(rows)
        @test length(collected) == 1
        @test haskey(collected[1], :ratio)
        @test collected[1].ratio isa Number
    end
end

@testitem "Column specs with Tables.jl" tags = [:part1] begin
    using SymbolicRegression
    using Test
    using Printf: @sprintf

    # Only run if Tables.jl is available
    if isdefined(Base, :get_extension)
        try
            @eval using Tables

            X = Float32[1.0 2.0 3.0; 4.0 5.0 6.0]
            y = Float32[1.0, 2.0, 3.0]

            options = Options(;
                binary_operators=[+, -], maxsize=5, deterministic=true, seed=0
            )

            dataset = Dataset(X, y)
            hof = SymbolicRegression.HallOfFameModule.HallOfFame(options, dataset)
            hof.exists[1] = true

            @testset "Tables.jl with custom columns" begin
                custom_cols = [
                    SymbolicRegression.HallOfFameModule.HOFColumn(
                        :complexity, "C", row -> row.complexity, string, 5, :right
                    ),
                    SymbolicRegression.HallOfFameModule.HOFColumn(
                        :loss, "L", row -> row.loss, x -> @sprintf("%.2e", x), 8, :right
                    ),
                ]

                rows = SymbolicRegression.HallOfFameModule.hof_rows(
                    hof, dataset, options; columns=custom_cols
                )

                # Test schema
                schema = Tables.schema(rows)
                @test schema !== nothing
                @test schema.names == (:complexity, :loss)

                # Test columntable
                ct = Tables.columntable(rows)
                @test haskey(ct, :complexity)
                @test haskey(ct, :loss)
                @test !haskey(ct, :equation)  # Not in custom columns
            end
        catch e
            @info "Skipping Tables.jl column spec tests: $e"
        end
    end
end
