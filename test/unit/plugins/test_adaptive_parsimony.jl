@testitem "AdaptiveParsimonyPlugin: legacy kwargs auto-inject" begin
    using SymbolicRegression
    using Test

    opts_default = Options(; binary_operators=[+, *])
    plugins = collect(opts_default.plugins)
    @test count(p -> p isa AdaptiveParsimonyPlugin, plugins) == 1
    p = plugins[findfirst(p -> p isa AdaptiveParsimonyPlugin, plugins)]
    @test p.tournament == true
    @test p.mutation_acceptance == true

    opts_t = Options(;
        binary_operators=[+, *], use_frequency=false, use_frequency_in_tournament=true
    )
    pt = first(p for p in opts_t.plugins if p isa AdaptiveParsimonyPlugin)
    @test pt.tournament == true
    @test pt.mutation_acceptance == false

    opts_m = Options(;
        binary_operators=[+, *], use_frequency=true, use_frequency_in_tournament=false
    )
    pm = first(p for p in opts_m.plugins if p isa AdaptiveParsimonyPlugin)
    @test pm.tournament == false
    @test pm.mutation_acceptance == true

    opts_off = Options(;
        binary_operators=[+, *], use_frequency=false, use_frequency_in_tournament=false
    )
    @test !any(p -> p isa AdaptiveParsimonyPlugin, opts_off.plugins)

    opts_explicit = Options(;
        binary_operators=[+, *],
        plugins=(AdaptiveParsimonyPlugin(; tournament=false, mutation_acceptance=false),),
        use_frequency=true,
        use_frequency_in_tournament=true,
    )
    plugs = collect(opts_explicit.plugins)
    @test count(p -> p isa AdaptiveParsimonyPlugin, plugs) == 1
    px = plugs[findfirst(p -> p isa AdaptiveParsimonyPlugin, plugs)]
    @test px.tournament == false  # user's instance wins
end

@testitem "Plugin collections: vectors normalize and defaults are overridable" begin
    using SymbolicRegression
    using SymbolicRegression: AbstractPlugin
    using Test

    struct DefaultProbePlugin <: AbstractPlugin
        value::Int
    end

    opts_vector = Options(;
        binary_operators=[+, *],
        use_frequency=false,
        use_frequency_in_tournament=false,
        annealing=false,
        plugins=[DefaultProbePlugin(1)],
    )
    @test first(opts_vector.plugins) === DefaultProbePlugin(1)
    @test count(p -> p isa AdaptiveMutationWeightsPlugin, opts_vector.plugins) == 1

    opts_no_defaults = Options(; binary_operators=[+, *], default_plugins=())
    @test isempty(opts_no_defaults.plugins)

    opts_custom_defaults = Options(;
        binary_operators=[+, *],
        plugins=[DefaultProbePlugin(1)],
        default_plugins=[DefaultProbePlugin(2), AdaptiveParsimonyPlugin()],
    )
    @test opts_custom_defaults isa Options
    @test opts_custom_defaults.plugins isa Tuple
    @test opts_custom_defaults.plugins[1] === DefaultProbePlugin(1)
    @test count(p -> p isa DefaultProbePlugin, opts_custom_defaults.plugins) == 1
    @test count(p -> p isa AdaptiveParsimonyPlugin, opts_custom_defaults.plugins) == 1
end

