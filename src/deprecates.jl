module LegacyCoreModule

using ..SymbolicRegression: SymbolicRegression
Base.@deprecate_binding CoreModule LegacyCoreModule false

Base.@deprecate_binding ProgramConstantsModule SymbolicRegression.InterfacesModule.ProgramConstantsModule false
Base.@deprecate_binding DatasetModule SymbolicRegression.InterfacesModule.DatasetModule false
Base.@deprecate_binding MutationsModule SymbolicRegression.InterfacesModule.MutationsModule false
Base.@deprecate_binding CrossoversModule SymbolicRegression.InterfacesModule.CrossoversModule false
Base.@deprecate_binding MutationWeightsModule SymbolicRegression.ConfigModule.MutationWeightsModule false
Base.@deprecate_binding OptionsStructModule SymbolicRegression.ConfigModule.OptionsStructModule false
Base.@deprecate_binding OperatorsModule SymbolicRegression.ConfigModule.OperatorsModule false
Base.@deprecate_binding ExpressionSpecModule SymbolicRegression.InterfacesModule.ExpressionSpecModule false
Base.@deprecate_binding PluginModule SymbolicRegression.InterfacesModule.PluginModule false
Base.@deprecate_binding OptionsModule SymbolicRegression.ConfigModule.OptionsModule false
Base.@deprecate_binding InterfaceDataTypesModule SymbolicRegression.InterfacesModule.InterfaceDataTypesModule false
Base.@deprecate_binding UtilsModule SymbolicRegression.UtilsModule false
Base.@deprecate_binding create_expression SymbolicRegression.InterfacesModule.OptionsInterfaceModule.create_expression false
Base.@deprecate_binding MaybeTrace SymbolicRegression.InterfacesModule.ProgramConstantsModule.MaybeTrace false
Base.@deprecate_binding TraceType SymbolicRegression.InterfacesModule.ProgramConstantsModule.TraceType false
Base.@deprecate_binding DATA_TYPE SymbolicRegression.InterfacesModule.ProgramConstantsModule.DATA_TYPE false
Base.@deprecate_binding LOSS_TYPE SymbolicRegression.InterfacesModule.ProgramConstantsModule.LOSS_TYPE false
Base.@deprecate_binding Dataset SymbolicRegression.InterfacesModule.DatasetModule.Dataset false
Base.@deprecate_binding BasicDataset SymbolicRegression.InterfacesModule.DatasetModule.BasicDataset false
Base.@deprecate_binding SubDataset SymbolicRegression.InterfacesModule.DatasetModule.SubDataset false
Base.@deprecate_binding is_weighted SymbolicRegression.InterfacesModule.DatasetModule.is_weighted false
Base.@deprecate_binding has_units SymbolicRegression.InterfacesModule.DatasetModule.has_units false
Base.@deprecate_binding max_features SymbolicRegression.InterfacesModule.DatasetModule.max_features false
Base.@deprecate_binding batch SymbolicRegression.InterfacesModule.DatasetModule.batch false
Base.@deprecate_binding get_indices SymbolicRegression.InterfacesModule.DatasetModule.get_indices false
Base.@deprecate_binding get_full_dataset SymbolicRegression.InterfacesModule.DatasetModule.get_full_dataset false
Base.@deprecate_binding dataset_fraction SymbolicRegression.InterfacesModule.DatasetModule.dataset_fraction false
Base.@deprecate_binding MutationWeights SymbolicRegression.ConfigModule.MutationWeightsModule.MutationWeights false
Base.@deprecate_binding sample_mutation SymbolicRegression.ConfigModule.MutationWeightsModule.sample_mutation false
Base.@deprecate_binding AbstractMutation SymbolicRegression.InterfacesModule.MutationsModule.AbstractMutation false
Base.@deprecate_binding ConstantMutation SymbolicRegression.InterfacesModule.MutationsModule.ConstantMutation false
Base.@deprecate_binding OperatorMutation SymbolicRegression.InterfacesModule.MutationsModule.OperatorMutation false
Base.@deprecate_binding FeatureMutation SymbolicRegression.InterfacesModule.MutationsModule.FeatureMutation false
Base.@deprecate_binding SwapOperandsMutation SymbolicRegression.InterfacesModule.MutationsModule.SwapOperandsMutation false
Base.@deprecate_binding AddNodeMutation SymbolicRegression.InterfacesModule.MutationsModule.AddNodeMutation false
Base.@deprecate_binding InsertNodeMutation SymbolicRegression.InterfacesModule.MutationsModule.InsertNodeMutation false
Base.@deprecate_binding DeleteNodeMutation SymbolicRegression.InterfacesModule.MutationsModule.DeleteNodeMutation false
Base.@deprecate_binding FormConnectionMutation SymbolicRegression.InterfacesModule.MutationsModule.FormConnectionMutation false
Base.@deprecate_binding BreakConnectionMutation SymbolicRegression.InterfacesModule.MutationsModule.BreakConnectionMutation false
Base.@deprecate_binding RotateTreeMutation SymbolicRegression.InterfacesModule.MutationsModule.RotateTreeMutation false
Base.@deprecate_binding BacksolveMutation SymbolicRegression.InterfacesModule.MutationsModule.BacksolveMutation false
Base.@deprecate_binding SimplifyMutation SymbolicRegression.InterfacesModule.MutationsModule.SimplifyMutation false
Base.@deprecate_binding RandomizeMutation SymbolicRegression.InterfacesModule.MutationsModule.RandomizeMutation false
Base.@deprecate_binding OptimizeMutation SymbolicRegression.InterfacesModule.MutationsModule.OptimizeMutation false
Base.@deprecate_binding DoNothingMutation SymbolicRegression.InterfacesModule.MutationsModule.DoNothingMutation false
Base.@deprecate_binding ConstantMutationContext SymbolicRegression.InterfacesModule.MutationsModule.ConstantMutationContext false
Base.@deprecate_binding BUILTIN_MUTATION_TYPES SymbolicRegression.InterfacesModule.MutationsModule.BUILTIN_MUTATION_TYPES false
Base.@deprecate_binding default_mutations SymbolicRegression.InterfacesModule.MutationsModule.default_mutations false
Base.@deprecate_binding AbstractCrossover SymbolicRegression.InterfacesModule.CrossoversModule.AbstractCrossover false
Base.@deprecate_binding SubtreeCrossover SymbolicRegression.InterfacesModule.CrossoversModule.SubtreeCrossover false
Base.@deprecate_binding BUILTIN_CROSSOVER_TYPES SymbolicRegression.InterfacesModule.CrossoversModule.BUILTIN_CROSSOVER_TYPES false
Base.@deprecate_binding default_crossovers SymbolicRegression.InterfacesModule.CrossoversModule.default_crossovers false
Base.@deprecate_binding AbstractOptions SymbolicRegression.InterfacesModule.OptionsInterfaceModule.AbstractOptions false
Base.@deprecate_binding Options SymbolicRegression.ConfigModule.OptionsStructModule.Options false
Base.@deprecate_binding ComplexityMapping SymbolicRegression.ConfigModule.OptionsStructModule.ComplexityMapping false
Base.@deprecate_binding specialized_options SymbolicRegression.ConfigModule.OptionsStructModule.specialized_options false
Base.@deprecate_binding operator_specialization SymbolicRegression.ConfigModule.OptionsStructModule.operator_specialization false
Base.@deprecate_binding use_batching SymbolicRegression.ConfigModule.OptionsStructModule.use_batching false
Base.@deprecate_binding get_batch_size SymbolicRegression.ConfigModule.OptionsStructModule.get_batch_size false
Base.@deprecate_binding batching_required SymbolicRegression.ConfigModule.OptionsStructModule.batching_required false
Base.@deprecate_binding WarmStartIncompatibleError SymbolicRegression.ConfigModule.OptionsStructModule.WarmStartIncompatibleError false
Base.@deprecate_binding check_warm_start_compatibility SymbolicRegression.ConfigModule.OptionsStructModule.check_warm_start_compatibility false
Base.@deprecate_binding get_safe_op SymbolicRegression.ConfigModule.OperatorsModule.get_safe_op false
Base.@deprecate_binding plus SymbolicRegression.ConfigModule.OperatorsModule.plus false
Base.@deprecate_binding sub SymbolicRegression.ConfigModule.OperatorsModule.sub false
Base.@deprecate_binding mult SymbolicRegression.ConfigModule.OperatorsModule.mult false
Base.@deprecate_binding square SymbolicRegression.ConfigModule.OperatorsModule.square false
Base.@deprecate_binding cube SymbolicRegression.ConfigModule.OperatorsModule.cube false
Base.@deprecate_binding pow SymbolicRegression.ConfigModule.OperatorsModule.pow false
Base.@deprecate_binding safe_pow SymbolicRegression.ConfigModule.OperatorsModule.safe_pow false
Base.@deprecate_binding safe_log SymbolicRegression.ConfigModule.OperatorsModule.safe_log false
Base.@deprecate_binding safe_log2 SymbolicRegression.ConfigModule.OperatorsModule.safe_log2 false
Base.@deprecate_binding safe_log10 SymbolicRegression.ConfigModule.OperatorsModule.safe_log10 false
Base.@deprecate_binding safe_log1p SymbolicRegression.ConfigModule.OperatorsModule.safe_log1p false
Base.@deprecate_binding safe_sqrt SymbolicRegression.ConfigModule.OperatorsModule.safe_sqrt false
Base.@deprecate_binding safe_asin SymbolicRegression.ConfigModule.OperatorsModule.safe_asin false
Base.@deprecate_binding safe_acos SymbolicRegression.ConfigModule.OperatorsModule.safe_acos false
Base.@deprecate_binding safe_acosh SymbolicRegression.ConfigModule.OperatorsModule.safe_acosh false
Base.@deprecate_binding safe_atanh SymbolicRegression.ConfigModule.OperatorsModule.safe_atanh false
Base.@deprecate_binding neg SymbolicRegression.ConfigModule.OperatorsModule.neg false
Base.@deprecate_binding greater SymbolicRegression.ConfigModule.OperatorsModule.greater false
Base.@deprecate_binding less SymbolicRegression.ConfigModule.OperatorsModule.less false
Base.@deprecate_binding greater_equal SymbolicRegression.ConfigModule.OperatorsModule.greater_equal false
Base.@deprecate_binding less_equal SymbolicRegression.ConfigModule.OperatorsModule.less_equal false
Base.@deprecate_binding cond SymbolicRegression.ConfigModule.OperatorsModule.cond false
Base.@deprecate_binding relu SymbolicRegression.ConfigModule.OperatorsModule.relu false
Base.@deprecate_binding logical_or SymbolicRegression.ConfigModule.OperatorsModule.logical_or false
Base.@deprecate_binding logical_and SymbolicRegression.ConfigModule.OperatorsModule.logical_and false
Base.@deprecate_binding gamma SymbolicRegression.ConfigModule.OperatorsModule.gamma false
Base.@deprecate_binding erf SymbolicRegression.ConfigModule.OperatorsModule.erf false
Base.@deprecate_binding erfc SymbolicRegression.ConfigModule.OperatorsModule.erfc false
Base.@deprecate_binding atanh_clip SymbolicRegression.ConfigModule.OperatorsModule.atanh_clip false
Base.@deprecate_binding AbstractExpressionSpec SymbolicRegression.InterfacesModule.ExpressionSpecModule.AbstractExpressionSpec false
Base.@deprecate_binding ExpressionSpec SymbolicRegression.InterfacesModule.ExpressionSpecModule.ExpressionSpec false
Base.@deprecate_binding get_expression_type SymbolicRegression.InterfacesModule.ExpressionSpecModule.get_expression_type false
Base.@deprecate_binding get_expression_options SymbolicRegression.InterfacesModule.ExpressionSpecModule.get_expression_options false
Base.@deprecate_binding get_node_type SymbolicRegression.InterfacesModule.ExpressionSpecModule.get_node_type false
Base.@deprecate_binding init_value SymbolicRegression.InterfacesModule.InterfaceDataTypesModule.init_value false
Base.@deprecate_binding parse_scope SymbolicRegression.InterfacesModule.InterfaceDataTypesModule.parse_scope false
Base.@deprecate_binding sample_value SymbolicRegression.InterfacesModule.InterfaceDataTypesModule.sample_value false
Base.@deprecate_binding mutate_value SymbolicRegression.InterfacesModule.InterfaceDataTypesModule.mutate_value false
Base.@deprecate_binding AbstractPlugin SymbolicRegression.InterfacesModule.PluginModule.AbstractPlugin false
Base.@deprecate_binding MutationEvent SymbolicRegression.InterfacesModule.PluginModule.MutationEvent false
Base.@deprecate_binding init_plugin_state SymbolicRegression.InterfacesModule.PluginModule.init_plugin_state false
Base.@deprecate_binding init_plugin_states SymbolicRegression.InterfacesModule.PluginModule.init_plugin_states false
Base.@deprecate_binding on_search_start! SymbolicRegression.InterfacesModule.PluginModule.on_search_start! false
Base.@deprecate_binding on_search_end! SymbolicRegression.InterfacesModule.PluginModule.on_search_end! false
Base.@deprecate_binding on_generation_end! SymbolicRegression.InterfacesModule.PluginModule.on_generation_end! false
Base.@deprecate_binding on_cycle_end! SymbolicRegression.InterfacesModule.PluginModule.on_cycle_end! false
Base.@deprecate_binding on_mutation_end! SymbolicRegression.InterfacesModule.PluginModule.on_mutation_end! false
Base.@deprecate_binding init_member SymbolicRegression.InterfacesModule.PluginModule.init_member false
Base.@deprecate_binding tournament_cost_multiplier SymbolicRegression.InterfacesModule.PluginModule.tournament_cost_multiplier false
Base.@deprecate_binding mutation_acceptance_multiplier SymbolicRegression.InterfacesModule.PluginModule.mutation_acceptance_multiplier false
Base.@deprecate_binding MutationAcceptanceContext SymbolicRegression.InterfacesModule.PluginModule.MutationAcceptanceContext false
Base.@deprecate_binding fork_plugin_state SymbolicRegression.InterfacesModule.PluginModule.fork_plugin_state false
Base.@deprecate_binding refresh_worker_plugin_state SymbolicRegression.InterfacesModule.PluginModule.refresh_worker_plugin_state false
Base.@deprecate_binding resolve_init_member SymbolicRegression.InterfacesModule.PluginModule.resolve_init_member false
Base.@deprecate_binding MutationStepResult SymbolicRegression.InterfacesModule.PluginModule.MutationStepResult false
Base.@deprecate_binding wrap_mutation_step SymbolicRegression.InterfacesModule.PluginModule.wrap_mutation_step false
Base.@deprecate_binding on_cycle_start! SymbolicRegression.InterfacesModule.PluginModule.on_cycle_start! false
Base.@deprecate_binding prepare_mutation_context SymbolicRegression.InterfacesModule.PluginModule.prepare_mutation_context false
Base.@deprecate_binding condition_mutation! SymbolicRegression.InterfacesModule.PluginModule.condition_mutation! false
Base.@deprecate_binding plugin_mutations SymbolicRegression.InterfacesModule.PluginModule.plugin_mutations false
Base.@deprecate_binding plugin_crossovers SymbolicRegression.InterfacesModule.PluginModule.plugin_crossovers false
Base.@deprecate_binding default_adaptive_parsimony_plugin SymbolicRegression.ConfigModule.PluginDefaultsModule.default_adaptive_parsimony_plugin false
Base.@deprecate_binding default_simulated_annealing_plugin SymbolicRegression.ConfigModule.PluginDefaultsModule.default_simulated_annealing_plugin false
Base.@deprecate_binding default_adaptive_mutation_weights_plugin SymbolicRegression.ConfigModule.PluginDefaultsModule.default_adaptive_mutation_weights_plugin false
Base.@deprecate_binding _merge_with_default_plugins SymbolicRegression.ConfigModule.PluginDefaultsModule._merge_with_default_plugins false

