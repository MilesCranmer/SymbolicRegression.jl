module LoggingModule

using Base: AbstractLogger
using Logging: with_logger
using DynamicExpressions: string_tree

using ..CoreModule: Options, Dataset
using ..ComplexityModule: compute_complexity
using ..HallOfFameModule: calculate_pareto_frontier
using ..SearchUtilsModule: SearchState, RuntimeOptions

# Defined by Plots extension
function default_sr_plot(args...; kws...)
    return "Load the Plots package to use this function."
end

function default_logging_callback(
    logger::AbstractLogger;
    log_step::Integer,
    state::SearchState,
    datasets::AbstractVector{<:Dataset{T,L}},
    ropt::RuntimeOptions,
    options::Options,
) where {T,L}
    data = let d = Dict{String,Union{Dict{String,Any},Float64}}()
        for i in eachindex(datasets, state.halls_of_fame)
            dominating = calculate_pareto_frontier(state.halls_of_fame[i])
            best_loss = length(dominating) > 0 ? dominating[end].loss : L(Inf)
            trees = [member.tree for member in dominating]
            losses = L[member.loss for member in dominating]
            complexities = Int[compute_complexity(member, options) for member in dominating]
            equations = String[
                string_tree(
                    member.tree, options; variable_names=datasets[i].variable_names
                ) for member in dominating
            ]
            is = string(i)
            d[is] = Dict{String,Any}()
            d[is]["best_loss"] = best_loss
            d[is]["equations"] = Dict([
                string(complexities[i_eqn]) =>
                    Dict("loss" => losses[i_eqn], "equation" => equations[i_eqn]) for
                i_eqn in eachindex(complexities, losses, equations)
            ])
            if ropt.log_every_n.plots > 0 && log_step % ropt.log_every_n.plots == 0
                d[is]["plot"] = default_sr_plot(
                    trees,
                    losses,
                    complexities,
                    options;
                    variable_names=datasets[i].variable_names,
                )
            end
        end
        d["num_evals"] = sum(sum, state.num_evals)
        d
    end
    with_logger(logger) do
        @info("search_state", data = data)
    end
end

end
