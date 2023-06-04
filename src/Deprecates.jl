using Base: @deprecate

@deprecate calculate_pareto_frontier(
    X, y, hallOfFame, options; weights=nothing, varMap=nothing
) calculate_pareto_frontier(hallOfFame)
@deprecate calculate_pareto_frontier(dataset, hallOfFame, options) calculate_pareto_frontier(
    hallOfFame
)

function deprecate_varmap(variable_names, varMap, func_name)
    if varMap !== nothing
        Base.depwarn("`varMap` is deprecated; use `variable_names` instead", func_name)
        @assert variable_names === nothing "Cannot pass both `varMap` and `variable_names`"
        variable_names = varMap
    end
    return variable_names
end
