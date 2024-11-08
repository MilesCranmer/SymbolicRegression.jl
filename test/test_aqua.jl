using SymbolicRegression
using Aqua

Aqua.test_all(SymbolicRegression; ambiguities=false)

Aqua.test_ambiguities(SymbolicRegression)
