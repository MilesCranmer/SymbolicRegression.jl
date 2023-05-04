module Subtree_module

using SymbolicUtils
using SymbolicRegression
using DataStructures

export calculate_pareto_frontiers
export extract_subtrees_from_dominating
export count_subtrees
export extract_subtrees

function count_subtrees(subtrees::Vector{Node{T}}, subtrees2=Dict{Node{T},Int}()) where {T}
    for tree in subtrees
        if !haskey(subtrees2, tree)
            # Add the current tree to the collection of subtrees
            subtrees2[tree] = 1
        else 
            subtrees2[tree] += 1
        end
    end
    return subtrees2
end

function extract_subtrees(tree::Node{T}, subtrees=IdDict{Node{T}, Int}()) where {T}
    if !haskey(subtrees, tree)
        # Add the current tree to the collection of subtrees
        subtrees[tree] = 1


        # Recursively extract subtrees from children
        if tree.degree >= 1
            extract_subtrees(tree.l, subtrees)
        end
        if tree.degree == 2
            extract_subtrees(tree.r, subtrees)
        end
    else
        subtrees[tree] += 1
    
    end

    return subtrees #,counts
end

function to_expression(tree::Node{T}, operators) where {T}
    if tree.degree == 0
        if tree.constant
            return string(tree.val)
        else
            return "x$(tree.feature)"
        end
    elseif tree.degree == 1
        op = operators.unaops[tree.op]  # Add 1 to handle 1-based indices
        arg = to_expression(tree.l, operators)
        return "($op($arg))"
    else
        op = operators.binops[tree.op]  # Add 1 to handle 1-based indices
        left = to_expression(tree.l, operators)
        right = to_expression(tree.r, operators)
        return "($left $op $right)"
    end
end


function calculate_pareto_frontiers_1(QBC_module, hofs...)
    dominating_frontiers = []
    for hof in hofs
        push!(dominating_frontiers, calculate_pareto_frontier(QBC_module.new_X1, QBC_module.new_y1, hof[2], QBC_module.options))
    end
    return dominating_frontiers
end

function calculate_pareto_frontiers_2(QBC_module, hofs...)
    dominating_frontiers = []
    for hof in hofs
        push!(dominating_frontiers, calculate_pareto_frontier(QBC_module.new_X1, QBC_module.new_y1, hof[2], QBC_module.options2))
    end
    return dominating_frontiers
end


function extract_subtrees_from_dominating(dominating)
    subtrees = IdDict()
    for node in dominating
        subtrees = extract_subtrees(node.tree, subtrees)
    end
    return subtrees
end

function subtrees_by_generations(subtrees)
    subtrees_by_generation = []
    for generation in subtrees
        push!(subtrees_by_generation, extract_subtrees_from_dominating(generation))
    end
    return subtrees_by_generation
end

function count_subtrees(subtrees, QBC)
    new_subtree_dict = Dict()
    for node in keys(subtrees)
        if 2 < compute_complexity(node, QBC.options) < 6
            symb = node_to_symbolic(node, QBC.options)
            if symb in keys(new_subtree_dict)
                new_subtree_dict[symb] += 1
            else
                new_subtree_dict[symb] = 1
            end
        end
    end
    return new_subtree_dict
end

function count_subtree_by_generations(subtrees_by_generation, QBC)
    subtrees_by_generation_count = []
    for generation in subtrees_by_generation
        push!(subtrees_by_generation_count, count_subtrees(generation, QBC))
    end
    return subtrees_by_generation_count
end
#dominating_frontiers = Subtree_module.calculate_pareto_frontiers(QBC,hof_1,hof_2,hof_3)

#subtrees_by_gen = subtrees_by_generations(dominating_frontiers)
end #module


