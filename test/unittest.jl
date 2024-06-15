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

@testitem "Test units" tags = [:unit] begin
    include("test_units.jl")
end

@testitem "Dataset" tags = [:unit] begin
    include("test_dataset.jl")
end