end

Base.@deprecate_binding CoreModule LegacyCoreModule false
Base.@deprecate_binding InterfaceDynamicQuantitiesModule InterfacesModule.InterfaceDynamicQuantitiesModule false
Base.@deprecate_binding InterfaceDynamicExpressionsModule ExpressionsModule.InterfaceDynamicExpressionsModule false
Base.@deprecate_binding ExpressionBuilderModule ExpressionsModule.ExpressionBuilderModule false
Base.@deprecate_binding ComposableExpressionModule ExpressionsModule.ComposableExpressionModule false
Base.@deprecate_binding TemplateExpressionModule ExpressionsModule.TemplateExpressionModule false
Base.@deprecate_binding TemplateExpressionMacroModule ExpressionsModule.TemplateExpressionMacroModule false
Base.@deprecate_binding ComplexityModule EvaluationModule.ComplexityModule false
Base.@deprecate_binding DimensionalAnalysisModule EvaluationModule.DimensionalAnalysisModule false
Base.@deprecate_binding CheckConstraintsModule EvaluationModule.CheckConstraintsModule false
Base.@deprecate_binding InverseFunctionsModule EvaluationModule.InverseFunctionsModule false
Base.@deprecate_binding EvaluateInverseModule EvaluationModule.EvaluateInverseModule false
Base.@deprecate_binding LossFunctionsModule EvaluationModule.LossFunctionsModule false
Base.@deprecate_binding BacksolveModule EvolutionModule.BacksolveModule false
Base.@deprecate_binding MutationFunctionsModule EvolutionModule.MutationFunctionsModule false
Base.@deprecate_binding PopMemberModule EvolutionModule.PopMemberModule false
Base.@deprecate_binding ConstantOptimizationModule EvolutionModule.ConstantOptimizationModule false
Base.@deprecate_binding PopulationModule EvolutionModule.PopulationModule false
Base.@deprecate_binding HallOfFameModule EvolutionModule.HallOfFameModule false
Base.@deprecate_binding TracingModule EvolutionModule.TracingModule false
Base.@deprecate_binding MutateModule EvolutionModule.MutateModule false
Base.@deprecate_binding CrossoverModule EvolutionModule.CrossoverModule false
Base.@deprecate_binding RegularizedEvolutionModule EvolutionModule.RegularizedEvolutionModule false
Base.@deprecate_binding SingleIterationModule EvolutionModule.SingleIterationModule false
Base.@deprecate_binding MigrationModule EvolutionModule.MigrationModule false
Base.@deprecate_binding ProgressBarsModule SearchModule.ProgressBarsModule false
Base.@deprecate_binding SearchUtilsModule SearchModule.SearchUtilsModule false
Base.@deprecate_binding LoggingModule SearchModule.LoggingModule false
Base.@deprecate_binding AdaptiveParsimonyModule PluginsModule.AdaptiveParsimonyModule false
Base.@deprecate_binding AdaptiveMutationWeightsModule PluginsModule.AdaptiveMutationWeightsModule false
Base.@deprecate_binding MutationBurstModule PluginsModule.MutationBurstModule false
Base.@deprecate_binding SimulatedAnnealingModule PluginsModule.SimulatedAnnealingModule false

