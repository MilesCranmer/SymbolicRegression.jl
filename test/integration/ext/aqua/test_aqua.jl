@testitem "integration/ext/aqua/test_aqua.jl" begin
using SymbolicRegression
using Aqua

Aqua.test_all(SymbolicRegression; ambiguities=false)

Aqua.test_ambiguities(SymbolicRegression)
end
