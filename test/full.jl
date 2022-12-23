using SymbolicRegression
using Test
using SafeTestsets
using SymbolicRegression: string_tree
using Random

@safetestset "Test mixed settings." begin
    include("test_mixed.jl")
end

@safetestset "Testing fast-cycle and custom variable names, with mutations" begin
    include("test_fast_cycle.jl")
end

@safetestset "Testing whether we can stop based on clock time." begin
    include("test_stop_on_clock.jl")
end

@safetestset "Running README example." begin
    include("../example.jl")
end

@safetestset "Testing whether the recorder works." begin
    include("test_recorder.jl")
end

@safetestset "Testing whether deterministic mode works." begin
    include("test_deterministic.jl")
end

@safetestset "Testing whether early stop criteria works." begin
    include("test_early_stop.jl")
end

@testset "Testing whether we can move operators to workers." begin
    include("test_custom_operators_multiprocessing.jl")
end

@testset "Test whether the precompilation script works." begin
    include("test_precompilation.jl")
end

@testset "Test whether custom objectives work." begin
    include("test_custom_objectives.jl")
end
