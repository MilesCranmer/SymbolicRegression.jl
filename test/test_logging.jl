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
    # Points: (0,0), (0,2), (2,0), and (1,1) which is inside the triangle
    points = [
        0.0 0.0   # vertex 1
        0.0 2.0   # vertex 2
        2.0 0.0   # vertex 3
        1.0 1.0   # interior point that should be ignored
    ]
    hull = convex_hull(points)

    @test length(hull) == 3
    @test hull == [[0.0, 0.0], [0.0, 2.0], [2.0, 0.0]]

    # Expected area = 1/2 * base * height = 1/2 * 2 * 2 = 2
    area = convex_hull_area(hull)
    @test isapprox(area, 2.0, atol=1e-10)
end
