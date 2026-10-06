@testitem "Plugin interface: types and defaults" begin
    using SymbolicRegression
    import SymbolicRegression:
        AbstractPlugin,
        init_plugin_state,
        init_plugin_states,
        strictmap,
        fork_plugin_state,
        refresh_worker_plugin_state,
        on_search_start!,
        on_search_end!,
        on_generation_end!,
        on_cycle_end!,
        on_cycle_start!,
        on_mutation_end!,
        init_member,
        tournament_cost_multiplier,
        mutation_acceptance_multiplier,
        MutationAcceptanceContext,
        wrap_mutation_step,
        prepare_mutation_context,
        condition_mutation!,
        condition_mutation_weights!,
        MutationEvent,
        MutationWeights
    using Test
    # No-plugin Options (legacy adaptive parsimony off, no auto-inject).
    opts = Options(;
        binary_operators=[+, *],
        use_frequency=false,
        use_frequency_in_tournament=false,
        annealing=false,
        default_plugins=(),
    )
    @test opts.plugins isa Tuple{}

    # Dummy plugin exercises every default hook contract.
    struct DummyPlugin <: AbstractPlugin end
    p = DummyPlugin()
    @test init_plugin_state(p, opts, nothing) === nothing
    plugin_opts = Options(;
        binary_operators=[+, *],
        use_frequency=false,
        use_frequency_in_tournament=false,
        annealing=false,
        plugins=(p,),
        default_plugins=(),
    )
    @test init_plugin_states(plugin_opts, nothing) === (nothing,)
    dataset = Dataset(randn(1, 4), randn(4))
    @test_throws DimensionMismatch Population(
        dataset; population_size=1, options=plugin_opts, nfeatures=1, plugin_states=()
    )
    callback_called = Ref(false)
    @test_throws DimensionMismatch strictmap((_, _) -> (callback_called[] = true), (p,), ())
    @test !callback_called[]
    s = nothing

    # Observers default to no-op (return nothing). Hooks follow the convention
    # (state, plugin, ...) so the mutated `state` is first.
    @test on_search_start!(s, p, nothing, opts, nothing) === nothing
    @test on_search_end!(s, p, nothing, nothing, opts, nothing) === nothing
    @test on_generation_end!(s, p, nothing, nothing, opts, nothing, nothing) === nothing
    @test on_cycle_end!(s, p, nothing, nothing, nothing, opts) === nothing
    @test on_mutation_end!(
        s, p, ConstantMutation(), MutationEvent(true, 0.5, 0.4, 0.5, 0.4, 1), nothing, opts
    ) === nothing
    @test MutationEvent(false, 1, nothing, 1, nothing, 1) isa MutationEvent{Int,Int}

    # Factory defaults: init_member returns nothing, fork_plugin_state
    # deepcopies the head state.
    @test init_member(s, p, nothing, opts) === nothing
    head = Ref(3)
    snap = fork_plugin_state(head, p, nothing)
    @test snap[] == head[]
    @test snap !== head
    @test refresh_worker_plugin_state(snap, head, p, nothing) === snap

    # Modifier defaults return 1.0 (multiplicative identity).
    @test tournament_cost_multiplier(s, p, nothing, opts) == 1.0
    acceptance_ctx = MutationAcceptanceContext(nothing, nothing, 0.0, 0.0)
    @test mutation_acceptance_multiplier(s, p, acceptance_ctx, opts) == 1.0

    @test wrap_mutation_step(s, p) === nothing

    # on_cycle_start! default is no-op.
    @test on_cycle_start!(s, p, 1, 3, opts) === nothing

    # Mutation contexts: no context by default; conditioning defaults to no-op.
    @test prepare_mutation_context(OperatorMutation()) === nothing
    @test condition_mutation!(
        prepare_mutation_context(ConstantMutation()), s, p, ConstantMutation(), opts
    ) === nothing

    # Conditioner default leaves weights untouched. `weights` is the mutated
    # arg → first; then state, then plugin.
    w = deepcopy(opts.mutations)
    before = deepcopy(w)
    @test condition_mutation_weights!(w, s, p, nothing, opts, 20, 2) === nothing
    @test w == before
