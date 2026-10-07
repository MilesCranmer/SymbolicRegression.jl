@testitem "trace_optimization! seeds missing old ref" begin
    using SymbolicRegression
    using SymbolicRegression: Options, TraceType, PopMember, Expression
    using SymbolicRegression.EvolutionModule.TracingModule: trace_optimization!
    using Test

    options = Options(; binary_operators=(+, *), default_plugins=(), use_tracing=true)
    mutations = TraceType()
    old_member = TraceType(
        "tree" => "x1", "cost" => 2.0, "loss" => 2.0, "parent" => 0, "ref" => 1
    )
    trace = TraceType("members" => [old_member], "mutations" => mutations)
    expression = Expression(Node{Float64}(; feature=1); operators=options.operators)
    member = PopMember(expression, 1.0, 1.0; deterministic=true)
    member.ref = 2
    member.parent = 1

    # Survivor from a previous iteration that was not recorded in this
    # iteration's `mutations` must not raise KeyError.
    trace_optimization!(trace, member, 1, 2, false, options)

    @test haskey(mutations, "2")
    @test haskey(mutations, "1")
    old_entry = mutations["1"]
    @test all(
        old_entry[key] == old_member[key] for key in ("tree", "cost", "loss", "parent")
    )
    events = old_entry["events"]
    @test [e["type"] for e in events] == ["tuning", "death"]
end

@testitem "trace_optimization! tolerates a reference held by several slots" begin
    using SymbolicRegression
    using SymbolicRegression: Options, TraceType, PopMember, Expression
    using SymbolicRegression.EvolutionModule.TracingModule: trace_optimization!
    using Test

    options = Options(; binary_operators=(+, *), default_plugins=(), use_tracing=true)
    mutations = TraceType()
    old_member = TraceType(
        "tree" => "x1", "cost" => 2.0, "loss" => 2.0, "parent" => 0, "ref" => 1
    )

    # One reference occupying several slots, as migration leaves it.
    trace = TraceType("members" => [old_member, copy(old_member)], "mutations" => mutations)
    expression = Expression(Node{Float64}(; feature=1); operators=options.operators)
    member = PopMember(expression, 1.0, 1.0; deterministic=true)
    member.ref = 2
    member.parent = 1

    trace_optimization!(trace, member, 1, 2, false, options)

    old_entry = mutations["1"]
    @test all(
        old_entry[key] == old_member[key] for key in ("tree", "cost", "loss", "parent")
    )
    @test [e["type"] for e in old_entry["events"]] == ["tuning", "death"]
end

@testitem "Tracing worker pipeline smoke test" begin
    using Distributed: myid
    using SymbolicRegression
    using SymbolicRegression: Dataset, Options
    using Test

    dataset = Dataset(randn(1, 20), randn(20))
    options = Options(;
        binary_operators=(+, *), default_plugins=(), use_tracing=true, population_size=20
    )
    @test isnothing(
        SymbolicRegression.test_entire_pipeline([myid()], dataset, options, 0, (), ())
    )
end

@testitem "Tracing requires JSON.jl" begin
    using SymbolicRegression: TraceType
    using SymbolicRegression.EvolutionModule: write_trace
    using Test

    err = try
        write_trace(TraceType("loss" => Inf), tempname())
        nothing
    catch caught
        caught
    end
    @test err isa ErrorException
    @test err.msg == "Please load the JSON.jl package."
end

@testitem "Disabled tracing is allocation-free" begin
    using SymbolicRegression: Options, TraceType
    using SymbolicRegression.EvolutionModule:
        initialize_trace!,
        new_trace,
        next_trace_iteration,
        trace_iteration_start!,
        write_trace
    using SymbolicRegression.EvolutionModule.TracingModule:
        new_step_trace,
        new_traced_steps,
        reset_traced_steps!,
        trace_crossover!,
        trace_identity_mutation!,
        trace_mutation_attempts!,
        trace_mutation_result!,
        trace_mutation_step!,
        trace_mutation_type!,
        trace_optimization!
    using Test

    options = Options(; binary_operators=(+, *), default_plugins=())

    @test new_trace(options) === nothing
    @test new_trace(nothing) === nothing
    @test new_step_trace(nothing) === nothing
    @test new_traced_steps(nothing, Int) === nothing
    @test reset_traced_steps!(nothing) === nothing
    @test trace_mutation_step!(nothing, nothing, nothing, nothing) === nothing
    disabled_steps = Any[]
    @test trace_mutation_step!(disabled_steps, nothing, nothing, nothing) === nothing
    @test isempty(disabled_steps)
    @test trace_mutation_type!(nothing, "optimize") === nothing
    @test trace_mutation_result!(nothing, "reject", "acceptance") === nothing
    @test trace_identity_mutation!(nothing) === nothing
    @test initialize_trace!(nothing, options, "unused.jsonl") === nothing
    @test write_trace(nothing, "unused.jsonl") === nothing
    @test next_trace_iteration(nothing) == 0
    @test trace_iteration_start!(nothing, 1, 1, 0, nothing, options) === nothing
    @test trace_optimization!(nothing, nothing, 1, 2, false, options) === nothing
    @test trace_mutation_attempts!(nothing, nothing, nothing, 1, false, 0, options) ===
        nothing
    @test trace_crossover!(
        nothing, nothing, nothing, nothing, nothing, nothing, 1, 2, nothing, options
    ) === nothing

    @test @allocated(new_trace(options)) == 0
    @test @allocated(new_trace(nothing)) == 0
    @test @allocated(new_step_trace(nothing)) == 0
    @test @allocated(new_traced_steps(nothing, Int)) == 0
    @test @allocated(reset_traced_steps!(nothing)) == 0
    @test @allocated(trace_mutation_step!(nothing, nothing, nothing, nothing)) == 0
    @test @allocated(trace_mutation_type!(nothing, "optimize")) == 0
    @test @allocated(trace_mutation_result!(nothing, "reject", "acceptance")) == 0
    @test @allocated(trace_identity_mutation!(nothing)) == 0
    @test @allocated(initialize_trace!(nothing, options, "unused.jsonl")) == 0
    @test @allocated(write_trace(nothing, "unused.jsonl")) == 0
    @test @allocated(next_trace_iteration(nothing)) == 0
    @test @allocated(trace_iteration_start!(nothing, 1, 1, 0, nothing, options)) == 0
    @test @allocated(trace_optimization!(nothing, nothing, 1, 2, false, options)) == 0
    @test @allocated(
        trace_mutation_attempts!(nothing, nothing, nothing, 1, false, 0, options)
    ) == 0
    @test @allocated(
        trace_crossover!(
            nothing, nothing, nothing, nothing, nothing, nothing, 1, 2, nothing, options
        )
    ) == 0

    enabled_options = Options(;
        binary_operators=(+, *), default_plugins=(), use_tracing=true
    )
    trace = new_trace(enabled_options)
    @test trace isa TraceType
    trace_mutation_type!(trace, "mutate_constant")
    trace_mutation_result!(trace, "accept", "pass")
    @test trace ==
        TraceType("type" => "mutate_constant", "result" => "accept", "reason" => "pass")
    trace["iteration"] = 4
    @test next_trace_iteration(trace) == 5
end
