using TestItems: @testitem
using TestItemRunner: @run_package_tests

ENV["SYMBOLIC_REGRESSION_TEST"] = "true"

const SYMBOLIC_REGRESSION_TEST_SUITE = get(ENV, "SYMBOLIC_REGRESSION_TEST_SUITE", "")
const SYMBOLIC_REGRESSION_TEST_NAMES = get(ENV, "SYMBOLIC_REGRESSION_TEST_NAMES", "")
tags_to_run = map(Symbol, filter(!isempty, split(SYMBOLIC_REGRESSION_TEST_SUITE, ",")))
names_to_run = filter(!isempty, split(SYMBOLIC_REGRESSION_TEST_NAMES, ","))
test_filter = if !isempty(names_to_run)
    ti -> any(name -> occursin(name, ti.name), names_to_run)
else
    tags_to_run = isempty(tags_to_run) ? [:part1, :part2, :part3] : tags_to_run
    ti -> !isdisjoint(ti.tags, tags_to_run)
end
@run_package_tests(filter = test_filter, verbose = true)

# TODO: This is a very slow test
include("test_operators.jl")

@testitem "Test tree construction and scoring" tags = [:part3] begin
    include("test_tree_construction.jl")
end

include("test_graph_nodes.jl")

@testitem "Test SymbolicUtils interface" tags = [:part1] begin
    include("test_symbolic_utils.jl")
end

@testitem "Test constraints interface" tags = [:part2] begin
    include("test_constraints.jl")
end

@testitem "Test custom losses" tags = [:part1] begin
    include("test_losses.jl")
end

@testitem "Test derivatives" tags = [:part2] begin
    include("test_derivatives.jl")
end
include("test_expression_derivatives.jl")

@testitem "Test simplification" tags = [:part3] begin
    include("test_simplification.jl")
end

@testitem "Test printing" tags = [:part1] begin
    include("test_print.jl")
end

@testitem "Test validity of expression evaluation" tags = [:part2] begin
    include("test_evaluation.jl")
end

@testitem "Test turbo mode with NaN" tags = [:part3] begin
    include("test_turbo_nan.jl")
end

@testitem "Test validity of integer expression evaluation" tags = [:part1] begin
    include("test_integer_evaluation.jl")
end

@testitem "Test tournament selection" tags = [:part2] begin
    include("test_prob_pick_first.jl")
end

@testitem "Test crossover mutation" tags = [:part3] begin
    include("test_crossover.jl")
end

include("test_rotation.jl")

# TODO: This is another very slow test
@testitem "Test NaN detection in evaluator" tags = [:part1] begin
    include("test_nan_detection.jl")
end

@testitem "Test nested constraint checking" tags = [:part2] begin
    include("test_nested_constraints.jl")
end

include("test_complexity.jl")
include("test_options.jl")

@testitem "Test hash of tree" tags = [:part2] begin
    include("test_hash.jl")
end

@testitem "Test migration" tags = [:part3] begin
    include("test_migration.jl")
end

@testitem "Test deprecated options" tags = [:part1] begin
    include("test_deprecation.jl")
end

@testitem "Test optimization mutation" tags = [:part2] begin
    include("test_optimizer_mutation.jl")
end

@testitem "Test RunningSearchStatistics" tags = [:part3] begin
    include("test_search_statistics.jl")
end

@testitem "Test utils" tags = [:part1] begin
    include("test_utils.jl")
end

include("test_units.jl")
include("test_dataset.jl")
include("test_batched_dataset.jl")
include("test_mixed.jl")

@testitem "Testing fast-cycle and custom variable names" tags = [:part2] begin
    include("test_fast_cycle.jl")
end

@testitem "Testing whether we can stop based on clock time." tags = [:part3] begin
    include("test_stop_on_clock.jl")
end

@testitem "Running README example." tags = [:part1] begin
    ENV["SYMBOLIC_REGRESSION_IS_TESTING"] = "true"
    include("../example.jl")
end

# TODO: This is the slowest test.
@testitem "Running parameterized function example." tags = [:part1] begin
    ENV["SYMBOLIC_REGRESSION_IS_TESTING"] = "true"
    include("../examples/parameterized_function.jl")
end

@testitem "Running custom types example." tags = [:part3] begin
    ENV["SYMBOLIC_REGRESSION_IS_TESTING"] = "true"
    include("../examples/custom_types.jl")
end

@testitem "Testing whether the recorder works." tags = [:part3] begin
    include("test_recorder.jl")
end

@testitem "Testing whether deterministic mode works." tags = [:part1] begin
    include("test_deterministic.jl")
end

include("test_early_stop.jl")

include("test_mlj.jl")

include("test_custom_operators_multiprocessing.jl")
include("test_filtered_async.jl")

@testitem "Testing whether we can move loss function expression to workers." tags = [:part2] begin
    include("test_loss_function_expression_multiprocessing.jl")
end

@testitem "Test whether the precompilation script works." tags = [:part2] begin
    include("test_precompilation.jl")
end

@testitem "Test whether custom objectives work." tags = [:part3] begin
    include("test_custom_objectives.jl")
end

include("test_abstract_numbers.jl")
include("test_abstract_popmember.jl")

include("test_logging.jl")
include("test_pretty_printing.jl")
include("test_expression_builder.jl")
include("test_guesses.jl")
include("test_composable_expression.jl")
include("test_parametric_template_expressions.jl")
include("test_template_expression.jl")
include("test_template_macro.jl")
include("test_template_expression_mutation.jl")
include("test_template_expression_string.jl")
include("test_loss_scale.jl")

@testitem "Aqua tests" tags = [:part2, :aqua] begin
    include("test_aqua.jl")
end

@testitem "JET tests" tags = [:jet] begin
    test_jet_file = joinpath((@__DIR__), "test_jet.jl")
    run(`$(Base.julia_cmd()) --startup-file=no $test_jet_file`)
end