end

@testitem "Plugin interface: operation defaults" begin
    using SymbolicRegression
    import SymbolicRegression:
        AbstractPlugin,
        AbstractMutation,
        AbstractCrossover,
        ConstantMutation,
        SubtreeCrossover,
        plugin_mutations,
        plugin_crossovers
    using Test

    struct PluginMutation <: AbstractMutation end
    struct PluginCrossover <: AbstractCrossover end
    struct OperationDefaultsPlugin <: AbstractPlugin end

    SymbolicRegression.plugin_mutations(::OperationDefaultsPlugin) =
        (PluginMutation() => 2.0, ConstantMutation() => 3.0)
    SymbolicRegression.plugin_crossovers(::OperationDefaultsPlugin) =
        (PluginCrossover() => 4.0, SubtreeCrossover() => 5.0)

    plugin = OperationDefaultsPlugin()
    @test plugin_mutations(plugin) == (PluginMutation() => 2.0, ConstantMutation() => 3.0)
    @test plugin_crossovers(plugin) == (PluginCrossover() => 4.0, SubtreeCrossover() => 5.0)

    options = Options(; binary_operators=[+, *], plugins=(plugin,), default_plugins=())
    @test first.(options.mutations)[1:2] == [PluginMutation(), ConstantMutation()]
    @test last.(options.mutations)[1:2] == [2.0, 3.0]
    @test count(pair -> pair.first isa ConstantMutation, options.mutations) == 1
    @test first.(options.crossovers) == [PluginCrossover(), SubtreeCrossover()]
    @test last.(options.crossovers) == [4.0, 5.0]

    overridden = Options(;
        binary_operators=[+, *],
        plugins=(plugin,),
        default_plugins=(),
        mutations=(PluginMutation() => 6.0,),
        crossovers=(PluginCrossover() => 7.0,),
    )
    @test first(overridden.mutations).first isa PluginMutation
    @test first(overridden.mutations).second == 6.0
    @test count(pair -> pair.first isa PluginMutation, overridden.mutations) == 1
    @test first(overridden.crossovers).first isa PluginCrossover
    @test first(overridden.crossovers).second == 7.0
    @test count(pair -> pair.first isa PluginCrossover, overridden.crossovers) == 1

    no_defaults = Options(;
        binary_operators=[+, *],
        plugins=(plugin,),
        default_plugins=(),
        default_mutations=(),
        default_crossovers=(),
    )
    @test isempty(no_defaults.mutations)
    @test isempty(no_defaults.crossovers)
end

