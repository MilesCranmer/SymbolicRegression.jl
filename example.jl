@everywhere include("src/sr.jl")
using .SR

X = randn(Float32, 100, 5)
y = X[1:end, 3] .^ 2

RunSR(X, y, 100, Options())
rmprocs(nprocs)
