using Base: @deprecate

# Now the batch dimension is the last axis!
@deprecate RunSR(X, y; kw...) EquationSearch(copy(transpose(X)), y; kw...)
