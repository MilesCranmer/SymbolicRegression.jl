using SymbolicRegression
using Aqua

Aqua.test_all(SymbolicRegression; ambiguities=false, project_toml_formatting=false)

# Some dependencies have ambiguous methods:
Aqua.test_ambiguities(SymbolicRegression; recursive=false)
