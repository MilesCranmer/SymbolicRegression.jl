using Pkg
Pkg.activate(".")
using SymbolicRegression
using CSV
using DataFrames
using Random
using Plots
gr()

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

df_m1 = CSV.read("./transfer/marginal_data_0.npy", DataFrame, header=false)
df_m2 = CSV.read("./transfer/marginal_data_1.npy", DataFrame, header=false)
df_c1_slices = CSV.read("./transfer/conditional_slices_0.npy", DataFrame, header=false)
df_c2_slices = CSV.read("./transfer/conditional_slices_1.npy", DataFrame, header=false)
df_c1_data_slice_1 = CSV.read("./transfer/conditional_data_0_slice_0.npy", DataFrame, header=false)
df_c1_data_slice_2 = CSV.read("./transfer/conditional_data_0_slice_1.npy", DataFrame, header=false)
df_c1_data_slice_3 = CSV.read("./transfer/conditional_data_0_slice_2.npy", DataFrame, header=false)
df_c1_data_slice_4 = CSV.read("./transfer/conditional_data_0_slice_3.npy", DataFrame, header=false)
df_c1_data_slice_5 = CSV.read("./transfer/conditional_data_0_slice_4.npy", DataFrame, header=false)
df_c1_data_slice_6 = CSV.read("./transfer/conditional_data_0_slice_5.npy", DataFrame, header=false)
df_c1_data_slice_7 = CSV.read("./transfer/conditional_data_0_slice_6.npy", DataFrame, header=false)
df_c1_data_slice_8 = CSV.read("./transfer/conditional_data_0_slice_7.npy", DataFrame, header=false)
df_c2_data_slice_1 = CSV.read("./transfer/conditional_data_1_slice_0.npy", DataFrame, header=false)
df_c2_data_slice_2 = CSV.read("./transfer/conditional_data_1_slice_1.npy", DataFrame, header=false)
df_c2_data_slice_3 = CSV.read("./transfer/conditional_data_1_slice_2.npy", DataFrame, header=false)
df_c2_data_slice_4 = CSV.read("./transfer/conditional_data_1_slice_3.npy", DataFrame, header=false)
df_c2_data_slice_5 = CSV.read("./transfer/conditional_data_1_slice_4.npy", DataFrame, header=false)
df_c2_data_slice_6 = CSV.read("./transfer/conditional_data_1_slice_5.npy", DataFrame, header=false)
df_c2_data_slice_7 = CSV.read("./transfer/conditional_data_1_slice_6.npy", DataFrame, header=false)
df_c2_data_slice_8 = CSV.read("./transfer/conditional_data_1_slice_7.npy", DataFrame, header=false)

m_x1 = df_m1[:,1]
m_y1 = df_m1[:,2]
m_x2 = df_m2[:,1]
m_y2 = df_m2[:,2]

c1_x1_slice_info = df_c1_slices[1,1]; c1_y1_slice_info = df_c1_slices[1,2]
c2_x1_slice_info = df_c1_slices[2,1]; c2_y1_slice_info = df_c1_slices[2,2]
c3_x1_slice_info = df_c1_slices[3,1]; c3_y1_slice_info = df_c1_slices[3,2]
c4_x1_slice_info = df_c1_slices[4,1]; c4_y1_slice_info = df_c1_slices[4,2]
c5_x1_slice_info = df_c1_slices[5,1]; c5_y1_slice_info = df_c1_slices[5,2]
c6_x1_slice_info = df_c1_slices[6,1]; c6_y1_slice_info = df_c1_slices[6,2]
c7_x1_slice_info = df_c1_slices[7,1]; c7_y1_slice_info = df_c1_slices[7,2]
c8_x1_slice_info = df_c1_slices[8,1]; c8_y1_slice_info = df_c1_slices[8,2]

