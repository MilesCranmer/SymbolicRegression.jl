@testitem "Test mixed settings." tags = [:integration] begin
    include("test_mixed.jl")
end

@testitem "Testing fast-cycle and custom variable names" tags = [:integration] begin
    include("test_fast_cycle.jl")
end

@testitem "Testing whether we can stop based on clock time." tags = [:integration] begin
    include("test_stop_on_clock.jl")
end

@testitem "Running README example." tags = [:integration] begin
    include("../example.jl")
end

@testitem "Testing whether the recorder works." tags = [:integration] begin
    include("test_recorder.jl")
end

@testitem "Testing whether deterministic mode works." tags = [:integration] begin
    include("test_deterministic.jl")
end

@testitem "Testing whether early stop criteria works." tags = [:integration] begin
    include("test_early_stop.jl")
end

@testitem "Test MLJ integration" tags = [:integration] begin
    include("test_mlj.jl")
end

@testitem "Testing whether we can move operators to workers." tags = [:integration] begin
    include("test_custom_operators_multiprocessing.jl")
end

@testitem "Test whether the precompilation script works." tags = [:integration] begin
    include("test_precompilation.jl")
end

@testitem "Test whether custom objectives work." tags = [:integration] begin
    include("test_custom_objectives.jl")
end

@testitem "Test abstract numbers" tags = [:integration] begin
    include("test_abstract_numbers.jl")
end
