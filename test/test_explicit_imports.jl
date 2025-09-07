using SymbolicRegression
using ExplicitImports
using Test

# Test that we have no implicit imports or stale imports
@test ExplicitImports.check_no_implicit_imports(SymbolicRegression) === nothing
@test ExplicitImports.check_no_stale_explicit_imports(SymbolicRegression) === nothing
