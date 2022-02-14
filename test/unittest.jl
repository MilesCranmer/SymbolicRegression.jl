using SymbolicRegression, SymbolicUtils, Test, Random, ForwardDiff
using SymbolicRegression: Options, stringTree, evalTreeArray, Dataset, differentiableEvalTreeArray
using SymbolicRegression: printTree, pow, EvalLoss, scoreFunc, Node
using SymbolicRegression: plus, sub, mult, square, cube, div, log_abs, log2_abs, log10_abs, sqrt_abs, acosh_abs, neg, greater, greater, relu, logical_or, logical_and, gamma
using SymbolicRegression: node_to_symbolic, symbolic_to_node
using SymbolicRegression: check_constraints, Loss

x1 = 2.0
# Initialize functions in Base....
for unaop in [cos, exp, log_abs, log2_abs, log10_abs, relu, gamma, acosh_abs]
    for binop in [sub]

        function make_options(;kw...)
            Options(
                binary_operators=(+, *, ^, /, binop),
                unary_operators=(unaop,), npopulations=4;
                kw...
            )
        end
        make_options()

        # for unaop in 
        f_true = (x,) -> binop((3.0 * unaop(x)) ^ 2.0, -1.2)

        # binop at outside:
        tree = Node(5, (Node(3.0) * Node(1, Node("x1"))) ^ 2.0, -1.2)
        tree_bad = Node(5, (Node(3.0) * Node(1, Node("x1"))) ^ 2.1, -1.3)
        n = countNodes(tree)

        true_result = f_true(x1)

        result = eval(Meta.parse(stringTree(tree, make_options())))

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
            X = T.(randn(MersenneTwister(0), Float64, 5, N)/3)
            X = X + sign.(X) * T(0.1)
            y = T.(f_true.(X[1, :]))
            dataset = Dataset(X, y)
            test_y, complete = evalTreeArray(tree, X, make_options())
            test_y2, complete2 = differentiableEvalTreeArray(tree, X, make_options())

            # Test Evaluation
            @test complete == true
            @test all(abs.(test_y .- y)/N .< zero_tolerance)
            @test complete2 == true
            @test all(abs.(test_y2 .- y)/N .< zero_tolerance)

            #Test Scoring
            @test abs(EvalLoss(tree, dataset, make_options())) < zero_tolerance
            @test abs(scoreFunc(dataset, one(T), tree, make_options(parsimony=0.0))) < zero_tolerance
            @test scoreFunc(dataset, one(T), tree, make_options(parsimony=1.0)) > 1.0
            @test scoreFunc(dataset, one(T), tree, make_options()) < scoreFunc(dataset, one(T), tree_bad, make_options())
            @test scoreFunc(dataset, one(T)*10, tree_bad, make_options()) < scoreFunc(dataset, one(T), tree_bad, make_options())

            # Test gradients:
            df_true = x -> ForwardDiff.derivative(f_true, x)
            dy = T.(df_true.(X[1, :]))
            test_dy = (x -> ForwardDiff.gradient(
                 _x -> sum(differentiableEvalTreeArray(tree, _x, make_options())[1]),
                x)
            )(X)[1, :]
            @test all(abs.(test_dy .- dy)/N .< zero_tolerance)
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
_inv(x) = 1/x
options = Options(
    binary_operators=(+, *, ^, /, greater),
    unary_operators=(_inv,),
    constraints=(_inv=>4,),
    npopulations=4
)
tree = Node(5, (Node(3.0) * Node(1, Node("x1"))) ^ 2.0, -1.2)

eqn = node_to_symbolic(tree, options;
                       varMap=["energy"], index_functions=true)
tree2 = symbolic_to_node(eqn, options; varMap=["energy"])

@test stringTree(tree, options) == stringTree(tree2, options)

# Test constraint-checking interface
tree = Node(5, (Node(3.0) * Node(1, Node("x1"))) ^ 2.0, -1.2)
violating_tree = Node(1, tree)

@test check_constraints(tree, options) == true
@test check_constraints(violating_tree, options) == false

# Test different loss functions
customloss(x, y) = abs(x - y) ^ 2.5
customloss(x, y, w) = w * (abs(x - y) ^ 2.5)
testl1(x, y) = abs(x - y)
testl1(x, y, w) = abs(x - y) * w

for (loss, evaluator) in [(L1DistLoss(), testl1), (customloss, customloss)]
    local options = Options(;
        binary_operators=(+, *, -, /),
        unary_operators=(cos, exp),
        npopulations=4,
        loss=loss,
    )
    x = randn(MersenneTwister(0), Float32, 100)
    y = randn(MersenneTwister(1), Float32, 100)
    w = abs.(randn(MersenneTwister(2), Float32, 100))
    @test abs(Loss(x, y, options) - sum(evaluator.(x, y))/length(x)) < 1e-6
    @test abs(Loss(x, y, w, options) - sum(evaluator.(x, y, w))/sum(w)) < 1e-6
