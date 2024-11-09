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
@testitem "Test convex hull calculation" tags = [:part1] begin
    using SymbolicRegression.LoggingModule: convex_hull, convex_hull_area

    # Create a Pareto front with an interior point that should be ignored
    log_complexities = [1.0, 2.0, 3.0, 4.0]
    log_losses = [4.0, 3.0, 3.0, 2.5]

    # Add a point to connect things at lower right corner
    push!(log_complexities, 5.0)
    push!(log_losses, 2.5)

    # Add a point to connect things at upper right corner
    push!(log_losses, 4.0)
    push!(log_complexities, 5.0)

    xy = cat(log_complexities, log_losses; dims=2)
    hull = convex_hull(xy)
    @test length(hull) == 5
    @test hull == [[1.0, 4.0], [5.0, 4.0], [5.0, 2.5], [4.0, 2.5], [2.0, 3.0]]

    # Expected area = 1/2 * base * height = 1/2 * 2 * 2 = 2
    area = convex_hull_area(hull)
    true_area = (
        1 * (4.0 - 2.5)           # lower right rectangle
        + 2.0 * (4.0 - 3.0)       # block to the slight left and update
        + 1.0 * (4.0 - 3.0) / 2  # top left triangle
        + 2.0 * (3.0 - 2.5) / 2  # bottom triangle
    )
    @test isapprox(area, true_area, atol=1e-10)
end
