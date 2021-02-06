julia --code-coverage=user --project=. -e 'import Pkg; Pkg.test("SymbolicRegression"; coverage=true)'
julia coverage.jl
