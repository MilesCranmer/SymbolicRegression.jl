import DynamicExpressions: Node
using DataStructures
import Base: ==, hash

function ==(n1::Node{T}, n2::Node{T}) where {T}
    n1.degree == n2.degree || return false
    n1.val == n2.val || return false
    if n1.degree >= 1
        n1.op == n2.op || return false
        n1.l == n2.l || return false
    end
    if n1.degree == 2
        n1.r == n2.r || return false
    end
    return true
end

function hash(n::Node{T}, h::UInt) where {T}
    h = hash(n.degree, h)
    h = hash(n.val, h)
    if n.degree >= 1
        h = hash(n.op, h)
        h = hash(n.l, h)
    end
    if n.degree == 2
        h = hash(n.r, h)
    end
    return h
end

# i want to extract subtrees, but also count each occurrence 
# of each subtree in the tree
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
#function to keep track of every occurrence 
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


unaops = ["-", "sin", "cos", "sqrt", "square"]
binops = ["+", "-", "*", "/"]

operators = (unaops=unaops, binops=binops)
# Create the equation ((x1 + 2) * (x2 - 3)) / x3
x1 = Node(feature=1)
y1 = Node(feature=2)
x2 = Node(feature=3)
y2 = Node(feature=4)

# (x2-x1)
x_diff = Node(1, x2, x1)

# (y2-y1)
y_diff = Node(1, y2, x1)

# (x2-x1)^2
x_diff_sq = Node(4, x_diff)

# (y2-y1)^2
y_diff_sq = Node(4, y_diff)

# (x2-x1)^2 + (y2-y1)^2
sum_sq = Node(1, x_diff_sq, y_diff_sq)

# sqrt((x2-x1)^2 + (y2-y1)^2)
sqrt_sum_sq = Node(3, sum_sq)

# 1/sqrt((x2-x1)^2 + (y2-y1)^2)
inv_sqrt_sum_sq = Node(3, Node(val=1), sqrt_sum_sq)

#print(inv_sqrt_sum_sq)
# Extract sub-trees
subtrees= extract_subtrees(inv_sqrt_sum_sq);
print(typeof(subtrees))
#counting = count_subtrees(subtrees)

#subtrees2 = extract_subtrees_frequency(inv_sqrt_sum_sq, operators)
# Print sub-trees and their counts

#println("keys",subtrees2)
#println("values",subtrees.values)
for (i, subtree) in enumerate(keys(subtrees))

    println("Sub-tree $i: $(to_expression(subtree, operators)), count: $(subtrees[subtree])")
end

