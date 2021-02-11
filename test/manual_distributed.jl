using FromFile
@from "test_params.jl" import maximum_residual

using Distributed
procs = addprocs(4)
using Test, Pkg
project_path = splitdir(Pkg.project().path)[1]
@everywhere procs begin
    Base.MainInclude.eval(quote
        using Pkg
        Pkg.activate($$project_path)
    end)
end
@everywhere using SymbolicRegression
@everywhere _inv(x::Float32)::Float32 = 1f0/x
X = rand(Float32, 5, 100) .+ 1
y = 1.2f0 .+ 2 ./ X[3, :]

options = SymbolicRegression.Options(
    binary_operators=(+, *),
    unary_operators=(_inv,),
    npopulations=8
)
hallOfFame = EquationSearch(X, y, niterations=8, options=options, procs=procs)
rmprocs(procs)

dominating = calculateParetoFrontier(X, y, hallOfFame, options)
best = dominating[end]
# Test the score
@test best.score < maximum_residual / 10
