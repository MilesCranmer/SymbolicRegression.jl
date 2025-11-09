@testitem "loss_scale parameter validation" begin
    using SymbolicRegression

    # Test Options constructor assertion
    @test_throws AssertionError Options(loss_scale=:invalid)

    # Test we can create options with valid values
    options_log = Options(; loss_scale=:log)
    options_linear = Options(; loss_scale=:linear)

    @test options_log.loss_scale == :log
    @test options_linear.loss_scale == :linear
end

@testitem "loss_scale score computation" begin
    using SymbolicRegression.HallOfFameModule:
        compute_direct_score, compute_zero_centered_score

    @test compute_direct_score(0.5, 1.0, 1.0) ≈ 0.5
    @test compute_direct_score(1.2, 1.0, 1.0) ≈ 0.0

    @test compute_zero_centered_score(0.5, 1.0, 1.0) ≈ log(2) atol = 1e-5
    @test compute_zero_centered_score(0.1, 1.0, 1.0) ≈ log(10) atol = 1e-5
    @test compute_zero_centered_score(2.0, 1.0, 1.0) ≈ 0.0
end

@testitem "loss_scale in choose_best" begin
    using SymbolicRegression
    using SymbolicRegression.MLJInterfaceModule: choose_best

    # Test data
    trees = [1, 2, 3, 4]  # Placeholder, not used in function
    losses = [0.5, 0.3, 0.4, 0.2]
    scores = [0.1, 0.8, 0.5, 0.3]
    complexities = [1, 2, 3, 4]

    # With loss_scale=:log (default behavior)
    options_log = Options(; loss_scale=:log)
    best_idx_log = choose_best(;
        trees=trees,
        losses=losses,
        scores=scores,
        complexities=complexities,
        options=options_log,
    )
    @test best_idx_log == 2  # Best score (0.8) among those with loss <= 1.5*min_loss

    # With loss_scale=:linear
    options_linear = Options(; loss_scale=:linear)
    best_idx_linear = choose_best(;
        trees=trees,
        losses=losses,
        scores=scores,
        complexities=complexities,
        options=options_linear,
    )
    @test best_idx_linear == 4  # Simply picks minimum loss (0.2)
end

@testitem "loss_scale in pareto_volume" begin
    using SymbolicRegression.LoggingModule: pareto_volume

    # Test data
    test_losses = [0.5, 0.3, 0.2]
    test_complexities = [1, 3, 5]

    # Both should produce valid volumes
    @test pareto_volume(test_losses, test_complexities, 10, false) > 0  # log mode
    @test pareto_volume(test_losses, test_complexities, 10, true) > 0   # linear mode

    # Test negative losses work with linear mode but not log mode
    neg_losses = [0.1, -0.1, -0.5]
    @test pareto_volume(neg_losses, test_complexities, 10, true) > 0    # works with linear
end

@testitem "loss_scale in MLJ interface" begin
    using SymbolicRegression
    using SymbolicRegression: get_options

    # Test MLJ interface supports loss_scale parameter
    model_log = SRRegressor(; loss_scale=:log)
    model_linear = SRRegressor(; loss_scale=:linear)
    @test get_options(model_log).loss_scale == :log
    @test get_options(model_linear).loss_scale == :linear

    # Test with multitarget regressor too
    model_mt_log = MultitargetSRRegressor(; loss_scale=:log)
    model_mt_linear = MultitargetSRRegressor(; loss_scale=:linear)
    @test get_options(model_mt_log).loss_scale == :log
    @test get_options(model_mt_linear).loss_scale == :linear
end

@testitem "loss_scale error handling" begin
    using SymbolicRegression
    using SymbolicRegression.CoreModule: Dataset
    using SymbolicRegression.HallOfFameModule: format_hall_of_fame
    using SymbolicRegression.PopMemberModule: PopMember
    using DynamicExpressions: Node

    # Create test dataset
    X = [1.0 2.0]
    y = [3.0]
    dataset = Dataset(X, y; variable_names=["x1", "x2"])

    # Create options with different loss scales
    options_log = Options(; loss_scale=:log, binary_operators=[+, -, *], unary_operators=[])
    options_linear = Options(; loss_scale=:linear)

    # Create a simple test case with negative loss
    hof = HallOfFame(options_log, dataset)
    hof.members[1].tree = Expression(
        Node{Float64}(; feature=1); operators=nothing, variable_names=nothing
    )
    hof.members[1].loss = -1.0
    hof.exists[1] = true

    # With :log scale, should throw a DomainError with a helpful message
    err = try
        format_hall_of_fame(hof, options_log)
        nothing
    catch e
        e
    end
    @test err isa DomainError
    @test occursin("must be non-negative", err.msg)
    @test occursin("set the `loss_scale` to linear", err.msg)

    # With :linear scale, should work fine with negative losses
    result = format_hall_of_fame(hof, options_linear)
    @test result.losses[1] == -1.0f0
    @test result.scores[1] >= 0.0
end

@testitem "string_dominating_pareto_curve header display" begin
    using SymbolicRegression
    using SymbolicRegression.HallOfFameModule: HallOfFame, string_dominating_pareto_curve
    using SymbolicRegression.CoreModule: Dataset
    using DynamicExpressions: Node, Expression

    # Create simple test dataset
    X = [1.0 2.0]
    y = [3.0]
    dataset = Dataset(X, y; variable_names=["x1", "x2"])

    # Create options with different loss scales
    options_log = Options(; loss_scale=:log, binary_operators=[+, -], unary_operators=[])
    options_linear = Options(;
        loss_scale=:linear, binary_operators=[+, -], unary_operators=[]
    )

    # Create a minimal Hall of Fame with one element
    hof = HallOfFame(options_log, dataset)
    hof.members[1].tree = Expression(
        Node{Float64}(; feature=1); operators=nothing, variable_names=nothing
    )
    hof.members[1].loss = 0.5
    hof.exists[1] = true

    # Test with log scale (should show Score column)
    output_log = string_dominating_pareto_curve(hof, dataset, options_log)
    @test occursin("Complexity", output_log)
    @test occursin("Loss", output_log)
    @test occursin("Score", output_log)
    @test occursin("Equation", output_log)

    # Test with linear scale (should NOT show Score column)
    output_linear = string_dominating_pareto_curve(hof, dataset, options_linear)
    @test occursin("Complexity", output_linear)
    @test occursin("Loss", output_linear)
    @test !occursin("Score", output_linear)
    @test occursin("Equation", output_linear)
end