@testitem "Plugin interface: lifecycle hooks called for each plugin" begin
    using SymbolicRegression
    import SymbolicRegression:
        AbstractPlugin,
        init_plugin_state,
        fork_plugin_state,
        on_search_start!,
        on_search_end!,
        on_generation_end!,
        on_cycle_end!
    using Test

    # Use a channel to safely count from multiple threads/tasks.
    counter_ch = Channel{Any}(10_000)

    struct LifecyclePlugin <: AbstractPlugin
        counter_ch::Channel{Any}
    end
    mutable struct LifecyclePluginState
        counter_ch::Channel{Any}
    end

    SymbolicRegression.init_plugin_state(p::LifecyclePlugin, options, datasets) =
        LifecyclePluginState(p.counter_ch)
    # Share the head state's channel with workers (default fork deepcopies,
    # which would isolate the channel and lose worker-side events).
    SymbolicRegression.fork_plugin_state(
        head::LifecyclePluginState, ::LifecyclePlugin, dataset
    ) = head
    SymbolicRegression.on_search_start!(s::LifecyclePluginState, ::LifecyclePlugin, d, o, r) = (
        put!(s.counter_ch, :start); nothing
    )
    SymbolicRegression.on_search_end!(s::LifecyclePluginState, ::LifecyclePlugin, ss, d, o, r) = (
        put!(s.counter_ch, :end); nothing
    )
    SymbolicRegression.on_generation_end!(s::LifecyclePluginState, ::LifecyclePlugin, ss, d, o, r, rp) = (
        put!(s.counter_ch, :gen); nothing
    )
    SymbolicRegression.on_cycle_end!(s::LifecyclePluginState, ::LifecyclePlugin, pop, d, h, o) = (
        put!(s.counter_ch, :cycle_end); put!(s.counter_ch, (:batch_size, d.n)); nothing
    )
    SymbolicRegression.on_cycle_start!(s::LifecyclePluginState, ::LifecyclePlugin, cycle_idx::Int, ncycles::Int, o) = (
        put!(s.counter_ch, :cycle_start); nothing
    )

    opts = Options(;
        binary_operators=[+, *],
        populations=2,
        verbosity=0,
        progress=false,
        batching=true,
        batch_size=7,
        plugins=(LifecyclePlugin(counter_ch),),
    )
    X = rand(Float32, 2, 30)
    y = 2.0f0 .* X[1, :] .+ X[2, :]

    equation_search(X, y; options=opts, niterations=3, parallelism=:serial)

    close(counter_ch)
    counts = Dict{Symbol,Int}()
    observed_batch_sizes = Int[]
    for event in counter_ch
        if event isa Symbol
            counts[event] = get(counts, event, 0) + 1
        else
            push!(observed_batch_sizes, event[2])
        end
    end

    @test get(counts, :start, 0) == 1
    @test get(counts, :end, 0) == 1
    @test get(counts, :gen, 0) > 0
    @test get(counts, :cycle_start, 0) > 0
    @test get(counts, :cycle_end, 0) == get(counts, :cycle_start, 0)
    @test !isempty(observed_batch_sizes)
    @test all(==(opts.batch_size), observed_batch_sizes)
end

@testitem "Plugin interface: multiple plugins all fire" begin
    using SymbolicRegression
    import SymbolicRegression: AbstractPlugin
    using Test

    a_calls = Ref(0)
    b_calls = Ref(0)

    struct PluginA <: AbstractPlugin
        calls::Base.RefValue{Int}
    end
    struct PluginB <: AbstractPlugin
        calls::Base.RefValue{Int}
    end
    mutable struct PluginAState
        calls::Base.RefValue{Int}
    end
    mutable struct PluginBState
        calls::Base.RefValue{Int}
    end

    SymbolicRegression.init_plugin_state(p::PluginA, o, d) = PluginAState(p.calls)
    SymbolicRegression.init_plugin_state(p::PluginB, o, d) = PluginBState(p.calls)
    SymbolicRegression.on_generation_end!(s::PluginAState, ::PluginA, ss, d, o, r, rp) = (
        s.calls[] += 1; nothing
    )
    SymbolicRegression.on_generation_end!(s::PluginBState, ::PluginB, ss, d, o, r, rp) = (
        s.calls[] += 1; nothing
    )

    opts = Options(;
        binary_operators=[+, *],
        populations=2,
        verbosity=0,
        progress=false,
        plugins=(PluginA(a_calls), PluginB(b_calls)),
    )
    X = rand(Float32, 2, 30)
    y = 2.0f0 .* X[1, :] .+ X[2, :]
    equation_search(X, y; options=opts, niterations=2, parallelism=:serial)

    @test a_calls[] > 0
    @test b_calls[] > 0
end

