@testitem "AdaptiveMutationWeightsPlugin: defaults + state" begin
    using SymbolicRegression
    using Test

    opts = Options(;
        binary_operators=[+, *],
        unary_operators=[sin],
        plugins=(AdaptiveMutationWeightsPlugin(),),
    )
    s = SymbolicRegression.init_plugin_state(AdaptiveMutationWeightsPlugin(), opts, nothing)
    @test length(s.attempts) == length(opts.mutations)
    @test all(s.multipliers .== 1.0)
    @test AdaptiveMutationWeightsPlugin().reward === :cost
    @test AdaptiveMutationWeightsPlugin().adaptation_strength == 0.5
    @test count(p -> p isa AdaptiveMutationWeightsPlugin, opts.plugins) == 1
    @test !any(p -> p isa MutationBurstPlugin, opts.plugins)
    @test isempty(Options(; default_plugins=()).plugins)
end

@testitem "AdaptiveMutationWeightsPlugin updates sampled operator and normalizes" begin
    using SymbolicRegression
    using SymbolicRegression: MutationEvent, init_plugin_state, on_mutation_end!
    using Test

    options = Options(;
        default_mutations=(),
        mutations=(ConstantMutation() => 1.0, OperatorMutation() => 1.0),
        default_plugins=(),
    )
    plugin = AdaptiveMutationWeightsPlugin(; smoothing=0.2, reward=:loss)
    state = init_plugin_state(plugin, options, nothing)

    on_mutation_end!(
        state,
        plugin,
        ConstantMutation(),
        MutationEvent(true, 1.0, 0.5, 1.0, 0.5, 1),
        nothing,
        options,
    )

    updated = 0.8 + 0.2 * ((2 / 3) / (3 / 5))
    normalizer = (updated + 1.0) / 2
    @test state.multipliers ≈ [updated / normalizer, 1.0 / normalizer]
    @test sum(state.multipliers) / length(state.multipliers) ≈ 1.0
end

@testitem "AdaptiveMutationWeightsPlugin regularizes multipliers in log space" begin
    using SymbolicRegression
    using SymbolicRegression: condition_mutation_weights!, init_plugin_state
    using Test

    options = Options(;
        default_mutations=(),
        mutations=(ConstantMutation() => 2.0, OperatorMutation() => 3.0),
        default_plugins=(),
    )
    learned_multipliers = [4.0, 0.25]

    function conditioned_weights(adaptation_strength)
        plugin = AdaptiveMutationWeightsPlugin(; adaptation_strength)
        state = init_plugin_state(plugin, options, nothing)
        state.multipliers .= learned_multipliers
        weights = collect(options.mutations)
        condition_mutation_weights!(weights, state, plugin, nothing, options, 20, 2)
        return last.(weights)
    end

    @test conditioned_weights(0.0) ≈ [2.0, 3.0]
    @test conditioned_weights(0.25) ≈ [2.0 * sqrt(2.0), 3.0 / sqrt(2.0)]
    @test conditioned_weights(0.5) ≈ [4.0, 1.5]
    @test conditioned_weights(1.0) ≈ [8.0, 0.75]

    plugin = AdaptiveMutationWeightsPlugin()
    state = init_plugin_state(plugin, options, nothing)
    weights = collect(options.mutations)
    condition_mutation_weights!(weights, state, plugin, nothing, options, 20, 2)
    copyto!(weights, options.mutations)
    @test @allocated(
        condition_mutation_weights!(weights, state, plugin, nothing, options, 20, 2)
    ) == 0
end

@testitem "skipped mutation kinds stay out of adaptive-weights accounting" begin
    using SymbolicRegression
    using SymbolicRegression: MutationEvent, init_plugin_state, on_mutation_end!
    import SymbolicRegression.PluginsModule.AdaptiveMutationWeightsModule:
        skip_in_adaptive_weights
    using Test

    struct SkippedMutation <: AbstractMutation end
    skip_in_adaptive_weights(::SkippedMutation) = true

    options = Options(;
        default_mutations=(),
        mutations=(ConstantMutation() => 1.0, SkippedMutation() => 1.0),
        plugins=(AdaptiveMutationWeightsPlugin(),),
        default_plugins=(),
    )
    plugin = only(options.plugins)
    state = init_plugin_state(plugin, options, nothing)

    on_mutation_end!(
        state,
        plugin,
        ConstantMutation(),
        MutationEvent(true, 1.0, 0.5, 1.0, 0.5, 1),
        nothing,
        options,
    )
    @test state.attempts == [1.0, 0.0]
    @test state.multipliers[2] == 1.0