@eval InterfacesModule.PluginModule begin
    using ...ConfigModule: PluginDefaultsModule
    Base.@deprecate_binding default_adaptive_parsimony_plugin PluginDefaultsModule.default_adaptive_parsimony_plugin false
    Base.@deprecate_binding default_simulated_annealing_plugin PluginDefaultsModule.default_simulated_annealing_plugin false
    Base.@deprecate_binding default_adaptive_mutation_weights_plugin PluginDefaultsModule.default_adaptive_mutation_weights_plugin false
    Base.@deprecate_binding _merge_with_default_plugins PluginDefaultsModule._merge_with_default_plugins false
end

@eval ExpressionsModule.ExpressionBuilderModule begin
    using ...EvolutionModule:
        PopMemberModule, PopulationModule, HallOfFameModule, ExpressionMetadataModule
    Base.@deprecate_binding Fix ExpressionMetadataModule.Fix false
    using ...EvaluationModule: ComplexityModule
    Base.@deprecate_binding HallOfFame HallOfFameModule.HallOfFame false
    Base.@deprecate_binding Population PopulationModule.Population false
    Base.@deprecate_binding PopMember PopMemberModule.PopMember false
    Base.@deprecate_binding AbstractPopMember PopMemberModule.AbstractPopMember false
    Base.@deprecate_binding create_child PopMemberModule.create_child false
    Base.@deprecate_binding compute_complexity ComplexityModule.compute_complexity false
