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
        set_dispatch_failure(failure) = (dispatch_failure[]=failure; nothing)
        function dispatch_failure_loss(ex, dataset, options)
            dispatch_failure[] == :error && error("worker-error-in-main-loop")
            dispatch_failure[] == :exit && exit()
            prediction, complete = eval_tree_array(ex, dataset.X, options)
            return complete ? sum(abs2, prediction .- dataset.y) / dataset.n : Inf32
        end
        # Arms the failure on one worker from the head once the main loop has started.
        struct FailWorkerPlugin <: SymbolicRegression.AbstractPlugin
            worker::Int
            failure::Symbol
            armed::Base.RefValue{Bool}
        end
        function SymbolicRegression.on_generation_end!(
            _, p::FailWorkerPlugin, search_state, dataset, options, ropt, returned_pop
        )
            if !p.armed[]
                p.armed[] = true
                remotecall(set_dispatch_failure, p.worker, p.failure)
            end
            return nothing
        end
        # Stops the search once `worker` has exited.
        struct WorkerExited <: Function
            worker::Int
        end
        (stop::WorkerExited)(_, _) = stop.worker ∉ workers()
    end
    # Workers are initialized in `Core.Main`, so the definitions live there on every process.
    Core.eval(Core.Main, defs)
    eval(
        :(using Main:
            DispatchChannelPlugin, FailWorkerPlugin, WorkerExited, dispatch_failure_loss),
    )

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
    function with_workers(f)
        pids = addprocs(2; exeflags=`--project=$(dirname(Base.active_project())) -t 1`)
        try
            foreach(pid -> remotecall_fetch(Core.eval, pid, Core.Main, defs), pids)
            f(pids)
        finally
            rmprocs(filter(in(workers()), pids))
        end
    end
    failure_options(pids, failure; kws...) = Options(;
        common...,
        loss_function_expression=dispatch_failure_loss,
        plugins=(FailWorkerPlugin(first(pids), failure, Ref(false)),),
        kws...,
    )
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

    # The failing worker hosts one population, which only runs again after it returns, and
    # the other population can use up a fixed cycle budget before then. So these searches
    # run until the failure happens.

    # An error thrown on a worker during the main loop reaches the caller.
    with_workers() do pids
        options = failure_options(pids, :error; timeout_in_seconds=90.0)
        err = try
            search(pids, options; niterations=10^9)
            nothing
        catch e
            e
        end
        @test err !== nothing
        @test occursin("worker-error-in-main-loop", sprint(showerror, err))
    end

    # A worker that exits mid-search does not stop the search on the remaining worker.
    with_workers() do pids
        options = failure_options(
            pids,
            :exit;
            early_stop_condition=WorkerExited(first(pids)),
            timeout_in_seconds=90.0,
        )
        started = time()
        hof = search(pids, options; niterations=10^9)
        @test first(pids) ∉ workers()
        @test last(pids) ∈ workers()
        @test time() - started < 110.0
        @test !isempty(calculate_pareto_frontier(hof))
    end
end
