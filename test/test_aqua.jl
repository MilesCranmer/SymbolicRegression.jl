using SymbolicRegression
using Aqua

Aqua.test_all(SymbolicRegression; ambiguities=false, project_toml_formatting=false)

VERSION >= v"1.9" && Aqua.test_ambiguities(SymbolicRegression)