c1_x2_slice_info = df_c2_slices[1,1]; c1_y2_slice_info = df_c2_slices[1,2]
c2_x2_slice_info = df_c2_slices[2,1]; c2_y2_slice_info = df_c2_slices[2,2]
c3_x2_slice_info = df_c2_slices[3,1]; c3_y2_slice_info = df_c2_slices[3,2]
c4_x2_slice_info = df_c2_slices[4,1]; c4_y2_slice_info = df_c2_slices[4,2]
c5_x2_slice_info = df_c2_slices[5,1]; c5_y2_slice_info = df_c2_slices[5,2]
c6_x2_slice_info = df_c2_slices[6,1]; c6_y2_slice_info = df_c2_slices[6,2]
c7_x2_slice_info = df_c2_slices[7,1]; c7_y2_slice_info = df_c2_slices[7,2]
c8_x2_slice_info = df_c2_slices[8,1]; c8_y2_slice_info = df_c2_slices[8,2]

c1_x1 = df_c1_data_slice_1[:,1]; c1_y1 = df_c1_data_slice_1[:,2]
c2_x1 = df_c1_data_slice_2[:,1]; c2_y1 = df_c1_data_slice_2[:,2]
c3_x1 = df_c1_data_slice_3[:,1]; c3_y1 = df_c1_data_slice_3[:,2]
c4_x1 = df_c1_data_slice_4[:,1]; c4_y1 = df_c1_data_slice_4[:,2]
c5_x1 = df_c1_data_slice_5[:,1]; c5_y1 = df_c1_data_slice_5[:,2]
c6_x1 = df_c1_data_slice_6[:,1]; c6_y1 = df_c1_data_slice_6[:,2]
c7_x1 = df_c1_data_slice_7[:,1]; c7_y1 = df_c1_data_slice_7[:,2]
c8_x1 = df_c1_data_slice_8[:,1]; c8_y1 = df_c1_data_slice_8[:,2]

c1_x2 = df_c2_data_slice_1[:,1]; c1_y2 = df_c2_data_slice_1[:,2]
c2_x2 = df_c2_data_slice_2[:,1]; c2_y2 = df_c2_data_slice_2[:,2]
c3_x2 = df_c2_data_slice_3[:,1]; c3_y2 = df_c2_data_slice_3[:,2]
c4_x2 = df_c2_data_slice_4[:,1]; c4_y2 = df_c2_data_slice_4[:,2]
c5_x2 = df_c2_data_slice_5[:,1]; c5_y2 = df_c2_data_slice_5[:,2]
c6_x2 = df_c2_data_slice_6[:,1]; c6_y2 = df_c2_data_slice_6[:,2]
c7_x2 = df_c2_data_slice_7[:,1]; c7_y2 = df_c2_data_slice_7[:,2]
c8_x2 = df_c2_data_slice_8[:,1]; c8_y2 = df_c2_data_slice_8[:,2]

conditional_data_x1 = [[c1_x1], [c2_x1], [c3_x1], [c4_x1], [c5_x1], [c6_x1], [c7_x1], [c8_x1]]
conditional_data_x2 = [[c1_x2], [c2_x2], [c3_x2], [c4_x2], [c5_x2], [c6_x2], [c7_x2], [c8_x2]]
conditional_data_y1 = [[c1_y1], [c2_y1], [c3_y1], [c4_y1], [c5_y1], [c6_y1], [c7_y1], [c8_y1]]
conditional_data_y2 = [[c1_y2], [c2_y2], [c3_y2], [c4_y2], [c5_y2], [c6_y2], [c7_y2], [c8_y2]]

joint_data_x = [c1_x1  repeat([c1_x1_slice_info], length(c1_x1));
                c2_x1 repeat([c2_x1_slice_info], length(c2_x1));
                c3_x1 repeat([c3_x1_slice_info], length(c3_x1));
                c4_x1 repeat([c4_x1_slice_info], length(c4_x1));
                c5_x1 repeat([c5_x1_slice_info], length(c5_x1));
                c6_x1 repeat([c6_x1_slice_info], length(c6_x1));
                c7_x1 repeat([c7_x1_slice_info], length(c7_x1));
                c8_x1 repeat([c8_x1_slice_info], length(c8_x1));
                c1_x2 repeat([c1_x2_slice_info], length(c1_x2));
                c2_x2 repeat([c2_x2_slice_info], length(c2_x2));
                c3_x2 repeat([c3_x2_slice_info], length(c3_x2));
                c4_x2 repeat([c4_x2_slice_info], length(c4_x2));
                c5_x2 repeat([c5_x2_slice_info], length(c5_x2));
                c6_x2 repeat([c6_x2_slice_info], length(c6_x2));
                c7_x2 repeat([c7_x2_slice_info], length(c7_x2));
                c8_x2 repeat([c8_x2_slice_info], length(c8_x2))]