@testitem "Plugin interface: init_member hook" begin
    using SymbolicRegression
    import SymbolicRegression: AbstractPlugin, init_member
    using SymbolicRegression.EvolutionModule.MutationFunctionsModule: gen_random_tree
    using Test

    init_count = Ref(0)

    struct InitMemberPlugin <: AbstractPlugin
        calls::Base.RefValue{Int}
    end
    mutable struct InitMemberPluginState
        calls::Base.RefValue{Int}
    end

    SymbolicRegression.init_plugin_state(p::InitMemberPlugin, o, d) =
        InitMemberPluginState(p.calls)
    # Return nothing to fall through to gen_random_tree, but count calls
    SymbolicRegression.init_member(s::InitMemberPluginState, ::InitMemberPlugin, dataset, options) = (
        s.calls[] += 1; nothing
    )

    opts = Options(;
        binary_operators=[+, *],
        populations=2,
        verbosity=0,
        progress=false,
        plugins=(InitMemberPlugin(init_count),),
    )
    X = rand(Float32, 2, 30)
    y = X[1, :] .+ X[2, :]

    equation_search(X, y; options=opts, niterations=2, parallelism=:serial)

    @test init_count[] == opts.population_size * opts.populations
end

@testitem "Plugin interface: init_member that returns a tree is consumed" begin
    using SymbolicRegression
    import SymbolicRegression: AbstractPlugin
    using SymbolicRegression.EvolutionModule.MutationFunctionsModule: gen_random_tree
    using Test

    seeded_calls = Ref(0)

    struct SeedingPlugin <: AbstractPlugin
        calls::Base.RefValue{Int}
    end
    mutable struct SeedingPluginState
        calls::Base.RefValue{Int}
    end
    SymbolicRegression.init_plugin_state(p::SeedingPlugin, o, d) =
        SeedingPluginState(p.calls)
    function SymbolicRegression.init_member(
        s::SeedingPluginState, ::SeedingPlugin, dataset, options
    )
        s.calls[] += 1
        nlength = 3
        nfeatures = size(dataset.X, 1)
        T = eltype(dataset.X)
        return gen_random_tree(nlength, options, nfeatures, T)
    end

    opts = Options(;
        binary_operators=[+, *],
        populations=2,
        verbosity=0,
        progress=false,
        plugins=(SeedingPlugin(seeded_calls),),
    )
    X = rand(Float32, 2, 30)
    y = X[1, :] .+ X[2, :]

    hof = equation_search(X, y; options=opts, niterations=2, parallelism=:serial)
    @test seeded_calls[] == opts.population_size * opts.populations
    @test hof isa SymbolicRegression.HallOfFame
end

@testitem "Plugin interface: two init_member providers is an error" begin
    using SymbolicRegression
    import SymbolicRegression: AbstractPlugin, resolve_init_member
    using SymbolicRegression.EvolutionModule.MutationFunctionsModule: gen_random_tree
    using Test

    struct SeederA <: AbstractPlugin end
    struct SeederB <: AbstractPlugin end
    for P in (SeederA, SeederB)
        @eval function SymbolicRegression.init_member(_, ::$P, dataset, options)
            return gen_random_tree(3, options, size(dataset.X, 1), eltype(dataset.X))
        end
    end

    opts = Options(; binary_operators=[+, *])
    X = rand(Float32, 2, 30)
    y = X[1, :] .+ X[2, :]
    dataset = SymbolicRegression.Dataset(X, y)

    @test_throws ArgumentError resolve_init_member(
        (nothing, nothing), (SeederA(), SeederB()), dataset, opts
    )
    # A single provider still works:
    @test resolve_init_member((nothing,), (SeederA(),), dataset, opts) !== nothing
end

