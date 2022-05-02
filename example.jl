using SymbolicRegression, SymbolicUtils

X = randn(Float32, 5, 100)
y = 2 * cos.(X[4, :]) + X[1, :] .^ 2 .- 2

options = SymbolicRegression.Options(;
    binary_operators=(+, *, /, -), unary_operators=(cos, exp), npopulations=40
)

hall_of_fame = EquationSearch(X, y; niterations=50, options=options, numprocs=4)

dominating = calculate_pareto_frontier(X, y, hall_of_fame, options)

eqn = node_to_symbolic(dominating[end].tree, options)
println(simplify(eqn * 5 + 3))

println("Complexity\tMSE\tEquation")

for member in dominating
    size = count_nodes(member.tree)
    loss = member.loss
    string = string_tree(member.tree, options)

    println("$(size)\t$(loss)\t$(string)")
end
