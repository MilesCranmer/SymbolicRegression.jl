using SymbolicRegression

X = randn(Float32, 5, 100)
y = 2 * cos.(X[4, :]) + X[1, :] .^ 2 .- 2

options = SymbolicRegression.Options(;
    binary_operators=(+, *, /, -), unary_operators=(cos, exp), npopulations=8
)

hallOfFame = EquationSearch(
    X, y; niterations=5, options=options, numprocs=0, multithreading=true
)
