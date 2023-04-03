using Statistics
using JSON3
using Plots
using Plots.Measures

names = ARGS

if length(names) == 0
    # Print usage:
    @error "Usage: julia --project=benchmark benchmark/visualize_benchmarks.jl <rev1> <rev2> ..."
end

function compute_summary_statistics(times)
    d = Dict("mean" => mean(times), "median" => median(times))
    return d = if length(times) > 1
        merge(
            d,
            Dict(
                "std" => std(times),
                "5" => quantile(times, 0.05),
                "25" => quantile(times, 0.25),
                "75" => quantile(times, 0.75),
                "95" => quantile(times, 0.95),
            ),
        )
    else
        d
    end
end

combined_results = Dict{String,Any}()
for name in names
    filename = joinpath(@__DIR__, "results_$(name).json")
    # Assert file exists:
    isfile(filename) || error("File $(filename) does not exist.")
    raw_data = open(filename) do io
        JSON3.read(io)
    end
    combined_results[name] = Dict{String,Any}()
    for (key, path) in zip(
        ("Float32", "Float64", "BigFloat"),
        (
            d -> d["data"]["evaluation"]["data"]["Float32"]["times"],
            d -> d["data"]["evaluation"]["data"]["Float64"]["times"],
            d -> d["data"]["evaluation"]["data"]["BigFloat"]["times"],
        ),
    )
        times = path(raw_data)
        combined_results[name][key] = compute_summary_statistics(times)
    end
    # search results:
    if "search" in keys(raw_data["data"])
        for (key, path) in zip(
            ("serial", "multithreading"),
            (
                d -> d["data"]["search"]["data"]["serial"]["times"],
                d -> d["data"]["search"]["data"]["multithreading"]["times"],
            ),
        )
            times = path(raw_data)
            combined_results[name][key] = compute_summary_statistics(times)
        end
    end
end

# Now, we want to create a plot for each key, over the different revisions,
# ordered by the order in which they were passed:
function create_line_plot(data, names, title)
    medians = [d["median"] for d in data]

    # Default unit of time is ns. Let's find one of
    # {ns, μs, ms, s} that is most appropriate
    # (i.e., log10(median / unit) should be closest to 0)
    units = [1e9, 1e6, 1e3, 1] ./ 1e9
    units_names = ["ns", "μs", "ms", "s"]
    unit_choice = argmin(abs.(log10.(median(medians) .* units)))
    unit = units[unit_choice]
    unit_name = units_names[unit_choice]

    medians = medians .* unit
    errors = if "75" in keys(first(data))
        lower_errors = [d["median"] - d["25"] for d in data] .* unit
        upper_errors = [d["75"] - d["median"] for d in data] .* unit
        hcat(lower_errors', upper_errors')
    else
        nothing
    end
    plot_xticks = 1:length(names)

    p = plot(plot_xticks, medians; yerror=errors, linestyle=:solid, marker=:circle)
    scatter!(plot_xticks, medians; yerror=errors)
    xticks!(plot_xticks, names)
    title!(title)
    xlabel!("Revisions")
    ylabel!("Value [$unit_name]")
    return p
end

# Creating and saving plots
plot_eval = []
for key in ["Float32", "Float64", "BigFloat"]
    push!(
        plot_eval,
        create_line_plot(
            [combined_results[name][key] for name in names], names, "Evaluation - $key"
        ),
    )
end
plot_search = []
if "serial" in keys(combined_results[first(names)])
    for key in ["serial", "multithreading"]
        push!(
            plot_search,
            create_line_plot(
                [combined_results[name][key] for name in names], names, "Search - $key"
            ),
        )
    end
end

combined_plots = [plot_eval...; plot_search...]
plot_combined = plot(combined_plots...; layout=(5, 1), size=(800, 1250), left_margin=10mm)

savefig(joinpath(@__DIR__, "benchmark_comparison_plot.png"))
