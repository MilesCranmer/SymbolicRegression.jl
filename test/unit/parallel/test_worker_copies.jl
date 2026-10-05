@testitem "Multiprocessing workers evaluate each output on its own search's dataset" begin
    using Distributed
    using Random
    using SymbolicRegression
    using SymbolicRegression: eval_loss
    using SymbolicRegression.SearchUtilsModule: store_on_workers, delete_worker_copy!
    using Test

    procs = addprocs(2)
    try
        @everywhere procs using SymbolicRegression
        value = (Float32[1, 2, 3], :worker_copy)
        Random.seed!(42)
        expected_draw = rand()
        Random.seed!(42)
        worker_copy = store_on_workers(value, procs)
        @test rand() == expected_draw
        for proc in procs
            stored_value = remotecall_fetch(fetch, proc, worker_copy)
            @test stored_value == value
            @test stored_value isa typeof(value)
            remotecall_fetch(delete_worker_copy!, proc, worker_copy.key)
        end
        options = Options(;
            binary_operators=[+, -, *],
            populations=2,
            population_size=8,
            tournament_selection_n=3,
            topn=3,
            ncycles_per_iteration=2,
            maxsize=10,
            save_to_file=false,
        )
        X = randn(MersenneTwister(0), Float32, 2, 64)
        # Losses stored in the hall of fame were computed on the workers. Recomputing them on
        # the head against each output's dataset catches a worker using another output's
        # data, or data left over from an earlier search on the same processes.
        function check_losses(Y)
            halls = equation_search(
                X,
                Y;
                options,
                niterations=2,
                parallelism=:multiprocessing,
                procs,
                progress=false,
                verbosity=0,
            )
            for j in axes(Y, 1)
                dataset = Dataset(X, Y[j, :])
                for member in calculate_pareto_frontier(halls[j])
                    @test member.loss ≈ eval_loss(member.tree, dataset, options) rtol = 1e-5
                end
            end
            for proc in procs
                @test remotecall_fetch(
                    Core.eval,
                    proc,
                    Core.Main,
                    :(isempty(SymbolicRegression.SearchUtilsModule.WORKER_COPIES)),
                )
            end
        end
        check_losses(vcat(X[1:1, :] .+ X[2:2, :], X[1:1, :] .* X[2:2, :]))
        check_losses(vcat(X[1:1, :] .- 2 .* X[2:2, :], X[2:2, :] .* X[2:2, :] .+ 1))
    finally
        rmprocs(procs)
    end
end