end

@eval ExpressionsModule.TemplateExpressionModule begin
    using ...EvolutionModule:
        ConstantOptimizationModule,
        MutationFunctionsModule,
        HallOfFameModule,
        MutateModule,
        PopMemberModule,
        TemplateExpressionEvolutionModule
    using ...EvaluationModule:
        DimensionalAnalysisModule,
        CheckConstraintsModule,
        ComplexityModule,
        LossFunctionsModule,
        TemplateExpressionEvaluationModule
    using ...SymbolicRegression: LegacyCoreModule
    Base.@deprecate_binding CM LegacyCoreModule false
    Base.@deprecate_binding CO ConstantOptimizationModule false
    Base.@deprecate_binding MF MutationFunctionsModule false
    Base.@deprecate_binding HOF HallOfFameModule false
    Base.@deprecate_binding DA DimensionalAnalysisModule false
    Base.@deprecate_binding CC CheckConstraintsModule false
    Base.@deprecate_binding LF LossFunctionsModule false
    Base.@deprecate_binding MM MutateModule false
    Base.@deprecate_binding StatsBase TemplateExpressionEvolutionModule.StatsBase false
    Base.@deprecate_binding DATA_TYPE TemplateExpressionEvolutionModule.DATA_TYPE false
    Base.@deprecate_binding ConstantMutation TemplateExpressionEvolutionModule.ConstantMutation false
    Base.@deprecate_binding preserve_sharing TemplateExpressionEvolutionModule.preserve_sharing false
    Base.@deprecate_binding has_units TemplateExpressionEvaluationModule.has_units false
    Base.@deprecate_binding PopMember PopMemberModule.PopMember false
    Base.@deprecate_binding AbstractPopMember PopMemberModule.AbstractPopMember false
    Base.@deprecate_binding _crossover_template_inners TemplateExpressionEvolutionModule._crossover_template_inners false
    Base.@deprecate_binding _template_crossover_child TemplateExpressionEvolutionModule._template_crossover_child false
