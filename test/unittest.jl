using SymbolicRegression, SymbolicUtils, Test
using SymbolicRegression: Options, stringTree, evalTreeArray, Dataset
using SymbolicRegression: printTree, pow, EvalLoss, scoreFunc


function make_options(;kw...)
    Options(
        binary_operators=(+, *, ^, /),
        unary_operators=(cos, exp),
        npopulations=4;
        kw...
    )
end

f_true = (x1) -> (3.0 * cos(x1)) ^ 2.0
tree = (Node(3.0) * cos(Node("x1"))) ^ 2.0
tree_bad = (Node(3.0) * cos(Node("x1"))) ^ 2.1
n = countNodes(tree)

x1 = 2.0
true_result = f_true(x1)

result = eval(Meta.parse(stringTree(tree, make_options())))

" Test Basics "
@test n == 5
@test result == true_result

X = [[0.0 1 2 3 4]; [4 3 2 1 0]]'
y = f_true.(X[1, :])
dataset = Dataset(X, y)
test_y, complete = evalTreeArray(tree, X, make_options())

" Test Evaluation"
@test complete == true
@test all(test_y == y)

" Test Scoring "
@test EvalLoss(tree, dataset, make_options()) == 0.0
@test scoreFunc(dataset, 1.0, tree, make_options(parsimony=0.0)) == 0.0
@test scoreFunc(dataset, 1.0, tree, make_options(parsimony=1.0)) > 0.0
@test scoreFunc(dataset, 1.0, tree, make_options()) < scoreFunc(dataset, 1.0, tree_bad, make_options())
@test scoreFunc(dataset, 10.0, tree_bad, make_options()) < scoreFunc(dataset, 1.0, tree_bad, make_options())