end

@testitem "AdaptiveMutationWeightsPlugin rewards the configured objective" begin
    using SymbolicRegression
    using SymbolicRegression: MutationEvent, init_plugin_state, on_mutation_end!
    using Test

    options = Options(;
        default_mutations=(), mutations=(ConstantMutation() => 1.0,), default_plugins=()
    )
    event = MutationEvent(true, 1.0, 0.5, 1.0, 2.0, 1)

    cost_plugin = AdaptiveMutationWeightsPlugin(; reward=:cost)
    cost_state = init_plugin_state(cost_plugin, options, nothing)
    on_mutation_end!(cost_state, cost_plugin, ConstantMutation(), event, nothing, options)
    @test cost_state.successes == [1.0]

    loss_plugin = AdaptiveMutationWeightsPlugin(; reward=:loss)
    loss_state = init_plugin_state(loss_plugin, options, nothing)
    on_mutation_end!(loss_state, loss_plugin, ConstantMutation(), event, nothing, options)
    @test loss_state.successes == [0.0]
end

@testitem "Plugin constructors validate parameter domains" begin
    using SymbolicRegression
    using Test

    @test_throws ArgumentError AdaptiveMutationWeightsPlugin(; smoothing=-0.1)
    @test_throws ArgumentError AdaptiveMutationWeightsPlugin(; smoothing=1.1)
    @test_throws ArgumentError AdaptiveMutationWeightsPlugin(; floor=0.0)
    @test_throws ArgumentError AdaptiveMutationWeightsPlugin(; floor=1.1)
    @test_throws ArgumentError AdaptiveMutationWeightsPlugin(; reward=:unknown)
    @test_throws ArgumentError AdaptiveMutationWeightsPlugin(; adaptation_strength=-0.1)
    @test_throws ArgumentError AdaptiveMutationWeightsPlugin(; adaptation_strength=1.1)
    @test_throws ArgumentError MutationBurstPlugin(; retry_attempts=0)
    @test_throws ArgumentError MutationBurstPlugin(; compound_probability=-0.1)
    @test_throws ArgumentError MutationBurstPlugin(; compound_probability=1.1)
    @test_throws ArgumentError MutationBurstPlugin(; compound_max_steps=0)
    @test_throws ArgumentError SimulatedAnnealingPlugin(; alpha=0.0)
    @test_throws ArgumentError SimulatedAnnealingPlugin(; alpha=-0.1)
    @test_throws ArgumentError SimulatedAnnealingPlugin(; alpha=Inf)
    @test_throws ArgumentError SimulatedAnnealingPlugin(; alpha=big"1e10000")
    @test_throws ArgumentError AdaptiveMutationWeightsPlugin(; floor=big"1e-10000")
end

@testitem "SimulatedAnnealingPlugin uses the requested cycle count" begin
    using SymbolicRegression
    using SymbolicRegression.PluginsModule.SimulatedAnnealingModule: SimulatedAnnealingState
    using Test

    plugin = SimulatedAnnealingPlugin()
    state = SimulatedAnnealingState(0.5)
    options = Options(; ncycles_per_iteration=100)

    SymbolicRegression.on_cycle_start!(state, plugin, 1, 3, options)
    @test state.temperature == 1.0
    SymbolicRegression.on_cycle_start!(state, plugin, 2, 3, options)
    @test state.temperature == 0.5
    let ctx = SymbolicRegression.prepare_mutation_context(ConstantMutation())
        SymbolicRegression.condition_mutation!(
            ctx, state, plugin, ConstantMutation(), options
        )
        @test ctx.scale == 0.5
    end
    SymbolicRegression.on_cycle_start!(state, plugin, 3, 3, options)
    @test state.temperature == 0.0
    SymbolicRegression.on_cycle_start!(state, plugin, 1, 1, options)
    @test state.temperature == 1.0

    for (cycle_idx, temperature) in enumerate(LinRange(1.0, 0.0, 550))
        SymbolicRegression.on_cycle_start!(state, plugin, cycle_idx, 550, options)
        @test state.temperature === temperature
    end
