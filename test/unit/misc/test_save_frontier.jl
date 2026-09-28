@testitem "Save frontier only when its members or values change" begin
    using SymbolicRegression
    using SymbolicRegression.SearchUtilsModule:
        FrontierSaveState, RuntimeOptions, save_frontier_if_changed!
    using Test

    X = reshape([1.0, 2.0, 3.0], 1, :)
    dataset = Dataset(X, vec(X))
    tmpdir = mktempdir()
    options = Options(;
        binary_operators=(+,),
        unary_operators=(),
        output_directory=tmpdir,
        save_to_file=true,
    )
    ropt = RuntimeOptions(; run_id="frontier-change")
    hof = HallOfFame(options, dataset)
    expression = Expression(
        Node{Float64}(; feature=1); operators=nothing, variable_names=nothing
    )
    hof.members[1] = PopMember(dataset, expression, options; deterministic=true)
    hof.exists[1] = true
    cache = FrontierSaveState(hof)
    save() = save_frontier_if_changed!(
        cache, hof, calculate_pareto_frontier(hof), 1, 1, dataset, options, ropt
    )
    csv_file = joinpath(tmpdir, ropt.run_id, "hall_of_fame.csv")

    @test save()
    @test read(csv_file, String) == read(csv_file * ".bak", String)
    write(csv_file, "sentinel")
    @test !save()
    @test read(csv_file, String) == "sentinel"

    hof.members[1] = copy(hof.members[1])
    @test save()
    @test read(csv_file, String) != "sentinel"
    write(csv_file, "sentinel")
    hof.members[1].cost += 1
    @test save()
    @test read(csv_file, String) != "sentinel"
    write(csv_file, "sentinel")
    hof.members[1].loss += 1
    @test save()
    @test read(csv_file, String) != "sentinel"
    @test occursin(",1.0,", read(csv_file, String))
end

@testitem "Saved CSV matches the live frontier throughout search" begin
    using SymbolicRegression
    using Test

    struct FrontierCsvProbe <: SymbolicRegression.AbstractPlugin
        checked::Base.RefValue{Int}
    end

    function SymbolicRegression.on_generation_end!(
        ::Nothing, probe::FrontierCsvProbe, search_state, dataset, options, ropt, population
    )
        frontier = calculate_pareto_frontier(only(search_state.halls_of_fame))
        csv_file = joinpath(options.output_directory, ropt.run_id, "hall_of_fame.csv")
        content = read(csv_file, String)
        @test content == read(csv_file * ".bak", String)
        rows = filter(!isempty, split(content, '\n'))
        @test first(rows) == "Complexity,Loss,Equation"
        @test length(rows) - 1 == length(frontier)
        for (row, member) in zip(rows[2:end], frontier)
            complexity, loss, equation = split(row, ','; limit=3)
            @test parse(Int, complexity) == compute_complexity(member, options)
            @test parse(typeof(member.loss), loss) == member.loss
            @test strip(equation, '"') == string_tree(
                member.tree, options; variable_names=dataset.variable_names, pretty=false
            )
        end
        probe.checked[] += 1
        return nothing
    end

    X = reshape(collect(range(-2.0, 2.0; length=24)), 1, :)
    y = @. X[1, :]^2 + X[1, :]
    checked = Ref(0)
    options = Options(;
        binary_operators=(+, *),
        unary_operators=(),
        populations=2,
        population_size=20,
        ncycles_per_iteration=20,
        progress=false,
        verbosity=0,
        seed=0,
        deterministic=true,
        save_to_file=true,
        output_directory=mktempdir(),
        plugins=(FrontierCsvProbe(checked),),
        default_plugins=(),
    )
    equation_search(X, y; options, niterations=3, parallelism=:serial)
    @test checked[] == 6
end