@testitem "AdaptiveParsimonyPlugin: hook outputs match the legacy formula" begin
    using SymbolicRegression
    using SymbolicRegression:
        tournament_cost_multiplier,
        mutation_acceptance_multiplier,
        MutationAcceptanceContext,
        init_plugin_state,
        fork_plugin_state,
        refresh_worker_plugin_state
    using SymbolicRegression.PluginsModule.AdaptiveParsimonyModule: update_frequencies!
    using SymbolicRegression.InterfacesModule.DatasetModule: Dataset
    using DynamicExpressions: Node
    using Test

    # Public-API setup: configure plugin via Options, build state via init_plugin_state.
    opts = Options(;
        binary_operators=[+, *],
        unary_operators=[cos],
        adaptive_parsimony_scaling=30.0,
        maxsize=20,
        use_frequency=false,
        use_frequency_in_tournament=false,
        plugins=(AdaptiveParsimonyPlugin(),),
    )
    dataset = Dataset(randn(2, 10), randn(10))
    plugin = first(p for p in opts.plugins if p isa AdaptiveParsimonyPlugin)

    head_state = init_plugin_state(plugin, opts, dataset)
    # Inject known frequency history via the public RunningSearchStatistics API.
    for size in (1, 1, 1, 1, 1, 3, 3, 5)
        update_frequencies!(head_state.rss; size=size)
    end

    # fork_plugin_state normalizes + deepcopies for the worker.
    worker_state = fork_plugin_state(head_state, plugin, dataset)
    @test sum(worker_state.rss.normalized_frequencies) ≈ 1.0 atol = 1e-9
    @test worker_state.rss !== head_state.rss  # snapshot is independent of head
    old_frequency = worker_state.rss.normalized_frequencies[2]
    for _ in 1:100
        update_frequencies!(head_state.rss; size=2)
    end
    refreshed_state = refresh_worker_plugin_state(worker_state, head_state, plugin, dataset)
    @test refreshed_state.rss.normalized_frequencies[2] > old_frequency

    # Build members of two complexities (1 vs 5) via the popmember_type from Options.
    PM = opts.popmember_type
    n1 = Node{Float64}(; feature=1)
    n5 = cos(n1) + n1 * n1
    m1 = PM(dataset, n1, opts; deterministic=false)
    m5 = PM(dataset, n5, opts; deterministic=false)

    # Frequent complexity (1) gets a larger multiplier than the rare one (5).
    mult1 = tournament_cost_multiplier(worker_state, plugin, m1, opts)
    mult5 = tournament_cost_multiplier(worker_state, plugin, m5, opts)
    @test mult1 > mult5
    @test mult1 > 1.0

    # mutation_acceptance: small parent (high old_freq), big new (low new_freq) → >1.
    mult_mut = mutation_acceptance_multiplier(
        worker_state, plugin, MutationAcceptanceContext(m1, n5, 0.0, 0.0), opts
    )
    @test mult_mut > 1.0

    # Flag toggles produce identity multipliers when off.
    p_tournament_off = AdaptiveParsimonyPlugin(; tournament=false, mutation_acceptance=true)
    p_mut_off = AdaptiveParsimonyPlugin(; tournament=true, mutation_acceptance=false)
    @test tournament_cost_multiplier(worker_state, p_tournament_off, m1, opts) == 1.0
    @test mutation_acceptance_multiplier(
        worker_state, p_mut_off, MutationAcceptanceContext(m1, n5, 0.0, 0.0), opts
    ) == 1.0

    # Out-of-range complexity (size > maxsize) → frequency = 0 → tournament multiplier
    # = exp(scaling * 0) = 1.0. Hits the "size out of range" branch.
    big_tree = foldl((acc, _) -> acc + n1, 1:30; init=Node{Float64}(; val=1.0))
    m_huge = PM(dataset, big_tree, opts; deterministic=false)
    @test tournament_cost_multiplier(worker_state, plugin, m_huge, opts) == 1.0
end

@testitem "AdaptiveParsimonyPlugin: end-to-end equation_search" begin
    using SymbolicRegression
    using Test

    # Legacy form (auto-injected).
    opts_legacy = Options(;
        binary_operators=[+, *],
        unary_operators=[cos],
        populations=2,
        verbosity=0,
        progress=false,
    )
    X = rand(Float32, 2, 30)
    y = 2.0f0 .* X[1, :] .+ X[2, :]
    hof_legacy = equation_search(
        X, y; options=opts_legacy, niterations=2, parallelism=:serial
    )
    @test hof_legacy isa SymbolicRegression.HallOfFame

    # Explicit plugin form, no legacy flags.
    opts_plugin = Options(;
        binary_operators=[+, *],
        unary_operators=[cos],
        populations=2,
        verbosity=0,
        progress=false,
        use_frequency=false,
        use_frequency_in_tournament=false,
        plugins=(AdaptiveParsimonyPlugin(),),
    )
    hof_plugin = equation_search(
        X, y; options=opts_plugin, niterations=2, parallelism=:serial
    )
    @test hof_plugin isa SymbolicRegression.HallOfFame
end

@testitem "AdaptiveParsimonyPlugin: per-output state shape (single-output)" begin
    using SymbolicRegression
    using SymbolicRegression.PluginsModule.AdaptiveParsimonyModule:
        AdaptiveParsimonyPlugin, AdaptiveParsimonyState, RunningSearchStatistics
    using SymbolicRegression: Dataset, init_plugin_state, fork_plugin_state
    using Test

    opts = Options(; binary_operators=[+, *])
    dataset = Dataset(randn(Float32, 2, 10), randn(Float32, 10))
    plugin = AdaptiveParsimonyPlugin()

    # init_plugin_state must operate per-output: one dataset in, one flat
    # per-output state out — no internal nout-length array.
    s = init_plugin_state(plugin, opts, dataset)
    @test s isa AdaptiveParsimonyState
    @test s.rss isa RunningSearchStatistics

    # fork_plugin_state must produce the same shape (no output_index needed).
    ws = fork_plugin_state(s, plugin, dataset)
    @test ws isa AdaptiveParsimonyState
    @test ws.rss isa RunningSearchStatistics
end
