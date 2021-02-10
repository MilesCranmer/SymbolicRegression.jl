# Will be included explicitly
using Base: @deprecate

# Now the batch dimension is the last axis!
@deprecate RunSR(X, y; kw...) EquationSearch(copy(transpose(X)), y; kw...)
@deprecate sqrtm(x) sqrt_abs(x)
@deprecate logm(x) log_abs(x)
@deprecate logm2(x) log2_abs(x)
@deprecate logm10(x) log10_abs(x)
