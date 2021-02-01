using SymbolicRegression, SafeTestsets

@safetestset "Basic run" begin include("basic.jl") end
@safetestset "Manual distributed" begin include("manual_distributed.jl") end
@safetestset "User-defined operator" begin include("user_defined_operator.jl") end
