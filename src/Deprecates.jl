using Base: @deprecate

@deprecate calculate_pareto_frontier(
    X, y, hallOfFame, options; weights=nothing, varMap=nothing
) calculate_pareto_frontier(hallOfFame)
@deprecate calculate_pareto_frontier(dataset, hallOfFame, options) calculate_pareto_frontier(
    hallOfFame
)
