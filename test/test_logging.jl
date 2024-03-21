using Test
using SymbolicRegression
using TensorBoardLogger
using Logging
using MLJBase
using Plots

mktempdir() do dir
    logger = TBLogger(dir, tb_overwrite; min_level=Logging.Info)

    niterations = 4
    populations = 36
    log_every_n = (; scalars=2, plots=10)
    model = SRRegressor(;
        binary_operators=[+, -, *, mod],
        unary_operators=[],
        maxsize=40,
        niterations,
        populations,
        log_every_n,
        logger,
    )

    X = (a=rand(500), b=rand(500))
    y = @. 2 * cos(X.a * 23.5) - X.b^2
    mach = machine(model, X, y)

    fit!(mach)

    b = TensorBoardLogger.steps(logger)
    @test length(b) == (niterations * populations//log_every_n.scalars) + 1

    files_and_dirs = readdir(dir)
    @test length(files_and_dirs) == 1
    @test occursin(r"events\.out\.tfevents", only(files_and_dirs))
end