end

@testitem "prepare_mutation_context / condition_mutation!" begin
    using SymbolicRegression
    using SymbolicRegression:
        AbstractPlugin,
        ConstantMutationContext,
        prepare_mutation_context,
        condition_mutation!
    using SymbolicRegression.PluginsModule.SimulatedAnnealingModule: SimulatedAnnealingState
    using Test

    @test prepare_mutation_context(OperatorMutation()) === nothing
    ctx = prepare_mutation_context(ConstantMutation())
    @test ctx isa ConstantMutationContext
    @test ctx.scale == 1.0

    struct _CtxNoopPlugin <: AbstractPlugin end
    opts = Options()
    @test condition_mutation!(ctx, nothing, _CtxNoopPlugin(), ConstantMutation(), opts) ===
        nothing
    @test ctx.scale == 1.0

    plugin = SimulatedAnnealingPlugin()
    state = SimulatedAnnealingState(0.25)
    condition_mutation!(ctx, state, plugin, ConstantMutation(), opts)
    @test ctx.scale == 0.25
    condition_mutation!(ctx, state, plugin, ConstantMutation(), opts)
    @test ctx.scale == 0.0625
end

@testitem "AdaptiveMutationWeightsPlugin attributes configured instances" begin
    using SymbolicRegression
    using SymbolicRegression: MutationEvent, init_plugin_state, on_mutation_end!
    using Test

    first_mutation = ConstantMutation(; perturbation_factor=0.1)
    second_mutation = ConstantMutation(; perturbation_factor=0.2)
    options = Options(;
        default_mutations=(),
        mutations=(first_mutation => 1.0, second_mutation => 1.0),
        plugins=(AdaptiveMutationWeightsPlugin(),),
        default_plugins=(),
    )
    plugin = only(options.plugins)
    state = init_plugin_state(plugin, options, nothing)

    # Attribution follows `event.mutation_idx`, not instance identity: the
    # dispatch arg is the first instance, but the index names slot 2.
    on_mutation_end!(
        state,
        plugin,
        first_mutation,
        MutationEvent(true, 1.0, 0.5, 1.0, 0.5, 2),
        nothing,
        options,
    )
    @test state.attempts == [0.0, 1.0]
    @test state.successes == [0.0, 1.0]

    on_mutation_end!(
        state,
        plugin,
        first_mutation,
        MutationEvent(true, 1.0, 0.5, 1.0, 0.5, 1),
        nothing,
        options,
    )
    allocs = @allocated on_mutation_end!(
        state,
        plugin,
        first_mutation,
        MutationEvent(true, 1.0, 0.5, 1.0, 0.5, 1),
        nothing,
        options,
    )
    @test allocs == 0
end

@testitem "MutationBurstPlugin: retry portion retries until accepted" begin
    using SymbolicRegression
    using SymbolicRegression: MutationStepResult, wrap_mutation_step
    using Test

    n_calls = Ref(0)
    inner = parent -> begin
        n_calls[] += 1
        MutationStepResult(parent, n_calls[] >= 3, 1, 0.0)
    end
    p = MutationBurstPlugin(;
        retry_attempts=4, compound_probability=0.0, compound_max_steps=1
    )
    result = something(wrap_mutation_step(nothing, p))(:parent, inner)
    @test result.accepted == true
    @test n_calls[] == 3
end

@testitem "MutationBurstPlugin: retry stops at budget when never accepted" begin
    using SymbolicRegression
    using SymbolicRegression: MutationStepResult, wrap_mutation_step
    using Test

    n_calls = Ref(0)
    inner = parent -> begin
        n_calls[] += 1
        MutationStepResult(parent, false, 1, 0.0)
    end
    p = MutationBurstPlugin(;
        retry_attempts=4, compound_probability=0.0, compound_max_steps=1
    )
    result = something(wrap_mutation_step(nothing, p))(:parent, inner)
    @test result.accepted == false
    @test n_calls[] == 4
end

