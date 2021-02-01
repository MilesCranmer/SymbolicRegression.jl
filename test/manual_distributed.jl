using Distributed, Test, SymbolicUtils, Pkg
procs = addprocs(4)
project_path = splitdir(Pkg.project().path)[1]
@everywhere procs begin
    Base.MainInclude.eval(quote
        using Pkg
        Pkg.activate($$project_path)
    end)
end
@everywhere using SymbolicRegression
_inv(x::Float32)::Float32 = 1f0/x
X = randn(Float32, 5, 100)
y = 2 ./ (X[3, :] .+ 1.5f0)

options = SymbolicRegression.Options(
    binary_operators=(+, *),
    unary_operators=(_inv,),
    npopulations=4
)
hallOfFame = EquationSearch(X, y, niterations=2, options=options, procs=procs)
rmprocs(procs)

dominating = calculateParetoFrontier(X, y, hallOfFame, options)
best = dominating[end]
eqn = node_to_symbolic(best.tree, options, evaluate_functions=true)

@syms x1::Real x2::Real x3::Real x4::Real
true_eqn = 2 / (x3 + 1.5)
residual = simplify(eqn - true_eqn)

# Test the score
@test best.score < 1e-6
x3 = 0.1f0
# Test the actual equation found:
@test abs(eval(Meta.parse(string(residual)))) < 1e-6
