include("test_params.jl")

using Distributed
procs = addprocs(2)
using Test, Pkg
project_path = splitdir(Pkg.project().path)[1]
@everywhere procs begin
    Base.MainInclude.eval(
        quote
            using Pkg
            Pkg.activate($$project_path)
        end,
    )
end
@everywhere using SymbolicRegression
@everywhere _inv(x::Float32)::Float32 = 1.0f0 / x
X = rand(Float32, 5, 100) .+ 1
y = 1.2f0 .+ 2 ./ X[3, :]

options = SymbolicRegression.Options(;
    default_params..., binary_operators=(+, *), unary_operators=(_inv,), npopulations=8
)
hallOfFame = EquationSearch(
    X, y; niterations=8, options=options, parallelism=:multiprocessing, procs=procs
)
rmprocs(procs)

dominating = calculate_pareto_frontier(X, y, hallOfFame, options)
best = dominating[end]
# Test the score
@test best.loss < maximum_residual / 10