@testitem "MutationBurstPlugin: compound portion chains on success" begin
    using SymbolicRegression
    using SymbolicRegression: MutationStepResult, wrap_mutation_step
    using Random
    using Test

    n_calls = Ref(0)
    inner = parent -> begin
        n_calls[] += 1
        MutationStepResult(parent + 1, true, 1, 0.0)
    end
    p = MutationBurstPlugin(;
        retry_attempts=1, compound_probability=1.0, compound_max_steps=3
    )
    Random.seed!(0)
    result = something(wrap_mutation_step(nothing, p))(0, inner)
    @test result.accepted == true
    @test n_calls[] == 3
    @test result.member == 3
end

@testitem "MutationBurstPlugin: compound doesn't chain on rejection" begin
    using SymbolicRegression
    using SymbolicRegression: MutationStepResult, wrap_mutation_step
    using Test

    n_calls = Ref(0)
    inner = parent -> begin
        n_calls[] += 1
        MutationStepResult(parent, false, 1, 0.0)
    end
    p = MutationBurstPlugin(;
        retry_attempts=1, compound_probability=1.0, compound_max_steps=3
    )
    result = something(wrap_mutation_step(nothing, p))(0, inner)
    @test result.accepted == false
    @test n_calls[] == 1
end

@testitem "MutationBurstPlugin traces every compound mutation" begin
    using SymbolicRegression
    using SymbolicRegression: Dataset, TraceType, init_plugin_state
    using SymbolicRegression.EvolutionModule.RegularizedEvolutionModule: reg_evol_cycle
    using Test

    plugin = MutationBurstPlugin(;
        retry_attempts=1, compound_probability=1.0, compound_max_steps=3
    )
    options = Options(;
        default_mutations=(),
        mutations=(DoNothingMutation() => 1.0,),
        plugins=(plugin,),
        default_plugins=(),
        crossover_probability=0.0,
        population_size=2,
        tournament_selection_n=1,
        use_tracing=true,
    )
    dataset = Dataset(zeros(1, 8), zeros(8))
    plugin_states = (init_plugin_state(plugin, options, dataset),)
    population = Population(
        dataset; population_size=2, nlength=1, options, nfeatures=1, plugin_states
    )
    trace = TraceType()

    reg_evol_cycle(
        dataset,
        population,
        options.maxsize,
        options,
        trace;
        plugin_states,
        best_seen=SymbolicRegression.HallOfFame(options, dataset),
    )

    mutation_events = Tuple{String,TraceType}[]
    for (parent, member_trace) in trace["mutations"]
        for event in member_trace["events"]
            event["type"] == "mutate" && push!(mutation_events, (parent, event))
        end
    end
    @test length(mutation_events) == 3 * options.population_size
    @test count(event -> event[2]["selected"], mutation_events) == options.population_size
    for (parent, event) in mutation_events
        child = trace["mutations"]["$(event["child"])"]
        @test child["parent"] == parse(Int, parent)
        @test event["mutation"]["type"] == "identity"
    end
end

@testitem "build_mutation_step composes type-stably" begin
    using SymbolicRegression
    using SymbolicRegression: AbstractPlugin
    using SymbolicRegression.EvolutionModule.RegularizedEvolutionModule: build_mutation_step
    using Test

    struct _TagPluginA <: AbstractPlugin end
    struct _TagPluginB <: AbstractPlugin end
    function SymbolicRegression.wrap_mutation_step(tag::Symbol, ::_TagPluginA)
        return (parent, next_step) -> next_step((parent..., tag))
    end
    function SymbolicRegression.wrap_mutation_step(tag::Symbol, ::_TagPluginB)
        return (parent, next_step) -> next_step((parent..., tag))
    end

    base = parent -> SymbolicRegression.MutationStepResult(parent, true, 1, 0.0)

    step0 = build_mutation_step((), base)
    @test step0 === base
    @test @inferred(step0(())).member == ()

    wrappers1 = map(SymbolicRegression.wrap_mutation_step, (:a,), (_TagPluginA(),))
    step1 = build_mutation_step(wrappers1, base)
    @test @inferred(step1(())).member == (:a,)

    # Plugin 1 is outermost, so its tag is appended first.
    wrappers2 = map(
        SymbolicRegression.wrap_mutation_step, (:a, :b), (_TagPluginA(), _TagPluginB())
    )
    step2 = build_mutation_step(wrappers2, base)
    @test @inferred(step2(())).member == (:a, :b)