joint_data_y = [c1_y1*c1_y1_slice_info;
                c2_y1*c2_y1_slice_info;
                c3_y1*c3_y1_slice_info;
                c4_y1*c4_y1_slice_info;
                c5_y1*c5_y1_slice_info;
                c6_y1*c6_y1_slice_info;
                c7_y1*c7_y1_slice_info;
                c8_y1*c8_y1_slice_info;
                c1_y2*c1_y2_slice_info;
                c2_y2*c2_y2_slice_info;
                c3_y2*c3_y2_slice_info;
                c4_y2*c4_y2_slice_info;
                c5_y2*c5_y2_slice_info;
                c6_y2*c6_y2_slice_info;
                c7_y2*c7_y2_slice_info;
                c8_y2*c8_y2_slice_info]


m_x1_p = plot(m_x1, m_y1, seriestype=:scatter, title="Scatter plot of data x0", xlabel="X-axis", ylabel="Y-axis")
m_x2_p = plot(m_x2, m_y2, seriestype=:scatter, title="Scatter plot of data x1", xlabel="X-axis", ylabel="Y-axis")
display(m_x1_p)
display(m_x2_p)

pow2(x) = x^2
pow3(x) = x^3
pow4(x) = x^4
pow5(x) = x^5

function p2f(x)
    return x^2
end
#region Low level API
options = SymbolicRegression.Options(;
    binary_operators=[+, *, /, -], unary_operators=[exp, pow2, pow3, pow4, pow5]
)

hall_of_fame_m_x1 = equation_search(
        reshape(m_x1, 1, :), m_y1; options=options, parallelism=:serial, niterations=10
    )

hall_of_fame_m_x2 = equation_search(
        reshape(m_x2, 1, :), m_y2; options=options, parallelism=:serial, niterations=10
    )
   
dominating_m_x1 = calculate_pareto_frontier(hall_of_fame_m_x1)
trees_m_x1 = [member.tree for member in dominating_m_x1]

dominating_m_x2 = calculate_pareto_frontier(hall_of_fame_m_x2)
trees_m_x2 = [member.tree for member in dominating_m_x2]


for i in eachindex(hall_of_fame_m_x2.members)
    update_feature!(hall_of_fame_m_x2.members[i].tree.tree)
end

conditional_hall_of_fame_x1 =[]
dominating_c_x1 = []
trees_c_x1 = []
for i in eachindex(conditional_data_x1)
    append!(conditional_hall_of_fame_x1, [equation_search(
        reshape(conditional_data_x1[i][1], 1, :), conditional_data_y1[i][1]; options=options, parallelism=:serial, niterations=10
    )])
    append!(dominating_c_x1, [calculate_pareto_frontier(conditional_hall_of_fame_x1[i])])
    append!(trees_c_x1, [member.tree for member in dominating_c_x1[i]])
end

conditional_hall_of_fame_x2 =[]
dominating_c_x2 = []
trees_c_x2 = []
for i in eachindex(conditional_data_x2)
    append!(conditional_hall_of_fame_x2, [equation_search(
        reshape(conditional_data_x2[i][1], 1, :), conditional_data_y2[i][1]; options=options, parallelism=:serial, niterations=10
    )])
    append!(dominating_c_x2, [calculate_pareto_frontier(conditional_hall_of_fame_x2[i])])
    append!(trees_c_x2, [[member.tree for member in conditional_hall_of_fame_x2[i].members]])
    for j in eachindex(trees_c_x2[i])
        update_feature!(trees_c_x2[i][j].tree)
    end
end

# Multiply marginals and conditionals to obtain PopMember for initialization
# 30*8 = 240 conditionals
# 30 marginals
# 240*30 = 7200
# 7200*2 = 14,400

# How many expressions per population?
# How many populations?
# How to distribute expressions to seed each population?

#Combine conditionals and marginals like this
# conditional_hall_of_fame_x2[1].members[8].tree = conditional_hall_of_fame_x1[1].members[8].tree * hall_of_fame_m_x2.members[7].tree

# Cross validation with KDE for the full pipeline