end

@eval ExpressionsModule.ComposableExpressionModule begin
    using ...EvolutionModule: ConstantOptimizationModule
    Base.@deprecate_binding CO ConstantOptimizationModule false
end

using Base: @deprecate

import .EvaluationModule.LossFunctionsModule: score_func
import .EvolutionModule.HallOfFameModule: calculate_pareto_frontier
import .EvolutionModule.MutationFunctionsModule: gen_random_tree, gen_random_tree_fixed_size
import .EvolutionModule.PopulationModule: best_of_sample
using .PluginsModule.AdaptiveParsimonyModule:
    AdaptiveParsimonyPlugin, AdaptiveParsimonyState, RunningSearchStatistics

Base.@deprecate_binding EvalOptions EvalContext

@deprecate(
    best_of_sample(
        pop::Population,
        running_search_statistics::RunningSearchStatistics,
        options::AbstractOptions,
    ),
    best_of_sample(
        pop,
        options;
        plugin_states=map(options.plugins) do plugin
            if plugin isa AdaptiveParsimonyPlugin  # COV_EXCL_LINE
                AdaptiveParsimonyState(running_search_statistics)  # COV_EXCL_LINE
            else
                nothing  # COV_EXCL_LINE
            end
        end,
    ),
)

@deprecate(
    score_func(
        dataset::Dataset{T,L},
        member,
        options::AbstractOptions;
        complexity::Union{Int,Nothing}=nothing,
    ) where {T<:DATA_TYPE,L<:LOSS_TYPE},
    eval_cost(dataset, member, options; complexity),
)
@deprecate(
    calculate_pareto_frontier(X, y, hallOfFame, options; weights=nothing),
    calculate_pareto_frontier(hallOfFame)
)
@deprecate(
    calculate_pareto_frontier(dataset, hallOfFame, options),
    calculate_pareto_frontier(hallOfFame)
)

