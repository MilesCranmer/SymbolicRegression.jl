@testitem "Test JSON tracing" begin
    using SymbolicRegression
    using SymbolicRegression: TraceType
    using SymbolicRegression.EvolutionModule.TracingModule: initialize_trace!, write_trace
    using JSON
    include(joinpath(@__DIR__, "..", "..", "..", "test_params.jl"))

    base_dir = mktempdir()
    tracing_file = joinpath(base_dir, "pysr_trace.jsonl")
    X = 2 .* randn(Float32, 2, 1000)
    y = 3 * cos.(X[2, :]) + X[1, :] .^ 2 .- 2

    options = SymbolicRegression.Options(;
        binary_operators=(+, *, /, -),
        unary_operators=(cos,),
        use_tracing=true,
        tracing_file=tracing_file,
        populations=2,
        population_size=100,
        maxsize=20,
        complexity_of_operators=[cos => 2],
    )

    prototype = TraceType()
    prototype_file = joinpath(base_dir, "prototype.jsonl")
    initialize_trace!(prototype, options, prototype_file)
    @test isempty(prototype)
    @test length(readlines(prototype_file)) == 1

    hall_of_fame = equation_search(
        X, y; niterations=5, options=options, parallelism=:multithreading
    )
    write_trace(TraceType("loss" => Inf), options.tracing_file; append=true)

    contents = read(options.tracing_file, String)
    records = [JSON.parse(line; allownan=true) for line in eachline(IOBuffer(contents))]
    search_record = first(records)
    iteration_records = records[2:(end - 1)]
    nonfinite_record = last(records)

    @test endswith(contents, '\n')
    @test search_record["schema_version"] == 1
    @test search_record["record_type"] == "search"
    @test contains(search_record["options"], "Options")
    @test search_record["started_at"] isa Real
    @test nonfinite_record["loss"] == Inf

    @test !isempty(iteration_records)
    @test all(record -> record["schema_version"] == 1, iteration_records)
    @test all(record -> record["record_type"] == "iteration", iteration_records)
    @test all(record -> record["output"] == 1, iteration_records)
    @test Set(record["population"] for record in iteration_records) == Set((1, 2))
    @test all(
        record -> length(record["members"]) == options.population_size, iteration_records
    )
    @test all(record -> haskey(record, "mutations"), iteration_records)

    for population in 1:(options.populations)
        iterations = sort([
            record["iteration"] for
            record in iteration_records if record["population"] == population
        ])
        @test iterations == collect(0:(length(iterations) - 1))
    end

    mutations = [
        mutation for record in iteration_records for mutation in values(record["mutations"])
    ]
    @test length(mutations) > 1000
    for mutation in mutations[1:10]
        for key in ("events", "cost", "tree", "loss", "parent")
            @test haskey(mutation, key)
        end
    end
end