end

@testitem "trace captures rejected retry branches" begin
    using SymbolicRegression
    using SymbolicRegression:
        Dataset, TraceType, init_plugin_state, MutationAcceptanceContext
    using SymbolicRegression.EvolutionModule.RegularizedEvolutionModule: reg_evol_cycle
    using Test

    struct _AlwaysRejectPlugin <: SymbolicRegression.AbstractPlugin end
    function SymbolicRegression.mutation_acceptance_multiplier(
        _, ::_AlwaysRejectPlugin, ctx::MutationAcceptanceContext, options
    )
        return 0.0
    end

    loop = MutationBurstPlugin(;
        retry_attempts=3, compound_probability=0.0, compound_max_steps=1
    )
    options = Options(;
        default_mutations=(),
        mutations=(ConstantMutation() => 1.0,),
        plugins=(loop, _AlwaysRejectPlugin()),
        default_plugins=(),
        crossover_probability=0.0,
        population_size=2,
        tournament_selection_n=1,
        use_tracing=true,
        skip_mutation_failures=true,
    )
    dataset = Dataset(randn(1, 8), randn(8))
    plugin_states = (init_plugin_state(loop, options, dataset), nothing)
    member = PopMember(dataset, Node(Float64; val=1.0), options; deterministic=false)
    population = Population([member, copy(member)])
    trace = TraceType()

    reg_evol_cycle(
        dataset,
        population,
        options.maxsize,
        options,
        trace;
        plugin_states,
        best_seen=SymbolicRegression.HallOfFame(options, dataset),
    )

    n_mutate_events, n_selected_events, n_death_events = let
        n_mutate = 0
        n_selected = 0
        n_death = 0
        for (_, member_trace) in trace["mutations"]
            for event in member_trace["events"]
                if event["type"] == "mutate"
                    n_mutate += 1
                    n_selected += event["selected"]
                elseif event["type"] == "death"
                    n_death += 1
                end
            end
        end
        (n_mutate, n_selected, n_death)
    end
    # Every rejected retry is its own traced event: retry_attempts per
    # tournament round, population_size rounds.
    @test n_mutate_events == 3 * options.population_size
    @test n_selected_events == options.population_size
    @test n_death_events == 0
end

@testitem "trace captures accepted mutations" begin
    using SymbolicRegression
    using SymbolicRegression: Dataset, TraceType
    using SymbolicRegression.EvolutionModule.MutateModule: next_generation
    using Test

    options = Options(;
        default_mutations=(),
        mutations=(ConstantMutation() => 1.0,),
        default_plugins=(),
        use_tracing=true,
    )
    dataset = Dataset(zeros(1, 8), zeros(8))
    member = PopMember(dataset, Node(Float64; val=1.0), options; deterministic=false)
    trace = TraceType()

    _, accepted, _ = next_generation(
        dataset, member, options.maxsize, options; tmp_trace=trace, plugin_states=()
    )

    @test accepted
    @test trace["result"] == "accept"
    @test trace["reason"] == "pass"
end

