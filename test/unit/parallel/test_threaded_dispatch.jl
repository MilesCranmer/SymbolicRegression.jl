@testitem "Threaded multiprocessing dispatch" begin
    using Distributed
    using SymbolicRegression
    using Test

    Core.eval(Core.Main, :(using Distributed, SymbolicRegression, Random, Test))
    Core.eval(
        Core.Main,
        quote
            threaded_dispatch_definitions = quote
                using Distributed, SymbolicRegression, Random, Test
                using SymbolicRegression.SearchUtilsModule: SearchUtilsModule as THSUM
                using SymbolicRegression.CoreModule: init_plugin_states, fork_plugin_state
                using SymbolicRegression.AdaptiveParsimonyModule: AdaptiveParsimonyState
                using SymbolicRegression.AdaptiveMutationWeightsModule:
                    AdaptiveMutationWeightsState
                using SymbolicRegression.SimulatedAnnealingModule: SimulatedAnnealingState

                struct ThreadedDispatchChannelPlugin <: SymbolicRegression.AbstractPlugin
                    channel::RemoteChannel
                end
                struct ThreadedDispatchChannelState
                    channel::RemoteChannel
                end
                function SymbolicRegression.init_plugin_state(
                    p::ThreadedDispatchChannelPlugin, _, _
                )
                    ThreadedDispatchChannelState(p.channel)
                end
                function SymbolicRegression.on_cycle_end!(
                    s::ThreadedDispatchChannelState,
                    ::ThreadedDispatchChannelPlugin,
                    pop,
                    dataset,
                    hof,
                    options,
                )
                    put!(s.channel, (myid(), minimum(m.loss for m in pop.members)))
                    return nothing
                end
                function threaded_dispatch_fixture(; plugins=nothing)
                    Random.seed!(123)
                    X = randn(Float32, 2, 32)
                    dataset = Dataset(X, vec(X[1, :] .+ X[2, :]))
                    options = if plugins === nothing
                        Options(;
                            binary_operators=[+, *],
                            populations=2,
                            population_size=8,
                            tournament_selection_n=3,
                            topn=3,
                            ncycles_per_iteration=2,
                            maxsize=10,
                            save_to_file=false,
                            deterministic=true,
                            optimizer_probability=0.0,
                            plugins=(AdaptiveMutationWeightsPlugin(),),
                        )
                    else
                        Options(;
                            binary_operators=[+, *],
                            populations=2,
                            population_size=8,
                            tournament_selection_n=3,
                            topn=3,
                            ncycles_per_iteration=2,
                            maxsize=10,
                            save_to_file=false,
                            plugins,
                            default_plugins=(),
                        )
                    end
                    states = init_plugin_states(options, dataset)
                    worker_states = map(
                        (p, s) -> fork_plugin_state(s, p, dataset),
                        options.plugins,
                        states,
                    )
                    pop = Population(
                        dataset;
                        options,
                        population_size=8,
                        nfeatures=2,
                        plugin_states=states,
                    )
                    hall = HallOfFame(options, dataset)
                    R = THSUM.DefaultWorkerOutputType{
                        typeof(pop),typeof(hall),Nothing,typeof(worker_states)
                    }
                    return dataset, options, pop, worker_states, R
                end

                function threaded_dispatch_cycle()
                    SymbolicRegression.UtilsModule.pseudo_time[] = 0
                    dataset, options, pop, states, _ = threaded_dispatch_fixture()
                    return SymbolicRegression._dispatch_s_r_cycle(
                        pop,
                        dataset,
                        options;
                        pop=1,
                        out=1,
                        iteration=1,
                        verbosity=0,
                        cur_maxsize=10,
                        plugin_states=states,
                    )
                end
                function threaded_dispatch_aliases()
                    dataset, options, pop, states, _ = threaded_dispatch_fixture()
                    pop.members[2] = pop.members[1]
                    hall = HallOfFame(options, dataset)
                    hall.members[1] = pop.members[1]
                    hall.exists[1] = true
                    return (pop, hall, nothing, 0.0, states)
                end
                function threaded_dispatch_compare_member(a, b, options)
                    @test a.tree == b.tree
                    @test string_tree(a.tree, options) == string_tree(b.tree, options)
                    @test isequal(a.cost, b.cost)
                    @test isequal(a.loss, b.loss)
                    @test a.birth == b.birth
                    @test a.ref == b.ref
                    @test a.parent == b.parent
                    @test compute_complexity(a, options) == compute_complexity(b, options)
                end
                function threaded_dispatch_compare_state(a, b)
                    @test a === b === nothing
                end
                function threaded_dispatch_compare_state(
                    a::AdaptiveParsimonyState, b::AdaptiveParsimonyState
                )
                    @test a.rss.window_size == b.rss.window_size
                    @test a.rss.frequencies == b.rss.frequencies
                    @test a.rss.normalized_frequencies == b.rss.normalized_frequencies
                end
                function threaded_dispatch_compare_state(
                    a::AdaptiveMutationWeightsState, b::AdaptiveMutationWeightsState
                )
                    @test a.attempts == b.attempts
                    @test a.successes == b.successes
                    @test a.multipliers == b.multipliers
                    @test a.active == b.active
                end
                function threaded_dispatch_compare_state(
                    a::SimulatedAnnealingState, b::SimulatedAnnealingState
                )
                    @test a.temperature == b.temperature
                end
            end
            Core.eval(Core.Main, threaded_dispatch_definitions)

            function threaded_dispatch_run_tests()
                dataset, options, pop, states, R = threaded_dispatch_fixture()

                pids = addprocs(
                    2; exeflags=`--project=$(dirname(Base.active_project())) -t 1`
                )
                try
                    defs = threaded_dispatch_definitions
                    for pid in pids
                        remotecall_fetch(
                            Core.eval,
                            pid,
                            Core.Main,
                            :(using Distributed, SymbolicRegression, Random, Test),
                        )
                        remotecall_fetch(Core.eval, pid, Core.Main, defs)
                    end
                    native = fetch(@spawnat first(pids) threaded_dispatch_cycle())
                    decoded = fetch(
                        THSUM.spawn_encoded_result(threaded_dispatch_cycle, first(pids), R)
                    )
                    @test native[1].n == decoded[1].n
                    @test native[2].exists == decoded[2].exists
                    for (a, b) in zip(native[1].members, decoded[1].members)
                        threaded_dispatch_compare_member(a, b, options)
                    end
                    for (a, b) in zip(native[2].members, decoded[2].members)
                        threaded_dispatch_compare_member(a, b, options)
                    end
                    @test native[3] === decoded[3] === nothing
                    @test native[4] == decoded[4]
                    foreach(threaded_dispatch_compare_state, native[5], decoded[5])

                    aliased = fetch(
                        THSUM.spawn_encoded_result(
                            threaded_dispatch_aliases, first(pids), R
                        ),
                    )
                    @test aliased[1].members[1] === aliased[1].members[2]
                    @test aliased[1].members[1] === aliased[2].members[1]
                    aliased[1].members[1].loss = 123.0f0
                    @test aliased[2].members[1].loss == 123.0f0

                    channel = RemoteChannel(() -> Channel{Tuple{Int,Float32}}(256))
                    _, channel_options, _, _, _ = threaded_dispatch_fixture(;
                        plugins=(ThreadedDispatchChannelPlugin(channel),)
                    )
                    hof = equation_search(
                        dataset.X,
                        dataset.y;
                        options=channel_options,
                        procs=pids,
                        parallelism=:multiprocessing,
                        niterations=3,
                        verbosity=0,
                        progress=false,
                        runtests=false,
                    )
                    messages = Tuple{Int,Float32}[]
                    while isready(channel)
                        push!(messages, take!(channel))
                    end
                    @test Set(first.(messages)) == Set(pids)
                    @test all(isfinite(last(message)) for message in messages)
                    @test !isempty(calculate_pareto_frontier(hof))
                finally
                    rmprocs(filter(in(workers()), pids))
                end
            end
            threaded_dispatch_run_tests()
        end,
    )
