using SymbolicRegression, SymbolicUtils, Unitful

X = randn(Float32, 5, 100)
y = 2 * cos.(X[4, :]) + X[1, :] .^ 2 .- 2

options = SymbolicRegression.Options(;
    binary_operators=[+, *, /, -], unary_operators=[cos, exp], npopulations=10
)

hall_of_fame = EquationSearch(
    X,
    y;
    niterations=40,
    options=options,
    parallelism=:serial,
    variable_units=[u"m", u"s", u"kg", u"m", u"s"],
)

dominating = calculate_pareto_frontier(hall_of_fame)

trees = [member.tree for member in dominating]

tree = trees[end]
output, did_succeed = eval_tree_array(tree, X, options)

eqn = node_to_symbolic(dominating[end].tree, options)
println("Complexity\tMSE\tEquation")

for member in dominating
    complexity = compute_complexity(member, options)
    loss = member.loss
    string = string_tree(member.tree, options)

    println("$(complexity)\t$(loss)\t$(string)")
end
