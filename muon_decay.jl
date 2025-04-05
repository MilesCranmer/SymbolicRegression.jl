using Pkg
Pkg.activate(".")
using SymbolicRegression
using CSV
using DataFrames
using Random
using Plots
gr()

df_m0 = CSV.read("./transfer/marginal_data_0.npy", DataFrame)
df_m1 = CSV.read("./transfer/marginal_data_1.npy", DataFrame)
x1 = df_m0[:,1]
y1 = df_m0[:,2]
x2 = df_m1[:,1]
y2 = df_m1[:,2]
p1 = plot(x1, y1, seriestype=:scatter, title="Scatter plot of data x0", xlabel="X-axis", ylabel="Y-axis")
p2 = plot(x2, y2, seriestype=:scatter, title="Scatter plot of data x1", xlabel="X-axis", ylabel="Y-axis")
display(p1)
display(p2)

pow2(x) = x^2
pow3(x) = x^3
pow4(x) = x^4
pow5(x) = x^5
#region Low level API
options = SymbolicRegression.Options(;
    binary_operators=[+, *, /, -], unary_operators=[exp, pow2, pow3, pow4, pow5]
)

hall_of_fame_x1m = equation_search(
        reshape(collect(x1), 1, :), y1; options=options, parallelism=:serial, niterations=10
    )

hall_of_fame_x2m = equation_search(
        reshape(collect(x2), 1, :), y2; options=options, parallelism=:serial, niterations=10
    )
   
dominating_x1m = calculate_pareto_frontier(hall_of_fame_x1m)
trees_x1m = [member.tree for member in dominating_x1m]

dominating_x2m = calculate_pareto_frontier(hall_of_fame_x2m)
trees_x2m = [member.tree for member in dominating_x2m]

function update_feature!(node::Node)
    # Only update leaf (degree==0) feature nodes (non-constant)
    if node.degree == 0 && !node.constant
        if node.feature == 1
            node.feature = 2
        end
    elseif node.degree >= 1
        # Recursively update children: left child is always defined;
        update_feature!(node.l)
        # Right child is defined only for binary operators (degree==2)
        if node.degree == 2
            update_feature!(node.r)
        end
    end
    return node
end

for i in eachindex(trees_x2m)
    update_feature!(trees_x2m[i].tree)
end