end

# Test simplification:
include("test_simplification.jl")

# Test `print`:
include("test_print.jl")


# Test simple evaluations:
options = Options(
    binary_operators=(+, *, /, -),
    unary_operators=(cos, sin),
)

# Here, we unittest the fast function evaluation scheme
# We need to trigger all possible fused functions, with all their logic.
# These are as follows:

## We fuse (and compile) the following:
##  - op(op2(x, y)), where x, y, z are constants or variables.
##  - op(op2(x)), where x is a constant or variable.
##  - op(x), for any x.
## We fuse (and compile) the following:
##  - op(x, y), where x, y are constants or variables.
##  - op(x, y), where x is a constant or variable but y is not.
##  - op(x, y), where y is a constant or variable but x is not.
##  - op(x, y), for any x or y
for fnc in [
        # deg2_l0_r0_eval
        (x1, x2, x3) -> x1 * x2,
        (x1, x2, x3) -> x1 * 3f0,
        (x1, x2, x3) -> 3f0 * x2,
        (((x1, x2, x3) -> 3f0 * 6f0), ((x1, x2, x3) -> Node(3f0) * 6f0)),
        # deg2_l0_eval
        (x1, x2, x3) -> x1 * sin(x2),
        (x1, x2, x3) -> 3f0 * sin(x2),

        # deg2_r0_eval
        (x1, x2, x3) -> sin(x1) * x2,
        (x1, x2, x3) -> sin(x1) * 3f0,

        # deg1_l2_ll0_lr0_eval
        (x1, x2, x3) -> cos(x1 * x2),
        (x1, x2, x3) -> cos(x1 * 3f0),
        (x1, x2, x3) -> cos(3f0 * x2),
        (((x1, x2, x3) -> cos(3f0 * -0.5f0)), ((x1, x2, x3) -> cos(Node(3f0) * -0.5f0))),

        # deg1_l1_ll0_eval
        (x1, x2, x3) -> cos(sin(x1)),
        (((x1, x2, x3) -> cos(sin(3f0))), ((x1, x2, x3) -> cos(sin(Node(3f0))))),

        # everything else:
        (x1, x2, x3) -> (sin(cos(sin(cos(x1) * x3) * 3f0) * -0.5f0) + 2f0) * 5f0,
    ]

    # check if fnc is tuple
    if typeof(fnc) <: Tuple
        realfnc = fnc[1]
        nodefnc = fnc[2]
    else
        realfnc = fnc
        nodefnc = fnc
    end

    global tree = nodefnc(Node("x1"), Node("x2"), Node("x3"))

    N = 100
    nfeatures = 3
    X = randn(MersenneTwister(0), Float32, nfeatures, N)
    
    test_y = evalTreeArray(tree, X, options)[1]
    true_y = realfnc.(X[1, :], X[2, :], X[3, :])

    zero_tolerance = 1e-6
    @test all(abs.(test_y .- true_y)/N .< zero_tolerance)
end


println("Testing whether probPickFirst works.")
include("test_prob_pick_first.jl")
println("Passed.")

println("Testing crossover function.")
using SymbolicRegression
using Test
using SymbolicRegression: crossoverTrees
options = SymbolicRegression.Options(
    binary_operators = (+, *, /, -),
    unary_operators = (cos, exp),
    npopulations = 8
)
tree1 = cos(Node("x1")) + (3f0 + Node("x2"))
tree2 = exp(Node("x1") - Node("x2") * Node("x2")) + 10f0 * Node("x3")

# See if we can observe operators flipping sides:
cos_flip_to_tree2 = false
exp_flip_to_tree1 = false
swapped_cos_with_exp = false
for i=1:1000
    child_tree1, child_tree2 = crossoverTrees(tree1, tree2)
    if occursin("cos", repr(child_tree2))
        # Moved cosine to tree2
        global cos_flip_to_tree2 = true
    end
    if occursin("exp", repr(child_tree1))
        # Moved exp to tree1
        global exp_flip_to_tree1 = true
    end
    if occursin("cos", repr(child_tree2)) && occursin("exp", repr(child_tree1))
        global swapped_cos_with_exp = true
        # Moved exp with cos
        @assert !occursin("cos", repr(child_tree1))
        @assert !occursin("exp", repr(child_tree2))
    end
    
    # Check that exact same operators, variables, numbers before and after:
    rep_tree_final = sort([a for a in repr(child_tree1) * repr(child_tree2)])
    rep_tree_final = strip(String(rep_tree_final), ['(', ')', ' '])
    rep_tree_initial = sort([a for a in repr(tree1) * repr(tree2)])
    rep_tree_initial = strip(String(rep_tree_initial), ['(', ')', ' '])
    @test rep_tree_final == rep_tree_initial
end

@test cos_flip_to_tree2
@test exp_flip_to_tree1
@test swapped_cos_with_exp
println("Passed.")
