module EvolutionModule

include("Backsolve.jl")
include("MutationFunctions.jl")
include("PopMember.jl")
include("ConstantOptimization.jl")
include("Population.jl")
include("HallOfFame.jl")
include("Tracing.jl")
include("Mutate.jl")
include("Crossover.jl")
include("RegularizedEvolution.jl")
include("SingleIteration.jl")
include("Migration.jl")
include("ExpressionMetadata.jl")
include("ComposableExpression.jl")
include("TemplateExpression.jl")

using .MutationFunctionsModule:
    gen_random_tree, gen_random_tree_fixed_size, random_node, crossover_trees
using .ConstantOptimizationModule:
    optimize_constants,
    get_constants_for_optimization,
    set_constants_for_optimization!,
    extract_gradient_for_optimization,
    get_optimizable_parameters,
    set_optimizable_parameters!,
    extract_optimizable_gradient
using .PopMemberModule:
    AbstractPopMember, PopMember, reset_birth!, popmember_type, expression_type
using .PopulationModule: Population, best_sub_pop, best_of_sample
using .HallOfFameModule:
    HallOfFame,
    calculate_pareto_frontier,
    string_dominating_pareto_curve,
    update_hall_of_fame!
using .MutateModule: mutate!, condition_mutation_weights!, MutationResult
using .CrossoverModule: crossover, CrossoverResult
using .SingleIterationModule: s_r_cycle, optimize_and_simplify_population
using .TracingModule:
    initialize_trace!, new_trace, next_trace_iteration, trace_iteration_start!, write_trace
using .MigrationModule: migrate!

end
