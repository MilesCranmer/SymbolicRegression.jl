@testitem "Multiprocessing workers evaluate each output on its own search's dataset" begin
    using Distributed
    using Random
    using SymbolicRegression
    using SymbolicRegression: eval_loss
    using Test

    procs = addprocs(2)
    try
        @everywhere procs using SymbolicRegression
        options = Options(;
            binary_operators=[+, -, *],
            populations=4,
            population_size=20,
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
        end
        check_losses(vcat(X[1:1, :] .+ X[2:2, :], X[1:1, :] .* X[2:2, :]))
        check_losses(vcat(X[1:1, :] .- 2 .* X[2:2, :], X[2:2, :] .* X[2:2, :] .+ 1))
    finally
        rmprocs(procs)
    end
end
