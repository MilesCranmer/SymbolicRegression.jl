module CheckConstraintsModule

import DynamicExpressions: Node
import ..UtilsModule: vals
import ..CoreModule: Options
import ..ComplexityModule: compute_complexity

# Check if any binary operator are overly complex
function flag_bin_operator_complexity(
    tree::Node, ::Val{op}, options::Options
)::Bool where {op}
    if tree.degree == 0
        return false
    elseif tree.degree == 1
        return flag_bin_operator_complexity(tree.l, vals[op], options)
    else
        if tree.op == op
            overly_complex::Bool = (
                (
                    (options.bin_constraints[op][1]::Int > -1) && (
                        compute_complexity(tree.l, options) >
                        options.bin_constraints[op][1]::Int
                    )
                ) || (
                    (options.bin_constraints[op][2]::Int > -1) && (
                        compute_complexity(tree.r, options) >
                        options.bin_constraints[op][2]::Int
                    )
                )
            )
            if overly_complex
                return true
            end
        end
        return (
            flag_bin_operator_complexity(tree.l, vals[op], options) ||
            flag_bin_operator_complexity(tree.r, vals[op], options)
        )
    end
end

# Check if any unary operators are overly complex
function flag_una_operator_complexity(
    tree::Node, ::Val{op}, options::Options
)::Bool where {op}
    if tree.degree == 0
        return false
    elseif tree.degree == 1
        if tree.op == op
            overly_complex::Bool = (
                (options.una_constraints[op]::Int > -1) &&
                (compute_complexity(tree.l, options) > options.una_constraints[op]::Int)
            )
            if overly_complex
                return true
            end
        end
        return flag_una_operator_complexity(tree.l, vals[op], options)
    else
        return (
            flag_una_operator_complexity(tree.l, vals[op], options) ||
            flag_una_operator_complexity(tree.r, vals[op], options)
        )
    end
end

"""Count the max number of times an operator of a given degree is nested"""
function count_max_nestedness(tree::Node, degree::Int, op::Int, options::Options)::Int
    if tree.degree == 0
        return 0
    elseif tree.degree == 1
        count = (degree == 1 && tree.op == op) ? 1 : 0
        return count + count_max_nestedness(tree.l, degree, op, options)
    else  # tree.degree == 2
        count = (degree == 2 && tree.op == op) ? 1 : 0
        return count + max(
            count_max_nestedness(tree.l, degree, op, options),
            count_max_nestedness(tree.r, degree, op, options),
        )
    end
end

# function fast_max_nestedness(tree::Node, degree::Int, op_idx::Int, nested_degree::Int, nested_op_idx::Int, options::Options)::Int
function fast_max_nestedness(
    tree::Node,
    degree::Int,
    op_idx::Int,
    nested_degree::Int,
    nested_op_idx::Int,
    options::Options,
)::Int
    # Don't need to branch - once you find operator, run
    # count_max once, then return. Don't need to go deeper!
    if tree.degree == 0
        return 0
    elseif tree.degree == 1
        if degree != tree.degree || tree.op != op_idx
            return fast_max_nestedness(
                tree.l, degree, op_idx, nested_degree, nested_op_idx, options
            )
        end
        return count_max_nestedness(tree.l, nested_degree, nested_op_idx, options)
    else
        if degree != tree.degree || tree.op != op_idx
            return max(
                fast_max_nestedness(
                    tree.l, degree, op_idx, nested_degree, nested_op_idx, options
                ),
                fast_max_nestedness(
                    tree.r, degree, op_idx, nested_degree, nested_op_idx, options
                ),
            )
        end
        return max(
            count_max_nestedness(tree.l, nested_degree, nested_op_idx, options),
            count_max_nestedness(tree.r, nested_degree, nested_op_idx, options),
        )
    end
end

"""Check if there are any illegal combinations of operators"""
function flag_illegal_nests(tree::Node, options::Options)::Bool
    # We search from the top first, then from child nodes at end.
    nested_constraints = options.nested_constraints
    if nested_constraints === nothing
        return false
    end
    for (degree, op_idx, op_constraint) in nested_constraints
        for (nested_degree, nested_op_idx, max_nestedness) in op_constraint
            nestedness = fast_max_nestedness(
                tree, degree, op_idx, nested_degree, nested_op_idx, options
            )
            if nestedness > max_nestedness
                return true
            end
        end
    end
    return false
end

"""Check if user-passed constraints are violated or not"""
function check_constraints(tree::Node, options::Options, maxsize::Int)::Bool
    size = compute_complexity(tree, options)
    if 0 > size > maxsize
        return false
    end
    for i in 1:(options.nbin)
        if options.bin_constraints[i] == (-1, -1)
            continue
        elseif flag_bin_operator_complexity(tree, Val(i), options)
            return false
        end
    end
    for i in 1:(options.nuna)
        if options.una_constraints[i] == -1
            continue
        elseif flag_una_operator_complexity(tree, Val(i), options)
            return false
        end
    end
    if flag_illegal_nests(tree, options)
        return false
    end

    return true
end

function check_constraints(tree::Node, options::Options)::Bool
    return check_constraints(tree, options, options.maxsize)
end

end
