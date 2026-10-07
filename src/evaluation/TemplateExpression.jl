module TemplateExpressionEvaluationModule

using DynamicExpressions: get_contents
using ...InterfacesModule: AbstractOptions, Dataset, has_units
using ...ExpressionsModule: TemplateExpression
using ...ExpressionsModule.TemplateExpressionModule: has_invalid_variables
using ..ComplexityModule: ComplexityModule
using ..DimensionalAnalysisModule: DimensionalAnalysisModule as DA
using ..CheckConstraintsModule: CheckConstraintsModule as CC

function ComplexityModule.compute_complexity(
    tree::TemplateExpression, options::AbstractOptions; break_sharing=Val(false)
)
    # Rather than including the complexity of the combined tree,
    # we only sum the complexity of each inner expression, which will be smaller.
    return sum(
        ex -> ComplexityModule.compute_complexity(ex, options; break_sharing),
        values(get_contents(tree)),
    )
end

function DA.violates_dimensional_constraints(
    @nospecialize(tree::TemplateExpression),
    dataset::Dataset,
    @nospecialize(options::AbstractOptions)
)
    @assert !has_units(dataset)
    return false
end

function CC.check_constraints(
    ex::TemplateExpression,
    options::AbstractOptions,
    maxsize::Int,
    cursize::Union{Int,Nothing}=nothing,
)::Bool
    # First, we check the variable constraints at the top level:
    if has_invalid_variables(ex)
        return false
    end

    # We also check the combined complexity:
    @something(cursize, ComplexityModule.compute_complexity(ex, options)) > maxsize &&
        return false

    # Then, we check other constraints for inner expressions:
    raw_contents = get_contents(ex)
    for t in values(raw_contents)
        if !CC.check_constraints(t, options, maxsize, nothing)
            return false
        end
    end
    return true
    # TODO: The concept of `cursize` doesn't really make sense here.
end

end
