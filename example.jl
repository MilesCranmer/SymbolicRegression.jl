@everywhere include("src/sr.jl")
using .SR

X = randn(Float32, 100, 5)
y = 2 * cos.(X[:, 4]) + X[:, 1] .^ 2 .- 2

RunSR(X, y, 100, Options())
rmprocs()
