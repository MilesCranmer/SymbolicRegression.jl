using SymbolicRegression
using Random
using SymbolicRegression: eval_loss, score_func, Dataset
using ForwardDiff
using Test
include("test_params.jl")

x1 = 2.0

# Initialize functions in Base....
for unaop in [cos, exp, safe_log, safe_log2, safe_log10, safe_sqrt, relu, gamma, safe_acosh]
    for binop in [sub]
        function make_options(; kw...)
            return Options(;
                default_params...,
                binary_operators=(+, *, ^, /, binop),
                unary_operators=(unaop, abs),
                npopulations=4,
                verbosity=(unaop == gamma) ? 0 : Int(1e9),
                kw...,
            )
        end
        options = make_options()
        @extend_operators options

        # for unaop in 
        f_true = (x,) -> binop(abs(3.0 * unaop(x))^2.0, -1.2)

        # binop at outside:
        const_tree = Node(
            5,
            safe_pow(Node(2, Node(; val=3.0) * Node(1, Node("x1"))), 2.0),
            Node(; val=-1.2),
        )
        const_tree_bad = Node(
            5,
            safe_pow(Node(2, Node(; val=3.0) * Node(1, Node("x1"))), 2.1),
            Node(; val=-1.3),
        )
        n = count_nodes(const_tree)

        true_result = f_true(x1)

        result = eval(Meta.parse(string_tree(const_tree, make_options().operators)))

        # Test Basics
        @test n == 9
        @test result == true_result

        types_to_test = [Float32, Float64, BigFloat]
        if unaop == cos
            # Other unary operators produce numbers too large
            # to do meaningful tests
            types_to_test = [Float16, types_to_test...]
        end
        for T in types_to_test
            if T == Float16 || unaop == gamma
                zero_tolerance = 3e-2
            else
                zero_tolerance = 1e-6
            end

            tree = convert(Node{T}, const_tree)
            tree_bad = convert(Node{T}, const_tree_bad)

            Random.seed!(0)
            N = 100
            if unaop in [safe_log, safe_log2, safe_log10, safe_acosh, safe_sqrt]
                X = T.(rand(MersenneTwister(0), 5, N) / 3)
            else
                X = T.(randn(MersenneTwister(0), 5, N) / 3)
            end
            X = X + sign.(X) * T(0.1)
            if unaop == safe_acosh
                X = X .+ T(1.0)
            end

            y = T.(f_true.(X[1, :]))
            dataset = Dataset(X, y)
            test_y, complete = eval_tree_array(tree, X, make_options())
            test_y2, complete2 = differentiable_eval_tree_array(tree, X, make_options())

            # Test Evaluation
            @test complete == true
            @test all(abs.(test_y .- y) / N .< zero_tolerance)
            @test complete2 == true
            @test all(abs.(test_y2 .- y) / N .< zero_tolerance)

            # Test loss:
            @test abs(eval_loss(tree, dataset, make_options())) < zero_tolerance
            @test eval_loss(tree, dataset, make_options()) ==
                score_func(dataset, tree, make_options())[2]

            #Test Scoring
            @test abs(score_func(dataset, tree, make_options(; parsimony=0.0))[1]) <
                zero_tolerance
            @test score_func(dataset, tree, make_options(; parsimony=1.0))[1] > 1.0
            @test score_func(dataset, tree, make_options())[1] <
                score_func(dataset, tree_bad, make_options())[1]

            dataset_with_larger_baseline = deepcopy(dataset)
            dataset_with_larger_baseline.baseline_loss = one(T) * 10
            @test score_func(dataset_with_larger_baseline, tree_bad, make_options())[1] <
                score_func(dataset, tree_bad, make_options())[1]

            # Test gradients:
            df_true = x -> ForwardDiff.derivative(f_true, x)
            dy = T.(df_true.(X[1, :]))
            test_dy = ForwardDiff.gradient(
                _x -> sum(differentiable_eval_tree_array(tree, _x, make_options())[1]), X
            )
            test_dy = test_dy[1, 1:end]
            @test all(abs.(test_dy .- dy) / N .< zero_tolerance)
        end
    end
end
