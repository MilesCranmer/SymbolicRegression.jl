using SymbolicRegression, SymbolicUtils, Test, Random
using SymbolicRegression: Options, stringTree, evalTreeArray, Dataset
using SymbolicRegression: printTree, pow, EvalLoss, scoreFunc, Node
using SymbolicRegression: plus, sub, mult, square, cube, div, log_abs, log2_abs, log10_abs, sqrt_abs, neg, greater, greater, relu, logical_or, logical_and
using SymbolicRegression: node_to_symbolic, symbolic_to_node


x1 = 2.0
# Initialize functions in Base....
for unaop in [cos, exp, log_abs, log2_abs, log10_abs, relu]
    for binop in [sub]

        function make_options(;kw...)
            Options(
                binary_operators=(+, *, ^, /, binop),
                unary_operators=(unaop,),
                npopulations=4;
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
            if T == Float16
                zero_tolerance = 3e-2
            else
                zero_tolerance = 1e-6
            end

            Random.seed!(0)
            N = 100
            X = map(x->convert(T, x), randn(Float64, 5, N)/3)
            X = X + sign.(X) * convert(T, 0.1)
            y = map(x->convert(T, x), f_true.(X[1, :]))
            dataset = Dataset(X, y)
            test_y, complete = evalTreeArray(tree, X, make_options())

            # Test Evaluation
            @test complete == true
            @test all(abs.(test_y - y)/N .< zero_tolerance)

            #Test Scoring
            @test abs(EvalLoss(tree, dataset, make_options())) < zero_tolerance
            @test abs(scoreFunc(dataset, one(T), tree, make_options(parsimony=0.0))) < zero_tolerance
            @test scoreFunc(dataset, one(T), tree, make_options(parsimony=1.0)) > 1.0
            @test scoreFunc(dataset, one(T), tree, make_options()) < scoreFunc(dataset, one(T), tree_bad, make_options())
            @test scoreFunc(dataset, one(T)*10, tree_bad, make_options()) < scoreFunc(dataset, one(T), tree_bad, make_options())

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
tree = Node(5, (Node(3.0) * Node(1, Node("x1"))) ^ 2.0, -1.2)
_inv(x) = 1/x
options = Options(
    binary_operators=(+, *, ^, /, greater),
    unary_operators=(_inv,),
    npopulations=4;
)

eqn = node_to_symbolic(tree, options;
                       varMap=["energy"], index_functions=true)
tree2 = symbolic_to_node(eqn, options; varMap=["energy"])

@test stringTree(tree, options) == stringTree(tree2, options)
