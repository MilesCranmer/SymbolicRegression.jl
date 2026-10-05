@testitem "@filtered_async error forwarding tests" begin
    using Distributed: Distributed
    using SymbolicRegression.SearchUtilsModule: SearchUtilsModule as SUM
    using Test: Test
    using Suppressor: Suppressor
    @gensym addprocs rmprocs procs t result future channel copy

    # n.b., we have to run in main as workers get initialized there,
    # and complain about not being able to access their own closures.
    expr = quote
        # Add a worker
        $procs = $Distributed.addprocs(1)
        try
            $Distributed.@everywhere $procs Core.eval(
                Core.Main, :(using Distributed: Distributed, @spawnat)
            )
            $Distributed.@everywhere $procs Core.eval(
                Core.Main, :(using SymbolicRegression)
            )

            # Import Suppressor in Main for @suppress_err
            $t = $SUM.@filtered_async 42
            $result = fetch($t)
            $Test.@test $result == 42

            $future = $Distributed.@spawnat $procs[1] 43
            $result = fetch($future)
            $Test.@test $result == 43

            # With no error
            $copy = $SUM.store_on_workers((nothing, nothing), $procs)
            $future = $SUM.@sr_spawner(
                (_, _) -> 44,
                inputs = (nothing, nothing),
                worker_copy = $copy,
                parallelism = :multiprocessing,
                worker_idx = $procs[1],
                result_type = Int
            )
            $channel = Channel(1)
            $t = $SUM.@filtered_async put!($channel, fetch($future))
            $Test.@test_nowarn fetch($t)
            $Test.@test take!($channel) == 44

            # With an error - suppress stderr but verify error forwarding works
            $Suppressor.@suppress_err begin
                $future = $SUM.@sr_spawner(
                    (_, _) -> throw(ArgumentError("test multiprocessing error")),
                    inputs = (nothing, nothing),
                    worker_copy = $copy,
                    parallelism = :multiprocessing,
                    worker_idx = $procs[1],
                    result_type = Int
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