end

@testitem "Threaded dispatch search failures and one head thread" begin
    using SymbolicRegression, Distributed, Test

    Core.eval(Core.Main, :(using Distributed, SymbolicRegression, Random, Test))
    Core.eval(
        Core.Main,
        quote
            using SymbolicRegression, Distributed, Test, Random
            using SymbolicRegression.SearchUtilsModule: SearchUtilsModule as THSUM
            using Logging
            threaded_dispatch_failure_definitions = :(
                module ThreadedDispatchFailures
                using Distributed, SymbolicRegression
                const counter = Ref(0)
                const action = Ref(:none)
                const target = Ref(0)
                function loss(ex, dataset, options)
                    if myid() != 1
                        counter[] += 1
                        if counter[] > 500
                            action[] == :error &&
                                error("threaded-dispatch-worker-error-after-main-loop")
                            action[] == :exit && myid() == target[] && exit()
                        end
                    end
                    prediction, complete = eval_tree_array(ex, dataset.X, options)
                    return if complete
                        sum(abs2, prediction .- dataset.y) / dataset.n
                    else
                        Inf32
                    end
                end
                end
            )
            Core.eval(Core.Main, threaded_dispatch_failure_definitions)
            threaded_dispatch_logger_type = quote
                using SymbolicRegression
                mutable struct ThreadedDispatchLogger <:
                               SymbolicRegression.LoggingModule.AbstractSRLogger
                    target::Int
                    state::Any
                    records::Vector{Tuple{Bool,Tuple{Int,Int},Any,Int,Float64}}
                end
            end
            Core.eval(Core.Main, threaded_dispatch_logger_type)
            function SymbolicRegression.LoggingModule.get_logger(::ThreadedDispatchLogger)
                Logging.NullLogger()
            end
            function SymbolicRegression.SearchUtilsModule.logging_callback!(
                logger::ThreadedDispatchLogger; state, datasets, ropt, options
            )
                logger.state = state
                dead = logger.target ∉ workers()
                for (key, worker) in state.worker_assignment
                    output = state.worker_output[key[1]][key[2]]
                    num_evals = state.num_evals[key[1]][key[2]]
                    push!(logger.records, (dead, key, output, worker, num_evals))
                end
                return nothing
            end

            function threaded_dispatch_failure_search(action)
                pids = addprocs(
                    2; exeflags=`--project=$(dirname(Base.active_project())) -t 1`
                )
                try
                    for pid in pids
                        remotecall_fetch(
                            Core.eval, pid, Core.Main, threaded_dispatch_failure_definitions
                        )
                        remotecall_fetch(
                            Core.eval, pid, Core.Main, threaded_dispatch_logger_type
                        )
                        remotecall_fetch(
                            Core.eval,
                            pid,
                            Core.Main,
                            quote
                                ThreadedDispatchFailures.counter[] = 0
                                ThreadedDispatchFailures.action[] = $(QuoteNode(action))
                                ThreadedDispatchFailures.target[] = $(first(pids))
                            end,
                        )
                    end
                    X = randn(MersenneTwister(0), Float32, 2, 32)
                    y = vec(X[1, :] .+ X[2, :])
                    options = Options(;
                        binary_operators=[+, *],
                        populations=2,
                        population_size=8,
                        tournament_selection_n=3,
                        topn=3,
                        ncycles_per_iteration=2,
                        maxsize=10,
                        save_to_file=false,
                        optimizer_probability=0.0,
                        loss_function_expression=ThreadedDispatchFailures.loss,
                        timeout_in_seconds=90.0,
                    )
                    hof = equation_search(
                        X,
                        y;
                        options,
                        procs=pids,
                        parallelism=:multiprocessing,
                        niterations=1,
                        verbosity=0,
                        progress=false,
                        runtests=false,
                    )
                    @test !isempty(calculate_pareto_frontier(hof))
                    warmup_counts = [
                        remotecall_fetch(
                            Core.eval, pid, Core.Main, :(ThreadedDispatchFailures.counter[])
                        ) for pid in pids
                    ]
                    @test all(0 .< warmup_counts .< 250)
                    for pid in pids
                        remotecall_fetch(
                            Core.eval,
                            pid,
                            Core.Main,
                            :(ThreadedDispatchFailures.counter[] = 0),
                        )
                    end
                    if action == :error
                        err = try
                            equation_search(
                                X,
                                y;
                                options,
                                procs=pids,
                                parallelism=:multiprocessing,
                                niterations=1000,
                                verbosity=0,
                                progress=false,
                                runtests=false,
                            )
                            nothing
                        catch ex
                            ex
                        end
                        @test err !== nothing
                        @test occursin(
                            "threaded-dispatch-worker-error-after-main-loop",
                            sprint(showerror, err),
                        )
                    else
                        logger = ThreadedDispatchLogger(
                            first(pids),
                            nothing,
                            Tuple{Bool,Tuple{Int,Int},Any,Int,Float64}[],
                        )
                        started = time()
                        stop_observer = Ref(false)
                        observer = @async begin
                            while !stop_observer[]
                                if logger.state !== nothing &&
                                    logger.target ∉ workers() &&
                                    !any(first, logger.records)
                                    SymbolicRegression.SearchUtilsModule.logging_callback!(
                                        logger;
                                        state=logger.state,
                                        datasets=nothing,
                                        ropt=nothing,
                                        options,
                                    )
                                end
                                sleep(0.01)
                            end
                        end
                        hof = try
                            equation_search(
                                X,
                                y;
                                options,
                                procs=pids,
                                parallelism=:multiprocessing,
                                niterations=100,
                                verbosity=0,
                                progress=false,
                                runtests=false,
                                logger,
                            )
                        finally
                            stop_observer[] = true
                            wait(observer)
                        end
                        @test first(pids) ∉ workers()
                        @test last(pids) ∈ workers()
                        @test time() - started < 110.0
                        @test !isempty(calculate_pareto_frontier(hof))
                        first_dead = findfirst(first, logger.records)
                        @assert first_dead !== nothing "head logger did not observe worker death"
                        after_death = logger.records[first_dead:end]
                        dead_keys = Set(r[2] for r in after_death if r[4] == first(pids))
                        @assert !isempty(dead_keys) "no population was assigned to the dead worker"
                        for key in dead_keys
                            output = first(r[3] for r in after_death if r[2] == key)
                            num_evals = first(r[5] for r in after_death if r[2] == key)
                            @assert all(
                                r[3] === output for r in after_death if r[2] == key
                            ) "dead population was dispatched again"
                            @assert (logger.state.worker_output[key[1]][key[2]] === output) "dead population was dispatched before teardown"
                            @assert all(
                                r[5] == num_evals for r in after_death if r[2] == key
                            ) "dead population completed another cycle"
                            @assert (logger.state.num_evals[key[1]][key[2]] == num_evals) "dead population completed a cycle before teardown"
                            @test istaskfailed(output)
                            @test first(current_exceptions(output)).exception isa
                                Distributed.ProcessExitedException
                        end
                    end
                finally
                    rmprocs(filter(in(workers()), pids))
                end
            end
            threaded_dispatch_failure_search(:error)
            threaded_dispatch_failure_search(:exit)

            pids = addprocs(1; exeflags=`--project=$(dirname(Base.active_project())) -t 1`)
            try
                remotecall_fetch(
                    Core.eval, only(pids), Core.Main, :(using SymbolicRegression)
                )
                t = THSUM.spawn_encoded_result(() -> exit(), only(pids), Nothing)
                @test_throws TaskFailedException fetch(t)
                @test istaskfailed(t)
                exceptions = current_exceptions(t)
                @test first(exceptions).exception isa Distributed.ProcessExitedException
                @test THSUM._isready(t)
            finally
                rmprocs(filter(in(workers()), pids))
            end
        end,
    )

    script = raw"""
        using SymbolicRegression, Distributed, Random
        X = randn(MersenneTwister(0), Float32, 2, 32)
        dataset = Dataset(X, vec(X[1, :] .+ X[2, :]))
        options = Options(; binary_operators=[+, *], populations=2, population_size=8,
                          tournament_selection_n=3, topn=3,
                          ncycles_per_iteration=2, maxsize=10, save_to_file=false)
        @assert Threads.nthreads() == 1
        hof = equation_search(dataset.X, dataset.y; options, niterations=3, numprocs=2,
                              parallelism=:multiprocessing, verbosity=0, progress=false)
        front = calculate_pareto_frontier(hof)
        @assert !isempty(front)
        println("THREADED_DISPATCH_ONE_THREAD_PASS front=", repr(front))
        """
    command = `$(Base.julia_cmd()) --startup-file=no
        --project=$(dirname(Base.active_project())) -t 1 -e $script`
    output = read(command, String)
    @test occursin("THREADED_DISPATCH_ONE_THREAD_PASS front=", output)
end