@testitem "Plugin interface: on_mutation_end! fires with correct args" begin
    using SymbolicRegression
    import SymbolicRegression: AbstractPlugin, MutationEvent, on_mutation_end!
    using Test

    # Collect MutationEvent values via a Channel
    events_ch = Channel{MutationEvent{Float32,Float32}}(10_000)

    struct MutEvalPlugin <: AbstractPlugin
        events_ch::Channel{MutationEvent{Float32,Float32}}
    end
    mutable struct MutEvalPluginState
        events_ch::Channel{MutationEvent{Float32,Float32}}
    end
    SymbolicRegression.init_plugin_state(p::MutEvalPlugin, o, d) =
        MutEvalPluginState(p.events_ch)
    # Share the channel with workers (default fork deepcopies → events lost).
    SymbolicRegression.fork_plugin_state(
        head::MutEvalPluginState, ::MutEvalPlugin, dataset
    ) = head
    function SymbolicRegression.on_mutation_end!(
        state::MutEvalPluginState,
        ::MutEvalPlugin,
        ::SymbolicRegression.AbstractMutation,
        event::MutationEvent,
        dataset,
        opts,
    )
        put!(state.events_ch, event)
        return nothing
    end

    # maxsize=5 ensures add_node frequently hits the constraint limit,
    # producing events without an after_loss reliably.
    opts = Options(;
        binary_operators=[+, *],
        populations=2,
        verbosity=0,
        progress=false,
        maxsize=5,
        plugins=(MutEvalPlugin(events_ch),),
    )
    X = rand(Float32, 2, 30)
    y = X[1, :] .+ X[2, :]

    equation_search(X, y; options=opts, niterations=3, parallelism=:serial)

    close(events_ch)
    events = collect(events_ch)

    # Hook fired at all
    @test length(events) > 0

    for ev in events
        @test ev isa MutationEvent
        @test ev.accepted isa Bool
        @test ev.before_cost isa Float32
        @test ev.after_cost === nothing || ev.after_cost isa Float32
        @test ev.before_loss isa Float32
        @test ev.after_loss === nothing || ev.after_loss isa Float32
        @test isfinite(ev.before_loss)
    end

    # Both accepted and rejected mutations should appear (over many calls)
    @test any(ev.accepted for ev in events)
    @test any(!ev.accepted for ev in events)

    # Some events should have finite after_loss (valid evaluations occurred)
    @test any(ev.after_loss !== nothing && isfinite(ev.after_loss) for ev in events)

    # Some events should have no after_loss (constraint failure or NaN eval)
    @test any(isnothing(ev.after_loss) for ev in events)
end

@testitem "Plugin interface: condition_mutation_weights! plugin-dispatched" begin
    using SymbolicRegression
    using SymbolicRegression: AbstractPlugin
    using Test

    # Plugin that zeroes out `mutate_constant` from its dispatched method.
    # Verifies the engine layers plugin conditioning on top of its own.
    struct ZeroConstPlugin <: AbstractPlugin
        calls::Base.RefValue{Int}
    end
    mutable struct ZeroConstState
        calls::Base.RefValue{Int}
    end
    SymbolicRegression.init_plugin_state(plugin::ZeroConstPlugin, o, d) =
        ZeroConstState(plugin.calls)
    SymbolicRegression.fork_plugin_state(
        state::ZeroConstState, ::ZeroConstPlugin, dataset
    ) = state
    function SymbolicRegression.condition_mutation_weights!(
        weights::AbstractVector,
        state::ZeroConstState,
        ::ZeroConstPlugin,
        member,
        options,
        curmaxsize,
        nfeatures,
    )
        state.calls[] += 1
        for i in eachindex(weights)
            mutation, weight = weights[i]
            mutation isa ConstantMutation && (weights[i] = mutation => zero(weight))
        end
        return nothing
    end

    calls = Ref(0)
    opts = Options(;
        binary_operators=[+, *],
        populations=2,
        verbosity=0,
        progress=false,
        use_frequency=false,
        use_frequency_in_tournament=false,
        plugins=(ZeroConstPlugin(calls),),
    )
    X = rand(Float32, 2, 20)
    y = X[1, :] .+ X[2, :]
    hof = equation_search(X, y; options=opts, niterations=2, parallelism=:serial)
    @test hof isa SymbolicRegression.HallOfFame
    @test calls[] > 0
end
