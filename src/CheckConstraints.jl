module CheckConstraintsModule

using DynamicExpressions:
    AbstractExpressionNode,
    AbstractExpression,
    get_tree,
    count_depth,
    tree_mapreduce,
    get_child
using ..CoreModule: AbstractOptions
using ..ComplexityModule: compute_complexity, past_complexity_limit

# Generic operator complexity checking for any degree
function flag_operator_complexity(
    tree::AbstractExpressionNode, degree::Int, op::Int, cons, options::AbstractOptions
)::Bool
    return any(tree) do subtree
        subtree.degree == degree &&
            subtree.op == op &&
            _check_operator_constraints(subtree, degree, cons, options)
    end
end

function _check_operator_constraints(
    node::AbstractExpressionNode, degree::Int, cons, options::AbstractOptions
)::Bool
    @assert degree != 0

    return any(1:degree) do i
        cons[i] != -1 && past_complexity_limit(get_child(node, i), options, cons[i])
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
    nested_constraints = options.nested_constraints
    isnothing(nested_constraints) && return false
    any(tree) do subtree
        any(nested_constraints) do (degree, op_idx, op_constraints)
            subtree.degree == degree &&
                subtree.op == op_idx &&
                any(op_constraints) do (nested_degree, nested_op_idx, max_nestedness)
                    count_max_nestedness(subtree, nested_degree, nested_op_idx) >
                    max_nestedness
                end
        end
    end
end

"""Check if user-passed constraints are satisfied. Returns false otherwise."""
function check_constraints(
    ex::AbstractExpression,
    options::AbstractOptions,
    maxsize::Int,
    cached_size::Union{Int,Nothing}=nothing,
)::Bool
    tree = get_tree(ex)
    return check_constraints(tree, options, maxsize, cached_size)
end
function check_constraints(
    tree::AbstractExpressionNode,
    options::AbstractOptions,
    maxsize::Int,
    cached_size::Union{Int,Nothing}=nothing,
)::Bool
    @something(cached_size, compute_complexity(tree, options)) > maxsize && return false
    count_depth(tree) > options.maxdepth && return false
    any_invalid = any(enumerate(options.op_constraints)) do (degree, degree_constraints)
        any(enumerate(degree_constraints)) do (op_idx, cons)
            any(!=(-1), cons) &&
                flag_operator_complexity(tree, degree, op_idx, cons, options)
        end
    end
    any_invalid && return false
    flag_illegal_nests(tree, options) && return false
    return true
end

check_constraints(
    ex::Union{AbstractExpression,AbstractExpressionNode}, options::AbstractOptions
)::Bool = check_constraints(ex, options, options.maxsize)

end
