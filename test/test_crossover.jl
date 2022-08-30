println("Testing crossover function.")
using SymbolicRegression
using Test
using SymbolicRegression: crossover_trees
include("test_params.jl")

options = SymbolicRegression.Options(;
    default_params...,
    binary_operators=(+, *, /, -),
    unary_operators=(cos, exp),
    npopulations=8,
)
tree1 = cos(Node("x1")) + (3.0f0 + Node("x2"))
tree2 = exp(Node("x1") - Node("x2") * Node("x2")) + 10.0f0 * Node("x3")

# See if we can observe operators flipping sides:
cos_flip_to_tree2 = false
exp_flip_to_tree1 = false
swapped_cos_with_exp = false
for i in 1:1000
    child_tree1, child_tree2 = crossover_trees(tree1, tree2)
    if occursin("cos", repr(child_tree2))
        # Moved cosine to tree2
        global cos_flip_to_tree2 = true
    end
    if occursin("exp", repr(child_tree1))
        # Moved exp to tree1
        global exp_flip_to_tree1 = true
    end
    if occursin("cos", repr(child_tree2)) && occursin("exp", repr(child_tree1))
        global swapped_cos_with_exp = true
        # Moved exp with cos
        @assert !occursin("cos", repr(child_tree1))
        @assert !occursin("exp", repr(child_tree2))
    end

    # Check that exact same operators, variables, numbers before and after:
    rep_tree_final = sort([a for a in repr(child_tree1) * repr(child_tree2)])
    rep_tree_final = strip(String(rep_tree_final), ['(', ')', ' '])
    rep_tree_initial = sort([a for a in repr(tree1) * repr(tree2)])
    rep_tree_initial = strip(String(rep_tree_initial), ['(', ')', ' '])
    @test rep_tree_final == rep_tree_initial
end

@test cos_flip_to_tree2
@test exp_flip_to_tree1
@test swapped_cos_with_exp
println("Passed.")
