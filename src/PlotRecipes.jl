module PlotRecipesModule

using RecipesBase: @recipe
using DynamicExpressions: Node, string_tree
using ..CoreModule: Options
using ..HallOfFameModule: HallOfFame, format_hall_of_fame
using ..MLJInterfaceModule: SRFitResult, SRRegressor

@recipe function default_sr_plot(fitresult::SRFitResult{<:SRRegressor})
    return fitresult.state[2], fitresult.options
end

# TODO: Add variable names
@recipe function default_sr_plot(hall_of_fame::HallOfFame, options::Options)
    (; trees, losses, complexities) = format_hall_of_fame(hall_of_fame, options)
    return (trees, losses, complexities, options)
end

@recipe function default_sr_plot(
    trees::Vector{N}, losses::Vector{L}, complexities::Vector{Int}, options::Options
) where {T,L,N<:Node{T}}
    tree_strings = [string_tree(tree, options) for tree in trees]

    xlabel --> "Complexity"
    ylabel --> "Loss"

    xlims --> (0.5, options.maxsize + 1)

    xscale --> :log10
    yscale --> :log10

    # Data for plotting:
    return complexities, losses
end

end
