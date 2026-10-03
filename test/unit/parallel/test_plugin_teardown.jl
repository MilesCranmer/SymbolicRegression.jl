@testitem "Plugin interface: teardown does not wait for unfinished multiprocessing cycles" begin
    using Distributed
    using DynamicExpressions: AbstractExpression, Node
    using SymbolicRegression
    using SymbolicRegression: AbstractPlugin
    using SymbolicRegression.SearchUtilsModule: AbstractRuntimeOptions, AbstractSearchState
    import SymbolicRegression.SearchUtilsModule: close_reader!
    using Test

    struct TeardownProbeExpression <: AbstractExpression{Float64,Node{Float64}} end
    struct TeardownProbeReader end
    close_reader!(::TeardownProbeReader) = nothing

    struct TeardownProbePlugin <: AbstractPlugin end
    struct TeardownProbeState
        called::Base.RefValue{Bool}
        workers_alive::Base.RefValue{Bool}
        outputs_pending::Base.RefValue{Bool}
    end
    function SymbolicRegression.on_search_end!(
        state::TeardownProbeState,
        ::TeardownProbePlugin,
        search_state,
        dataset,
        options,
        ropt,
    )
        state.called[] = true
        state.workers_alive[] = all(in(workers()), search_state.procs)
        state.outputs_pending[] = any(
            !istaskdone, Iterators.flatten(search_state.worker_output)
        )
        return nothing
    end

    struct TeardownProbeRuntimeOptions <: AbstractRuntimeOptions
        parallelism::Symbol
    end
    struct TeardownProbeSearchState <:
           AbstractSearchState{Float64,Float64,TeardownProbeExpression}
        procs::Vector{Int}
        we_created_procs::Bool
        worker_output::Vector{Vector{Task}}
        plugin_states::Vector{Tuple{TeardownProbeState}}
        stdin_reader::TeardownProbeReader
    end

    called = Ref(false)
    workers_alive = Ref(false)
    outputs_pending = Ref(false)
    plugin_state = TeardownProbeState(called, workers_alive, outputs_pending)
    options = Options(;
        binary_operators=[+, *],
        use_frequency=false,
        use_frequency_in_tournament=false,
        annealing=false,
        save_to_file=false,
        plugins=(TeardownProbePlugin(),),
        default_plugins=(),
    )
    ropt = TeardownProbeRuntimeOptions(:multiprocessing)

    proc = only(addprocs(1))
    try
        output = Threads.@spawn remotecall_fetch(sleep, proc, 60)
        search_state = TeardownProbeSearchState(
            [proc], true, [[output]], [(plugin_state,)], TeardownProbeReader()
        )

        elapsed = @elapsed SymbolicRegression._tear_down!(
            search_state, [nothing], ropt, options
        )

        @test called[]
        @test outputs_pending[]
        @test workers_alive[]
        @test proc ∉ workers()
        @test elapsed < 10
    finally
        proc in workers() && rmprocs(proc)
    end
end
