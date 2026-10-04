@testitem "Multiprocessing results: plugin channels, worker errors, and worker exits" begin
    using Distributed
    using SymbolicRegression
    using Test

    defs = quote
        using Distributed, SymbolicRegression
        struct DispatchChannelPlugin <: SymbolicRegression.AbstractPlugin
            channel::RemoteChannel
        end
        function SymbolicRegression.on_cycle_end!(
            _, p::DispatchChannelPlugin, pop, dataset, hof, options
        )
            put!(p.channel, myid())
            return nothing
        end
        const dispatch_failure = Ref(:none)
        const dispatch_calls = Ref(0)
        function dispatch_failure_loss(ex, dataset, options)
            dispatch_calls[] += 1
            if dispatch_calls[] > 500
                dispatch_failure[] == :error && error("worker-error-in-main-loop")
                dispatch_failure[] == :exit && exit()
            end
            prediction, complete = eval_tree_array(ex, dataset.X, options)
            return complete ? sum(abs2, prediction .- dataset.y) / dataset.n : Inf32
        end
    end
    # Workers are initialized in `Core.Main`, so the definitions live there on every process.
    Core.eval(Core.Main, defs)
    eval(:(using Main: DispatchChannelPlugin, dispatch_failure_loss))

    X = randn(Float32, 2, 32)
    y = vec(X[1, :] .+ X[2, :])
    common = (;
        binary_operators=[+, *],
        populations=2,
        population_size=8,
        tournament_selection_n=3,
        topn=3,
        ncycles_per_iteration=2,
        maxsize=10,
        save_to_file=false,
    )
    function with_workers(f; failure=:none)
        pids = addprocs(2; exeflags=`--project=$(dirname(Base.active_project())) -t 1`)
        try
            foreach(pid -> remotecall_fetch(Core.eval, pid, Core.Main, defs), pids)
            remotecall_fetch(
                Core.eval,
                first(pids),
                Core.Main,
                :(dispatch_failure[] = $(QuoteNode(failure))),
            )
            f(pids)
        finally
            rmprocs(filter(in(workers()), pids))
        end
    end
    search(pids, options; niterations) = equation_search(
        X,
        y;
        options,
        procs=pids,
        parallelism=:multiprocessing,
        niterations,
        verbosity=0,
        progress=false,
        runtests=false,
    )

    # A plugin's RemoteChannel reaches every worker through `options.plugins`. Every
    # consumed result ran `on_cycle_end!` once per cycle; which worker ran each cycle
    # depends on timing.
    with_workers() do pids
        channel = RemoteChannel(() -> Channel{Int}(4096))
        options = Options(; common..., plugins=(DispatchChannelPlugin(channel),))
        niterations = 3
        hof = search(pids, options; niterations)
        senders = Int[]
        while isready(channel)
            push!(senders, take!(channel))
        end
        consumed_cycles = niterations * options.populations * options.ncycles_per_iteration
        @test length(senders) >= consumed_cycles
        @test all(in(pids), senders)
        @test !isempty(calculate_pareto_frontier(hof))
    end

    # An error thrown on a worker during the main loop reaches the caller.
    with_workers(; failure=:error) do pids
        options = Options(; common..., loss_function_expression=dispatch_failure_loss)
        err = try
            search(pids, options; niterations=1000)
            nothing
        catch e
            e
        end
        @test err !== nothing
        @test occursin("worker-error-in-main-loop", sprint(showerror, err))
    end

    # A worker that exits mid-search does not stop the search on the remaining worker.
    with_workers(; failure=:exit) do pids
        options = Options(;
            common...,
            loss_function_expression=dispatch_failure_loss,
            timeout_in_seconds=90.0,
        )
        started = time()
        hof = search(pids, options; niterations=100)
        @test first(pids) ∉ workers()
        @test last(pids) ∈ workers()
        @test time() - started < 110.0
        @test !isempty(calculate_pareto_frontier(hof))
    end
end
