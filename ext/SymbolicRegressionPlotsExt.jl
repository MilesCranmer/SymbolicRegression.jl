module SymbolicRegressionPlotsExt

import Plots: plot
import SymbolicRegression: default_sr_plot

using DynamicExpressions: Node
using SymbolicRegression: HallOfFame, Options, string_tree
using SymbolicRegression.HallOfFameModule: format_hall_of_fame

function plot(hall_of_fame::HallOfFame, options::Options; variable_names=nothing, kws...)
    return default_sr_plot(hall_of_fame, options; variable_names, kws...)
end

function default_sr_plot(hall_of_fame::HallOfFame, options::Options; variable_names=nothing, kws...)
    (; trees, losses, complexities) = format_hall_of_fame(hall_of_fame, options)
    return default_sr_plot(trees, losses, complexities, options; variable_names, kws...)
end

function default_sr_plot(
    trees::Vector{N},
    losses::Vector{L},
    complexities::Vector{Int},
    options::Options;
    variable_names=nothing,
    kws...,
) where {T,L,N<:Node{T}}
    tree_strings = [string_tree(tree, options; variable_names) for tree in trees]
    return plot(
        complexities,
        losses;
        label=nothing,
        xlabel="Complexity",
        ylabel="Loss",
        title="Hall of Fame",
        xlims=(0, options.maxsize),
        yscale=:log10,
        kws...,
    )
end

end