@testitem "reg_evol_cycle owns middleware evaluation accounting" begin
    using SymbolicRegression
    using SymbolicRegression: AbstractPlugin, Dataset, MutationResult, TraceType
    using SymbolicRegression.EvolutionModule.RegularizedEvolutionModule: reg_evol_cycle
    using Test

    struct CountedMutation <: AbstractMutation end
    function SymbolicRegression.mutate!(
        tree::N, ::P, ::CountedMutation, options; kws...
    ) where {N,P}
        return MutationResult{N,P}(; tree, num_evals=1.0)
    end

    struct KeepFirstOfTwoPlugin <: AbstractPlugin end
    function SymbolicRegression.wrap_mutation_step(_, ::KeepFirstOfTwoPlugin)
        return function (parent, next_step)
            first_result = next_step(parent)
            next_step(parent)
            return first_result
        end
    end

    struct SkipMutationPlugin <: AbstractPlugin end
    function SymbolicRegression.wrap_mutation_step(_, ::SkipMutationPlugin)
        return (parent, next_step) ->
            SymbolicRegression.MutationStepResult(parent, true, 0, 0.0)
    end

    struct FabricateMutationPlugin <: AbstractPlugin end
    function SymbolicRegression.wrap_mutation_step(_, ::FabricateMutationPlugin)
        return function (parent, next_step)
            next_step(parent)
            return SymbolicRegression.MutationStepResult(parent, true, 0, 0.0)
        end
    end

    struct ModifySelectedMutationPlugin <: AbstractPlugin end
    function SymbolicRegression.wrap_mutation_step(_, ::ModifySelectedMutationPlugin)
        return function (parent, next_step)
            result = next_step(parent)
            result.member.cost = -Inf
            return result
        end
    end

    plugin = KeepFirstOfTwoPlugin()
    options = Options(;
        default_mutations=(),
        mutations=(CountedMutation() => 1.0,),
        plugins=(plugin,),
        default_plugins=(),
        crossover_probability=0.0,
        population_size=2,
        tournament_selection_n=1,
    )
    dataset = Dataset(zeros(1, 8), zeros(8))
    plugin_states = (nothing,)
    population = Population(
        dataset; population_size=1, nlength=1, options, nfeatures=1, plugin_states
    )

    _, num_evals = reg_evol_cycle(
        dataset,
        population,
        options.maxsize,
        options,
        TraceType();
        plugin_states,
        best_seen=SymbolicRegression.HallOfFame(options, dataset),
    )
    @test num_evals == 4.0

    skip_options = Options(;
        default_mutations=(),
        mutations=(CountedMutation() => 1.0,),
        plugins=(SkipMutationPlugin(),),
        default_plugins=(),
        crossover_probability=0.0,
        population_size=2,
        tournament_selection_n=1,
    )
    @test_throws ArgumentError reg_evol_cycle(
        dataset,
        population,
        skip_options.maxsize,
        skip_options,
        TraceType();
        plugin_states=(nothing,),
        best_seen=SymbolicRegression.HallOfFame(skip_options, dataset),
    )

    fabricate_options = Options(;
        default_mutations=(),
        mutations=(CountedMutation() => 1.0,),
        plugins=(FabricateMutationPlugin(),),
        default_plugins=(),
        crossover_probability=0.0,
        population_size=2,
        tournament_selection_n=1,
    )
    @test_throws ArgumentError reg_evol_cycle(
        dataset,
        population,
        fabricate_options.maxsize,
        fabricate_options,
        TraceType();
        plugin_states=(nothing,),
        best_seen=SymbolicRegression.HallOfFame(fabricate_options, dataset),
    )

    modify_options = Options(;
        default_mutations=(),
        mutations=(CountedMutation() => 1.0,),
        plugins=(ModifySelectedMutationPlugin(),),
        default_plugins=(),
        crossover_probability=0.0,
        population_size=2,
        tournament_selection_n=1,
        skip_mutation_failures=false,
    )
    modified_population, _ = reg_evol_cycle(
        dataset,
        population,
        modify_options.maxsize,
        modify_options,
        TraceType();
        plugin_states=(nothing,),
        best_seen=SymbolicRegression.HallOfFame(modify_options, dataset),
    )
    @test all(member -> member.cost != -Inf, modified_population.members)
end

