@testitem "@filtered_async error forwarding tests" begin
    using Distributed: Distributed
    using SymbolicRegression.SearchUtilsModule: SearchUtilsModule as SUM
    using Test: Test
    using Suppressor: Suppressor
    @gensym addprocs rmprocs procs t result future channel

    # n.b., we have to run in main as workers get initialized there,
    # and complain about not being able to access their own closures.
    expr = quote
        # Add a worker
        $procs = $Distributed.addprocs(1)
        try
            $Distributed.@everywhere $procs Core.eval(
                Core.Main, :(using Distributed: Distributed, @spawnat)
            )

            # Import Suppressor in Main for @suppress_err
            $t = $SUM.@filtered_async 42
            $result = fetch($t)
            $Test.@test $result == 42

            $future = $Distributed.@spawnat $procs[1] 43
            $result = fetch($future)
            $Test.@test $result == 43

            # With no error
            $future = $SUM.@sr_spawner(
                44, parallelism = :multiprocessing, worker_idx = $procs[1]
            )
            $channel = Channel(1)
            $t = $SUM.@filtered_async put!($channel, fetch($future))
            $Test.@test_nowarn fetch($t)
            $Test.@test take!($channel) == 44

            # With an error - suppress stderr but verify error forwarding works
            $Suppressor.@suppress_err begin
                $future = $SUM.@sr_spawner(
                    throw(ArgumentError("test multiprocessing error")),
                    parallelism = :multiprocessing,
                    worker_idx = $procs[1]
                )
                $t = $SUM.@filtered_async fetch($future)
                $Test.@test_throws TaskFailedException fetch($t)
            end

            # Test ProcessExitedException filtering (should be filtered out by @filtered_async)
            $t = $SUM.@filtered_async throw($Distributed.ProcessExitedException($procs[1]))
            $Test.@test_nowarn fetch($t)

        finally
            $Distributed.rmprocs($procs)
        end
    end
    Core.eval(Core.Main, expr)
end
