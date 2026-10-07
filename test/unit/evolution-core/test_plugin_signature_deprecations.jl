@testitem "Deprecated best_of_sample signature forwards to current method" begin
    using SymbolicRegression
    using SymbolicRegression: Dataset
    using SymbolicRegression.PluginsModule.AdaptiveParsimonyModule:
        AdaptiveParsimonyState, RunningSearchStatistics
    using SymbolicRegression.EvolutionModule: best_of_sample
    using Random
    using Test

    options = Options(;
        binary_operators=(+, *),
        mutation_weights=(; do_nothing=1e30),
        tournament_selection_n=1,
    )
    dataset = Dataset(randn(2, 16), randn(16))
    member = PopMember(dataset, Node(Float64; feature=1), options; deterministic=false)
    population = Population([member])
    statistics = RunningSearchStatistics(; options)
    plugin_states = map(options.plugins) do plugin
        if plugin isa SymbolicRegression.AdaptiveParsimonyPlugin
            AdaptiveParsimonyState(statistics)
        else
            nothing
        end
    end

    Random.seed!(0)
    current_best = best_of_sample(population, options; plugin_states)
    Random.seed!(0)
    deprecated_best = @test_deprecated best_of_sample(population, statistics, options)
    @test deprecated_best.tree == current_best.tree
end