@testitem "MutationBurstPlugin preserves accepted intermediate Hall-of-Fame members" begin
    using SymbolicRegression
    using SymbolicRegression: Dataset, MutationResult, TraceType, init_plugin_state
    using SymbolicRegression.EvolutionModule.PopMemberModule: create_child
    using Test

    struct CostSequenceMutation <: AbstractMutation
        calls::Base.RefValue{Int}
    end
    function SymbolicRegression.mutate!(
        tree::N, parent::P, mutation::CostSequenceMutation, options; parent_ref, kws...
    ) where {N,P}
        mutation.calls[] += 1
        cost = Float64(mutation.calls[])
        child = create_child(parent, copy(tree), cost, cost, options; parent_ref=parent_ref)
        return MutationResult{N,P}(; member=child, return_immediately=true)
    end

    mutation = CostSequenceMutation(Ref(0))
    plugin = MutationBurstPlugin(;
        retry_attempts=1, compound_probability=1.0, compound_max_steps=2
    )
    options = Options(;
        default_mutations=(),
        mutations=(mutation => 1.0,),
        plugins=(plugin,),
        default_plugins=(),
        crossover_probability=0.0,
        population_size=2,
        tournament_selection_n=1,
        deterministic=true,
    )
    dataset = Dataset(zeros(1, 8), zeros(8))
    member = PopMember(dataset, Node(Float64; val=0.0), options; deterministic=true)
    member.cost = 10.0
    member.loss = 10.0
    population = Population([member])
    plugin_states = (init_plugin_state(plugin, options, dataset),)

    final_population, best_seen, _ = s_r_cycle(
        dataset, population, 1, options.maxsize; options, trace=TraceType(), plugin_states
    )

    @test only(final_population.members).cost == 2.0
    @test best_seen.members[1].cost == 1.0
end

@testitem "mutation-cycle entry points require plugin state" begin
    using SymbolicRegression
    using SymbolicRegression:
        AbstractPlugin, Dataset, MutationEvent, TraceType, init_plugin_state
    using SymbolicRegression.EvolutionModule.MutateModule: next_generation
    using Test

    struct MutationCounterPlugin <: AbstractPlugin
        calls::Base.RefValue{Int}
    end
    SymbolicRegression.init_plugin_state(plugin::MutationCounterPlugin, options, dataset) =
        plugin.calls
    function SymbolicRegression.on_mutation_end!(
        calls::Base.RefValue{Int},
        ::MutationCounterPlugin,
        ::AbstractMutation,
        ::MutationEvent,
        dataset,
        options,
    )
        calls[] += 1
        return nothing
    end

    calls = Ref(0)
    plugin = MutationCounterPlugin(calls)
    options = Options(;
        default_mutations=(),
        mutations=(DoNothingMutation() => 1.0,),
        plugins=(plugin,),
        default_plugins=(),
        crossover_probability=0.0,
        population_size=2,
        tournament_selection_n=1,
    )
    dataset = Dataset(zeros(1, 8), zeros(8))
    member = PopMember(dataset, Node(Float64; val=0.0), options; deterministic=false)
    plugin_states = (init_plugin_state(plugin, options, dataset),)

    next_generation(
        dataset, member, options.maxsize, options; tmp_trace=TraceType(), plugin_states
    )
    @test calls[] == 1
    @test_throws UndefKeywordError next_generation(
        dataset, member, options.maxsize, options; tmp_trace=TraceType()
    )

    population = Population([member])
    @test_throws UndefKeywordError Population(
        dataset; population_size=2, options, nfeatures=1
    )
    @test s_r_cycle(
        dataset, population, 1, options.maxsize; options, trace=TraceType(), plugin_states
    ) isa Tuple
    @test_throws UndefKeywordError s_r_cycle(
        dataset, population, 1, options.maxsize; options, trace=TraceType()
    )
end

@testitem "worker plugin state persists across dispatches" begin
    using SymbolicRegression
    using SymbolicRegression: AbstractPlugin, MutationEvent
    using Test

    struct PersistentPlugin <: AbstractPlugin
        observations::Channel{Int}
    end
    mutable struct PersistentPluginState
        mutations::Int
        observations::Channel{Int}
    end
    SymbolicRegression.init_plugin_state(plugin::PersistentPlugin, options, dataset) =
        PersistentPluginState(0, plugin.observations)
    SymbolicRegression.fork_plugin_state(
        state::PersistentPluginState, ::PersistentPlugin, dataset
    ) = PersistentPluginState(state.mutations, state.observations)
    function SymbolicRegression.on_cycle_start!(
        state::PersistentPluginState,
        ::PersistentPlugin,
        cycle_idx::Int,
        ncycles::Int,
        options,
    )
        cycle_idx == 1 && put!(state.observations, state.mutations)
        return nothing
    end
    function SymbolicRegression.on_mutation_end!(
        state::PersistentPluginState,
        ::PersistentPlugin,
        ::AbstractMutation,
        ::MutationEvent,
        dataset,
        options,
    )
        state.mutations += 1
        return nothing
    end

    observations = Channel{Int}(100)
    plugin = PersistentPlugin(observations)
    options = Options(;
        default_mutations=(),
        mutations=(DoNothingMutation() => 1.0,),
        plugins=(plugin,),
        default_plugins=(),
        populations=1,
        population_size=2,
        tournament_selection_n=1,
        ncycles_per_iteration=2,
        progress=false,
        verbosity=0,
        deterministic=true,
    )
    X = zeros(1, 8)
    y = zeros(8)

    equation_search(X, y; options, niterations=2, parallelism=:serial)
    close(observations)
    dispatch_starts = collect(observations)

    @test first(dispatch_starts) == 0
    @test any(>(0), dispatch_starts[2:end])
