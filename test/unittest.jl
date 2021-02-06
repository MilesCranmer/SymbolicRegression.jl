##

using SymbolicRegression, SymbolicUtils, Test, Random
using SymbolicRegression: Options, stringTree, evalTreeArray, Dataset
using SymbolicRegression: printTree, pow, EvalLoss, scoreFunc
using SymbolicRegression: sub, greater

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

##
