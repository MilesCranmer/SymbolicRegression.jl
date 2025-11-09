@testitem "Expression constant optimization with Mooncake" begin
    using SymbolicRegression
    using SymbolicRegression.ConstantOptimizationModule: optimize_constants
    using DynamicExpressions: get_scalar_constants
    using StableRNGs: StableRNG
    using Mooncake
    using DifferentiationInterface: AutoMooncake

    backend = AutoMooncake(; config=nothing)
    default_args = (;
        binary_operators=(+, -, *),
        unary_operators=(sin,),
        autodiff_backend=backend,
        should_optimize_constants=true,
        optimizer_nrestarts=3,
        optimizer_probability=1.0,
        optimizer_iterations=1000,
    )

    @testset "Expression" begin
        options = Options(; default_args...)

        # Create expression with constants to optimize
        x1 = Expression(Node(Float64; feature=1); options.operators)
        x2 = Expression(Node(Float64; feature=2); options.operators)
        # Start with slightly wrong constants
        tree = 2.0 * x1 + sin(2.5 * x2 + 0.9) - 1.4

        rng = StableRNG(0)

        # Generate test data
        X = rand(rng, 2, 32) .* 10
        y = @. 2.1 * X[1, :] + sin(2.6 * X[2, :] + 0.8) - 1.5
        dataset = Dataset(X, y)

        member = PopMember(dataset, tree, options; deterministic=false)
        initial_loss = member.loss

        # Run constant optimization
        optimized_member, num_evals = optimize_constants(
            dataset, copy(member), options; rng=rng
        )

        @test optimized_member.loss < 1e-10
        @test num_evals > 0

        constants, _ = get_scalar_constants(optimized_member.tree)
        @test length(constants) == 4
        @test all(isfinite, constants)
    end

    @testset "TemplateExpression" begin
        spec = @template_spec(expressions = (f, g)) do x, y, z
            f(x, y) + 2.0 * g(3.0 * z)
        end
        options = Options(; default_args..., expression_spec=spec)

        arg1 = ComposableExpression(Node{Float64}(; feature=1); options.operators)

        true_f = 2.0 * arg1 - 1.5
        true_g = 0.9 * sin(arg1 * 0.2)

        init_f = 1.9 * arg1 - 1.4
        init_g = 0.8 * sin(arg1 * 0.25)

        true_tree = TemplateExpression(
            (; f=true_f, g=true_g); spec.structure, options.operators
        )
        init_tree = TemplateExpression(
            (; f=init_f, g=init_g); spec.structure, options.operators
        )

        rng = StableRNG(1)
        dataset = let
            X = rand(rng, 3, 32) .* 10
            y = true_tree(X)
            Dataset(X, y)
        end

        @test length(get_scalar_constants(true_tree)[1]) == 4

        member = PopMember(dataset, init_tree, options; deterministic=false)
        optimized_member, num_evals = optimize_constants(
            dataset, copy(member), options; rng=rng
        )

        @test optimized_member.loss < 1e-10
        @test num_evals > 0

        constants, _ = get_scalar_constants(optimized_member.tree)
        @test length(constants) == 4
        @test all(isfinite, constants)
    end

    @testset "TemplateExpression with parameters" begin
        spec = @template_spec(expressions = (f, g), parameters = (p=1,),) do x, y, z, w
            f(x, y) + g(3.0 * z) + p[1] * w
        end
        options = Options(; default_args..., expression_spec=spec)

        arg1 = ComposableExpression(Node{Float64}(; feature=1); options.operators)

        true_f = 2.0 * arg1 - 1.5
        true_g = 0.9 * sin(arg1 * 0.2)

        init_f = 1.9 * arg1 - 1.4
        init_g = 0.8 * sin(arg1 * 0.25)

        true_tree = TemplateExpression(
            (; f=true_f, g=true_g);
            spec.structure,
            options.operators,
            parameters=(; p=[0.9]),
        )
        init_tree = TemplateExpression(
            (; f=init_f, g=init_g);
            spec.structure,
            options.operators,
            parameters=(; p=[0.5]),
        )

        rng = StableRNG(0)
        dataset = let
            X = rand(rng, 4, 32) .* 10
            y = true_tree(X)
            Dataset(X, y)
        end

        @test length(get_scalar_constants(true_tree)[1]) == 5

        member = PopMember(dataset, init_tree, options; deterministic=false)
        optimized_member, num_evals = optimize_constants(
            dataset, copy(member), options; rng=rng
        )

        @test optimized_member.loss < 1e-10
        @test num_evals > 0

        @test get_metadata(optimized_member.tree).parameters.p ≈ [0.9]
    end
end
