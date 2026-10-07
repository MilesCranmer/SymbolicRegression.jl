@testitem "Legacy module paths preserve downstream consumers" begin
    using SymbolicRegression
    using Test
    using Suppressor: @capture_err

    consumer = Module(gensym(:LegacyModuleConsumer))
    for legacy_import in (
        :(using SymbolicRegression.CoreModule.OptionsModule: Options),
        :(using SymbolicRegression.CoreModule.DatasetModule: Dataset),
        :(using SymbolicRegression: PopMemberModule),
        :(import SymbolicRegression.CoreModule.PluginModule:
            AbstractPlugin, init_plugin_state),
    )
        warning = @capture_err Core.eval(consumer, legacy_import)
        @test occursin(r"deprecated"i, warning)
    end
    Core.eval(
        consumer,
        quote
            struct LegacyPlugin <: AbstractPlugin end
            init_plugin_state(::LegacyPlugin, options, dataset) = dataset.n
        end,
    )

    options = consumer.Options(; binary_operators=(+,), default_plugins=())
    X = reshape([1.0, 2.0, 3.0], 1, :)
    dataset = consumer.Dataset(X, copy(vec(X)))
    member = consumer.PopMemberModule.PopMember(
        dataset, Node{Float64}(; feature=1), options; deterministic=true
    )

    @test options isa SymbolicRegression.Options
    @test dataset isa SymbolicRegression.Dataset
    @test dataset.X == X
    @test member isa SymbolicRegression.PopMember
    @test member.loss == 0.0
    @test consumer.PopMemberModule === SymbolicRegression.EvolutionModule.PopMemberModule
    @test consumer.PopMemberModule.PopMember ===
        SymbolicRegression.EvolutionModule.PopMemberModule.PopMember
    @test consumer.init_plugin_state === SymbolicRegression.init_plugin_state
    @test consumer.init_plugin_state ===
        SymbolicRegression.InterfacesModule.PluginModule.init_plugin_state
    plugin = consumer.LegacyPlugin()
    @test SymbolicRegression.init_plugin_state(plugin, options, dataset) == 3
    @test SymbolicRegression.InterfacesModule.PluginModule.init_plugin_state(
        plugin, options, dataset
    ) == 3
end