@deprecate(
    EquationSearch(X::AbstractMatrix{T1}, y::AbstractMatrix{T2}; kw...) where {T1,T2},
    equation_search(X, y; kw...)
)

@deprecate(
    EquationSearch(X::AbstractMatrix{T1}, y::AbstractVector{T2}; kw...) where {T1,T2},
    equation_search(X, y; kw...)
)

@deprecate(EquationSearch(dataset::Dataset; kws...), equation_search(dataset; kws...),)

@deprecate(
    EquationSearch(
        X::AbstractMatrix{T},
        y::AbstractMatrix{T};
        niterations::Int=10,
        weights::Union{AbstractMatrix{T},AbstractVector{T},Nothing}=nothing,
        variable_names::Union{Vector{String},Nothing}=nothing,
        options::AbstractOptions=Options(),
        parallelism=:multithreading,
        numprocs::Union{Int,Nothing}=nothing,
        procs::Union{Vector{Int},Nothing}=nothing,
        addprocs_function::Union{Function,Nothing}=nothing,
        runtests::Bool=true,
        saved_state=nothing,
        loss_type::Type=Nothing,
        # Deprecated:
        multithreaded=nothing,
    ) where {T<:DATA_TYPE},
    equation_search(
        X,
        y;
        niterations,
        weights,
        variable_names,
        options,
        parallelism,
        numprocs,
        procs,
        addprocs_function,
        runtests,
        saved_state,
        loss_type,
        multithreaded,
    )
)

@deprecate(
    EquationSearch(
        datasets::Vector{D};
        niterations::Int=10,
        options::AbstractOptions=Options(),
        parallelism=:multithreading,
        numprocs::Union{Int,Nothing}=nothing,
        procs::Union{Vector{Int},Nothing}=nothing,
        addprocs_function::Union{Function,Nothing}=nothing,
        runtests::Bool=true,
        saved_state=nothing,
    ) where {T<:DATA_TYPE,L<:LOSS_TYPE,D<:Dataset{T,L}},
    equation_search(
        datasets;
        niterations,
        options,
        parallelism,
        numprocs,
        procs,
        addprocs_function,
        runtests,
        saved_state,
    )
)
