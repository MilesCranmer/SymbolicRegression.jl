module CheckConstraintsModule

using DynamicExpressions:
    AbstractExpressionNode, AbstractExpression, get_tree, count_depth, tree_mapreduce
using ..CoreModule: AbstractOptions
using ..ComplexityModule: compute_complexity, past_complexity_limit

# Check if any binary operator are overly complex
function flag_bin_operator_complexity(
    tree::AbstractExpressionNode, op, cons, options::AbstractOptions
)::Bool
    any(tree) do subtree
        if subtree.degree == 2 && subtree.op == op
            cons[1] > -1 &&
                past_complexity_limit(subtree.l, options, cons[1]) &&
                return true
            cons[2] > -1 &&
                past_complexity_limit(subtree.r, options, cons[2]) &&
                return true
        end
        return false
    end
end

"""
Check if any unary operators are overly complex.
This assumes  you have already checked whether the constraint is > -1.
"""
function flag_una_operator_complexity(
    tree::AbstractExpressionNode, op, cons, options::AbstractOptions
)::Bool
    any(tree) do subtree
        if subtree.degree == 1 && subtree.op == op
            past_complexity_limit(subtree.l, options, cons) && return true
        end
        return false
    end
end

function count_max_nestedness(tree, degree, op)
    # TODO: Update this to correctly share nodes
    nestedness = tree_mapreduce(
        t -> 0,  # Leafs
        t -> (t.degree == degree && t.op == op) ? 1 : 0,  # Branches
        (p, c...) -> p + max(c...),  # Reduce
        tree;
        break_sharing=Val(true),
    )
    # Remove count of self:
    is_self = tree.degree == degree && tree.op == op
    return nestedness - (is_self ? 1 : 0)
end

"""Check if there are any illegal combinations of operators"""
function flag_illegal_nests(tree::AbstractExpressionNode, options::AbstractOptions)::Bool
    # We search from the top first, then from child nodes at end.
    (nested_constraints = options.nested_constraints) === nothing && return false
    for (degree, op_idx, op_constraint) in nested_constraints
        for (nested_degree, nested_op_idx, max_nestedness) in op_constraint
            any(tree) do subtree
                if subtree.degree == degree && subtree.op == op_idx
                    nestedness = count_max_nestedness(subtree, nested_degree, nested_op_idx)
                    return nestedness > max_nestedness
                end
                return false
            end && return true
        end
    end
    return false
end

"""Check if user-passed constraints are satisfied. Returns false otherwise."""
function check_constraints(
    ex::AbstractExpression,
    options::AbstractOptions,
    maxsize::Int,
    cursize::Union{Int,Nothing}=nothing,
)::Bool
    tree = get_tree(ex)
    return check_constraints(tree, options, maxsize, cursize)
end
function check_constraints(
    tree::AbstractExpressionNode,
    options::AbstractOptions,
    maxsize::Int,
    cursize::Union{Int,Nothing}=nothing,
)::Bool
    ((cursize === nothing) ? compute_complexity(tree, options) : cursize) > maxsize &&
        return false
    count_depth(tree) > options.maxdepth && return false
    for i in 1:(options.nbin)
        cons = options.bin_constraints[i]
        cons == (-1, -1) && continue
        flag_bin_operator_complexity(tree, i, cons, options) && return false
    end
    for i in 1:(options.nuna)
        cons = options.una_constraints[i]
        cons == -1 && continue
        flag_una_operator_complexity(tree, i, cons, options) && return false
    end
    flag_illegal_nests(tree, options) && return false
    return true
end

check_constraints(
    ex::Union{AbstractExpression,AbstractExpressionNode}, options::AbstractOptions
)::Bool = check_constraints(ex, options, options.maxsize)

end