end

@testitem "worker plugin state may differ from head state" begin
    using SymbolicRegression
    using SymbolicRegression: AbstractPlugin
    using Test

    struct DistinctStatePlugin <: AbstractPlugin
        observations::Channel{Int}
    end
    mutable struct DistinctHeadState
        generation::Int
    end
    mutable struct DistinctWorkerState
        generation::Int
        observations::Channel{Int}
    end
    SymbolicRegression.init_plugin_state(::DistinctStatePlugin, options, dataset) =
        DistinctHeadState(0)
    SymbolicRegression.fork_plugin_state(
        state::DistinctHeadState, plugin::DistinctStatePlugin, dataset
    ) = DistinctWorkerState(state.generation, plugin.observations)
    function SymbolicRegression.refresh_worker_plugin_state(
        worker::DistinctWorkerState,
        latest_head::DistinctHeadState,
        ::DistinctStatePlugin,
        dataset,
    )
        worker.generation = latest_head.generation
        return worker
    end
    function SymbolicRegression.on_generation_end!(
        state::DistinctHeadState,
        ::DistinctStatePlugin,
        search_state,
        dataset,
        options,
        runtime_options,
        population,
    )
        state.generation += 1
        return nothing
    end
    function SymbolicRegression.on_search_start!(
        state::DistinctHeadState, ::DistinctStatePlugin, dataset, options, runtime_options
    )
        state.generation = 7
        return nothing
    end
    function SymbolicRegression.on_cycle_start!(
        state::DistinctWorkerState,
        ::DistinctStatePlugin,
        cycle_idx::Int,
        ncycles::Int,
        options,
    )
        cycle_idx == 1 && put!(state.observations, state.generation)
        return nothing
    end

    observations = Channel{Int}(100)
    options = Options(;
        default_mutations=(),
        mutations=(DoNothingMutation() => 1.0,),
        plugins=(DistinctStatePlugin(observations),),
        default_plugins=(),
        populations=1,
        population_size=2,
        tournament_selection_n=1,
        ncycles_per_iteration=2,
        progress=false,
        verbosity=0,
        deterministic=false,
    )
    X = zeros(1, 8)
    y = zeros(8)

    @test equation_search(X, y; options, niterations=2, parallelism=:serial) isa HallOfFame
    @test equation_search(X, y; options, niterations=2, parallelism=:multithreading) isa
        HallOfFame
    close(observations)
    observed_generations = collect(observations)
    @test first(observed_generations) == 7
    @test any(>(7), observed_generations)
end

@testitem "Integration: all three mechanisms enabled, search runs and returns a HoF" begin
    using SymbolicRegression
    using Random
    using Test

    Random.seed!(0)
    X = rand(Float32, 2, 60)
    y = @. 2.0f0 * X[1, :] + sin(X[2, :])

    opts = Options(;
        binary_operators=[+, -, *, /],
        unary_operators=[sin, cos],
        populations=4,
        population_size=20,
        ncycles_per_iteration=20,
        verbosity=0,
        progress=false,
        deterministic=true,
        plugins=(
            AdaptiveMutationWeightsPlugin(; smoothing=0.02, floor=0.05),
            MutationBurstPlugin(;
                retry_attempts=4, compound_probability=0.25, compound_max_steps=2
            ),
        ),
    )
    hof = equation_search(X, y; options=opts, niterations=3, parallelism=:serial)
    @test hof isa SymbolicRegression.HallOfFame
    @test any(hof.exists)
end
