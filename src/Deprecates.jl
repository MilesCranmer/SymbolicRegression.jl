using Base: @deprecate
@from "Operators.jl" import sqrt_abs, log_abs, log2_abs, log10_abs
@from "SymbolicRegression.jl" import EquationSearch

# Now the batch dimension is the last axis!
@deprecate RunSR(X, y; kw...) EquationSearch(copy(transpose(X)), y; kw...)
@deprecate sqrtm(x) sqrt_abs(x)
@deprecate logm(x) log_abs(x)
@deprecate logm2(x) log2_abs(x)
@deprecate logm10(x) log10_abs(x)
