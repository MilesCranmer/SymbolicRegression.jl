module SeedExpressionsModule

using DynamicExpressions: parse_expression, AbstractExpression, get_scalar_constants, set_scalar_constants!
using ..CoreModule: AbstractOptions, Dataset, DATA_TYPE, LOSS_TYPE
using ..PopMemberModule: PopMember
using ..ConstantOptimizationModule: optimize_constants
using ..HallOfFameModule: HallOfFame
using ..SearchUtilsModule: update_hall_of_fame!
using ..LossFunctionsModule: eval_cost
using ..ComplexityModule: compute_complexity
using ..ExpressionBuilderModule: create_expression

"""
    process_seed_expressions!(
        hall_of_fame::HallOfFame{T,L,N},
        dataset::Dataset{T,L},
        options::AbstractOptions
    ) where {T<:DATA_TYPE,L<:LOSS_TYPE,N<:AbstractExpression{T}}

Process user-provided seed expressions by parsing them from strings, optimizing their constants,
and adding them to the hall of fame.

# Arguments
- `hall_of_fame`: The hall of fame to add seed expressions to
- `dataset`: The dataset to evaluate expressions on
- `options`: Options containing the seed expressions and other parameters

# Returns
Nothing, but modifies the hall of fame in-place.
"""
function process_seed_expressions!(
    hall_of_fame::HallOfFame{T,L,N},
    dataset::Dataset{T,L},
    options::AbstractOptions
) where {T<:DATA_TYPE,L<:LOSS_TYPE,N<:AbstractExpression{T}}
    if options.seed_expressions === nothing || isempty(options.seed_expressions)
        return nothing
    end
    
    if options.verbosity !== nothing && options.verbosity > 0
        println("Processing $(length(options.seed_expressions)) seed expressions...")
    end
    
    successful_seeds = 0
    
    for (i, expr_string) in enumerate(options.seed_expressions)
        try
            # Parse the string expression
            parsed_expr = parse_expression(
                expr_string;
                operators=options.operators,
                variable_names=dataset.variable_names,
                expression_type=options.expression_type,
                node_type=options.node_type
            )
            
            # Create a proper expression for this codebase
            expression = create_expression(parsed_expr, options, dataset)
            
            # Create a PopMember for optimization
            member = PopMember(
                dataset,
                expression,
                options;
                deterministic=options.deterministic
            )
            
            # Optimize constants if the expression has any
            if options.should_optimize_constants
                optimized_member, _ = optimize_constants(dataset, member, options)
                member = optimized_member
            end
            
            # Add to hall of fame
            update_hall_of_fame!(hall_of_fame, [member], options)
            
            successful_seeds += 1
            
            if options.verbosity !== nothing && options.verbosity > 1
                complexity = compute_complexity(member, options)
                println("  Seed $(i): $(expr_string) (complexity: $(complexity), loss: $(member.loss))")
            end
            
        catch e
            if options.verbosity !== nothing && options.verbosity > 0
                @warn "Failed to process seed expression $(i): \"$(expr_string)\"" exception=(e, catch_backtrace())
            end
        end
    end
    
    if options.verbosity !== nothing && options.verbosity > 0
        println("Successfully processed $(successful_seeds)/$(length(options.seed_expressions)) seed expressions")
    end
    
    return nothing
end

end