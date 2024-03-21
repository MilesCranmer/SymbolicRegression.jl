module LoggingModule

using Base: AbstractLogger
using Logging: with_logger
using DynamicExpressions: string_tree
using Infiltrator: @infiltrate
using RecipesBase: plot

using ..CoreModule: Options, Dataset
using ..ComplexityModule: compute_complexity
using ..HallOfFameModule: calculate_pareto_frontier
using ..SearchUtilsModule: SearchState, RuntimeOptions

function default_logging_callback(
    logger::AbstractLogger;
    log_step::Integer,
    state::SearchState,
    datasets::AbstractVector{<:Dataset{T,L}},
    ropt::RuntimeOptions,
    options::Options,
) where {T,L}
    nout = length(datasets)
    data = let d = Ref(Dict{String,Any}())
        for i in eachindex(datasets, state.halls_of_fame)
            cur_out = Dict{String,Any}()

            #### Population diagnostics
            cur_out["population"] = Dict([
                "complexities" => let
                    complexities = Int[]
                    for pop in state.last_pops[i], member in pop.members
                        push!(complexities, compute_complexity(member, options))
                    end
                    complexities
                end,
            ])

            #### Summaries
            dominating = calculate_pareto_frontier(state.halls_of_fame[i])
            trees = [member.tree for member in dominating]
            losses = L[member.loss for member in dominating]
            complexities = Int[compute_complexity(member, options) for member in dominating]

            cur_out["min_loss"] = length(dominating) > 0 ? dominating[end].loss : L(Inf)
            # @infiltrate
            cur_out["pareto_volume"] = if length(dominating) > 1
                log_losses = @. log10(losses + eps(L))
                log_complexities = @. log10(complexities)

                # Add a point equal to the best loss and largest possible complexity, + 1
                push!(log_losses, minimum(log_losses))
                push!(log_complexities, log10(options.maxsize + 1))

                # Add a point to connect things:
                push!(log_losses, maximum(log_losses))
                push!(log_complexities, maximum(log_complexities))

                xy = cat(log_complexities, log_losses; dims=2)
                hull = convex_hull(xy)
                convex_hull_area(hull)
            else
                0.0
            end

            #### Full Pareto front
            cur_out["equations"] = let
                equations = String[
                    string_tree(
                        member.tree,
                        options;
                        variable_names=datasets[i].variable_names,
                    ) for member in dominating
                ]
                Dict([
                    "complexity=" * string(complexities[i_eqn]) => Dict(
                        "loss" => losses[i_eqn], "equation" => equations[i_eqn]
                    ) for i_eqn in eachindex(complexities, losses, equations)
                ])
            end
            cur_out["plot"] =
                if ropt.log_every_n.plots > 0 && log_step % ropt.log_every_n.plots == 0
                    plot(
                        trees,
                        losses,
                        complexities,
                        options;
                        variable_names=datasets[i].variable_names,
                    )
                else
                    nothing
                end

            if nout == 1
                d[] = cur_out
            else
                d[]["out_$(i)"] = cur_out
            end
        end
        d[]["num_evals"] = sum(sum, state.num_evals)
        d[]
    end
    with_logger(logger) do
        @info("search", data = data)
    end
end

"""Uses gift wrapping algorithm to create a convex hull."""
function convex_hull(xy)
    cur_point = xy[sortperm(xy[:, 1])[1], :]
    hull = typeof(cur_point)[]
    while true
        push!(hull, cur_point)
        end_point = xy[1, :]
        for candidate_point in eachrow(xy)
            if end_point == cur_point || isleftof(candidate_point, (cur_point, end_point))
                end_point = candidate_point
            end
        end
        cur_point = end_point
        if end_point == hull[1]
            break
        end
    end
    return hull
end

function isleftof(point, line)
    (start_point, end_point) = line
    return (end_point[1] - start_point[1]) * (point[2] - start_point[2]) -
           (end_point[2] - start_point[2]) * (point[1] - start_point[1]) > 0
end

"""Computes the area within a convex hull."""
function convex_hull_area(hull)
    area = 0.0
    for i in eachindex(hull)
        j = i == lastindex(hull) ? firstindex(hull) : nextind(hull, i)
        area += (hull[i][1] * hull[j][2] - hull[j][1] * hull[i][2])
    end
    return abs(area) / 2
end

end
