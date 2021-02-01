using SymbolicRegression, Test, SafeTestsets
@time begin
    @time @safetestset "Basic run" begin include("basic.jl") end
end
