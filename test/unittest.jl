include("test_params.jl")
using SymbolicRegression, SymbolicUtils, Test, Random, ForwardDiff
using SymbolicRegression:
    Options, string_tree, eval_tree_array, Dataset, differentiable_eval_tree_array
using SymbolicRegression: print_tree, pow, eval_loss, score_func, Node
using SymbolicRegression:
    plus,
    sub,
    mult,
    square,
    cube,
    div,
    log_abs,
    log2_abs,
    log10_abs,
    sqrt_abs,
    acosh_abs,
    neg,
    greater,
    greater,
    relu,
    logical_or,
    logical_and,
    gamma
using SymbolicRegression: node_to_symbolic, symbolic_to_node
using SymbolicRegression: check_constraints

x1 = 2.0
# Initialize functions in Base....
for unaop in [cos, exp, log_abs, log2_abs, log10_abs, relu, gamma, acosh_abs]
    for binop in [sub]
        function make_options(; kw...)
            return Options(;
                default_params...,
                binary_operators=(+, *, ^, /, binop),
                unary_operators=(unaop,),
                npopulations=4,
                verbosity=(unaop == gamma) ? 0 : Int(1e9),
                kw...,
            )
        end
        make_options()

        # for unaop in 
        f_true = (x,) -> binop((3.0 * unaop(x))^2.0, -1.2)

        # binop at outside:
        tree = Node(5, (Node(3.0) * Node(1, Node("x1")))^2.0, -1.2)
        tree_bad = Node(5, (Node(3.0) * Node(1, Node("x1")))^2.1, -1.3)
        n = count_nodes(tree)

        true_result = f_true(x1)

        result = eval(Meta.parse(string_tree(tree, make_options())))

        # Test Basics
        @test n == 8
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

            Random.seed!(0)
            N = 100
            X = T.(randn(MersenneTwister(0), Float64, 5, N) / 3)
            X = X + sign.(X) * T(0.1)
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
                score_func(dataset, one(T), tree, make_options())[2]

            #Test Scoring
            @test abs(score_func(dataset, one(T), tree, make_options(; parsimony=0.0))[1]) <
                zero_tolerance
            @test score_func(dataset, one(T), tree, make_options(; parsimony=1.0))[1] > 1.0
            @test score_func(dataset, one(T), tree, make_options())[1] <
                score_func(dataset, one(T), tree_bad, make_options())[1]
            @test score_func(dataset, one(T) * 10, tree_bad, make_options())[1] <
                score_func(dataset, one(T), tree_bad, make_options())[1]

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

# Generic operator tests
types_to_test = [Float16, Float32, Float64, BigFloat]
for T in types_to_test
    val = T(0.5)
    val2 = T(3.2)
    @test sqrt_abs(val) == sqrt_abs(-val)
    @test abs(log_abs(-val) - log(val)) < 1e-6
    @test abs(log2_abs(-val) - log2(val)) < 1e-6
    @test abs(log10_abs(-val) - log10(val)) < 1e-6
    @test neg(-val) == val
    @test sqrt_abs(val) == sqrt(val)
    @test mult(val, val2) == val * val2
    @test plus(val, val2) == val + val2
    @test sub(val, val2) == val - val2
    @test square(val) == val * val
    @test cube(val) == val * val * val
    @test div(val, val2) == val / val2
    @test greater(val, val2) == T(0.0)
    @test greater(val2, val) == T(1.0)
    @test relu(-val) == T(0.0)
    @test relu(val) == val
    @test logical_or(val, val2) == T(1.0)
    @test logical_or(T(0.0), val2) == T(1.0)
    @test logical_and(T(0.0), val2) == T(0.0)
end

# Test SymbolicUtils interface
_inv(x) = 1 / x
options = Options(;
    default_params...,
    binary_operators=(+, *, ^, /, greater),
    unary_operators=(_inv,),
    constraints=(_inv => 4,),
    npopulations=4,
)
tree = Node(5, (Node(3.0) * Node(1, Node("x1")))^2.0, -1.2)

eqn = node_to_symbolic(tree, options; varMap=["energy"], index_functions=true)
tree2 = symbolic_to_node(eqn, options; varMap=["energy"])

@test string_tree(tree, options) == string_tree(tree2, options)

# Test constraint-checking interface
tree = Node(5, (Node(3.0) * Node(1, Node("x1")))^2.0, -1.2)
violating_tree = Node(1, tree)

@test check_constraints(tree, options) == true
@test check_constraints(violating_tree, options) == false

# Test different loss functions
customloss(x, y) = abs(x - y)^2.5
customloss(x, y, w) = w * (abs(x - y)^2.5)
testl1(x, y) = abs(x - y)
testl1(x, y, w) = abs(x - y) * w

for (loss_fnc, evaluator) in [(L1DistLoss(), testl1), (customloss, customloss)]
    local options = Options(;
        default_params...,
        binary_operators=(+, *, -, /),
        unary_operators=(cos, exp),
        npopulations=4,
        loss=loss_fnc,
    )
    x = randn(MersenneTwister(0), Float32, 100)
    y = randn(MersenneTwister(1), Float32, 100)
    w = abs.(randn(MersenneTwister(2), Float32, 100))
    @test abs(
        SymbolicRegression.LossFunctionsModule.loss(x, y, options) -
        sum(evaluator.(x, y)) / length(x),
    ) < 1e-6
    @test abs(
        SymbolicRegression.LossFunctionsModule.loss(x, y, w, options) -
        sum(evaluator.(x, y, w)) / sum(w),
    ) < 1e-6
end

# Test derivatives
include("test_derivatives.jl")

# Test simplification:
include("test_simplification.jl")

# Test `print`:
include("test_print.jl")

include("test_evaluation.jl")

include("test_prob_pick_first.jl")

include("test_crossover.jl")

include("test_nan_detection.jl")

include("test_constraints.jl")

include("test_complexity.jl")
