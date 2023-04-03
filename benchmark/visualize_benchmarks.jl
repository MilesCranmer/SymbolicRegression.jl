using Statistics
using JSON3
using Plots
using Plots.Measures

names = ARGS

if length(names) == 0
    # Print usage:
    @error "Usage: julia --project=benchmark benchmark/runbenchmarks.jl <rev1> <rev2> ..."
end

function compute_summary_statistics(times)
    return Dict(
        "mean" => mean(times),
        "median" => median(times),
        "std" => std(times),
        "5" => quantile(times, 0.05),
        "25" => quantile(times, 0.25),
        "75" => quantile(times, 0.75),
        "95" => quantile(times, 0.95),
    )
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
    for (key, path) in
        zip(("serial",), (d -> d["data"]["search"]["data"]["serial"]["times"],))
        times = path(raw_data)
        combined_results[name][key] = compute_summary_statistics(times)
    end
end

# Now, we want to create a plot for each key, over the different revisions,
# ordered by the order in which they were passed:
function create_line_plot(data, names, title)
    medians = [d["median"] for d in data]
    lower_errors = [d["median"] - d["25"] for d in data]
    upper_errors = [d["75"] - d["median"] for d in data]
    errors = hcat(lower_errors', upper_errors')
    plot_xticks = 1:length(names)

    p = plot(
        plot_xticks,
        medians;
        yerror=errors,
        linestyle=:solid,
        marker=:circle,
        label="median",
    )
    scatter!(plot_xticks, medians; yerror=errors, label=nothing)
    xticks!(plot_xticks, names)
    title!(title)
    xlabel!("Revisions")
    ylabel!("Value")
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
for key in ["serial"]
    push!(
        plot_search,
        create_line_plot(
            [combined_results[name][key] for name in names], names, "Search - $key"
        ),
    )
end

combined_plots = [plot_eval...; plot_search...]
plot_combined = plot(
    combined_plots...; layout=(4, 1), size=(800, 1000), legend=:best, left_margin=10mm
)

savefig(joinpath(@__DIR__, "benchmark_comparison_plot.png"))
