using TestItems: @testitem
using TestItemRunner: @run_package_tests

ENV["SYMBOLIC_REGRESSION_TEST"] = "true"
tags_to_run = let t = get(ENV, "SYMBOLIC_REGRESSION_TEST_SUITE", "unit,integration")
    t = split(t, ",")
    t = map(Symbol, t)
    t
end

@eval @run_package_tests filter = ti -> !isdisjoint(ti.tags, $tags_to_run)

@testitem "JET tests" tags = [:integration, :jet] begin
    test_jet_file = joinpath((@__DIR__), "test_jet.jl")
    run(`$(Base.julia_cmd()) --startup-file=no $test_jet_file`)
end

@testitem "Test custom operators and additional types" tags = [:unit] begin
    include("test_operators.jl")
end

@testitem "Test tree construction and scoring" tags = [:unit] begin
    include("test_tree_construction.jl")
end

@testitem "Test SymbolicUtils interface" tags = [:unit] begin
    include("test_symbolic_utils.jl")
end

@testitem "Test constraints interface" tags = [:unit] begin
    include("test_constraints.jl")
end

@testitem "Test custom losses" tags = [:unit] begin
    include("test_losses.jl")
end

@testitem "Test derivatives" tags = [:unit] begin
    include("test_derivatives.jl")
end

@testitem "Test simplification" tags = [:unit] begin
    include("test_simplification.jl")
end

@testitem "Test printing" tags = [:unit] begin
    include("test_print.jl")
end

@testitem "Test validity of expression evaluation" tags = [:unit] begin
    include("test_evaluation.jl")
end

@testitem "Test turbo mode with NaN" tags = [:unit] begin
    include("test_turbo_nan.jl")
end

@testitem "Test validity of integer expression evaluation" tags = [:unit] begin
    include("test_integer_evaluation.jl")
end

@testitem "Test tournament selection" tags = [:unit] begin
    include("test_prob_pick_first.jl")
end

@testitem "Test crossover mutation" tags = [:unit] begin
    include("test_crossover.jl")
end

@testitem "Test NaN detection in evaluator" tags = [:unit] begin
    include("test_nan_detection.jl")
end

@testitem "Test nested constraint checking" tags = [:unit] begin
    include("test_nested_constraints.jl")
end

@testitem "Test complexity evaluation" tags = [:unit] begin
    include("test_complexity.jl")
end

@testitem "Test options" tags = [:unit] begin
    include("test_options.jl")
end

@testitem "Test hash of tree" tags = [:unit] begin
    include("test_hash.jl")
end

@testitem "Test migration" tags = [:unit] begin
    include("test_migration.jl")
end

@testitem "Test deprecated options" tags = [:unit] begin
    include("test_deprecation.jl")
end

@testitem "Test optimization mutation" tags = [:unit] begin
    include("test_optimizer_mutation.jl")
end

@testitem "Test RunningSearchStatistics" tags = [:unit] begin
    include("test_search_statistics.jl")
end

@testitem "Test utils" tags = [:unit] begin
    include("test_utils.jl")
end

@testitem "Test logging" tags = [:unit] begin
    include("test_logging.jl")
end

@testitem "Test units" tags = [:integration] begin
    include("test_units.jl")
end

@testitem "Dataset" tags = [:unit] begin
    include("test_dataset.jl")
end

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

@testitem "Aqua tests" tags = [:integration, :aqua] begin
    include("test_aqua.jl")
end
