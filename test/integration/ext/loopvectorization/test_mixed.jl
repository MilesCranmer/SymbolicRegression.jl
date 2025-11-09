@testitem "Search with batching & weighted & serial & progress bar & warmup & BFGS" begin
    include("test_mixed_utils.jl")
    test_mixed(0, true, true, :serial)
end

@testitem "Search with multiprocessing & batching & multi-output & use_frequency & string-specified parallelism" begin
    include("test_mixed_utils.jl")
    test_mixed(1, true, false, :multiprocessing)
end

@testitem "Search with multi-threading & default settings" begin
    include("test_mixed_utils.jl")
    test_mixed(2, false, true, :multithreading)
end

@testitem "Search with multi-threading & weighted & crossover & use_frequency_in_tournament & bumper" begin
    include("test_mixed_utils.jl")
    test_mixed(3, false, false, :multithreading)
end

@testitem "Search with multi-threading & crossover & skip mutation failures & both frequencies options & Float16 type" begin
    include("test_mixed_utils.jl")
    test_mixed(4, false, false, :multithreading)
end

@testitem "Search with multiprocessing & default hyperparameters & Float64 type & turbo" begin
    include("test_mixed_utils.jl")
    test_mixed(5, false, false, :multiprocessing)
end
