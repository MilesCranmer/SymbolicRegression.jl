using SymbolicRegression, SymbolicUtils
using Random

Random.seed!(0)

## y' = x
## x' = -y

n = 100
x = randn(Float64, n)
y = randn(Float64, n)
px = randn(Float64, n)
py = randn(Float64, n)

X = ones(Float64, 4, n)
X[1, :] = x
X[2, :] = y
X[3, :] = px
X[4, :] = py

dummy_y_variable = randn(Float64, n)

function _sqrt_abs(x::T)::T where {T}
    return Base.sqrt(abs(x))
end

options = SymbolicRegression.Options(;
    binary_operators=(+, *, /, -),
    unary_operators=(_sqrt_abs, square),
    nested_constraints=[square => [_sqrt_abs => 0], _sqrt_abs => [square => 0, _sqrt_abs => 0]],
    enable_autodiff=true,
    maxsize=40,
)

hall_of_fame = EquationSearch(
    X, dummy_y_variable; niterations=400, options=options, multithreading=true,
    varMap=["x", "y", "px", "py"],
)

dominating = calculate_pareto_frontier(X, y, hall_of_fame, options)

eqn = node_to_symbolic(dominating[end].tree, options)
println(simplify(eqn * 5 + 3))

println("Complexity\tMSE\tEquation")

for member in dominating
    complexity = compute_complexity(member.tree, options)
    loss = member.loss
    string = string_tree(member.tree, options)

    println("$(complexity)\t$(loss)\t$(string)")
end
