@testitem "Test logging" tags = [:part1, :integration] begin
    using SymbolicRegression, TensorBoardLogger, Logging, MLJBase, Plots

    include("test_params.jl")

    mktempdir() do dir
        logger = SRLogger(;
            logger=TBLogger(dir, tb_overwrite; min_level=Logging.Info),
            log_interval_scalars=2,
            log_interval_plots=10,
        )

        niterations = 4
        populations = 36
        model = SRRegressor(;
            binary_operators=[+, -, *, mod],
            unary_operators=[],
            maxsize=40,
            niterations,
            populations,
            logger,
        )

        X = (a=rand(500), b=rand(500))
        y = @. 2 * cos(X.a * 23.5) - X.b^2
        mach = machine(model, X, y)

        fit!(mach)

        b = TensorBoardLogger.steps(logger.logger)
        @test length(b) == (niterations * populations//2) + 1

        files_and_dirs = readdir(dir)
        @test length(files_and_dirs) == 1
        @test occursin(r"events\.out\.tfevents", only(files_and_dirs))
    end
end
