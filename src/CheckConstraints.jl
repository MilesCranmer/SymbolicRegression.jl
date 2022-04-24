module CheckConstraintsModule

import ..CoreModule: Node, Options
import ..EquationUtilsModule: countNodes

# Check if any binary operator are overly complex
function flagBinOperatorComplexity(tree::Node, ::Val{op}, options::Options)::Bool where {op}
    if tree.degree == 0
        return false
    elseif tree.degree == 1
        return flagBinOperatorComplexity(tree.l, Val(op), options)
    else
        if tree.op == op
            overly_complex::Bool = (
                    ((options.bin_constraints[op][1]::Int > -1) &&
                     (countNodes(tree.l) > options.bin_constraints[op][1]::Int))
                      ||
                    ((options.bin_constraints[op][2]::Int > -1) &&
                     (countNodes(tree.r) > options.bin_constraints[op][2]::Int))
                )
            if overly_complex
                return true
            end
        end
        return (flagBinOperatorComplexity(tree.l, Val(op), options) || flagBinOperatorComplexity(tree.r, Val(op), options))
    end
end

# Check if any unary operators are overly complex
function flagUnaOperatorComplexity(tree::Node, ::Val{op}, options::Options)::Bool where {op}
    if tree.degree == 0
        return false
    elseif tree.degree == 1
        if tree.op == op
            overly_complex::Bool = (
                      (options.una_constraints[op]::Int > -1) &&
                      (countNodes(tree.l) > options.una_constraints[op]::Int)
                )
            if overly_complex
                return true
            end
        end
        return flagUnaOperatorComplexity(tree.l, Val(op), options)
    else
        return (flagUnaOperatorComplexity(tree.l, Val(op), options) || flagUnaOperatorComplexity(tree.r, Val(op), options))
    end
end


"""Count number of a specific operator in a tree"""
function count_operators(tree::Node, ::Val{degree}, ::Val{op}, options::Options)::Int where {op,degree}
    if tree.degree == 0
        return 0
    end

    count = Int(tree.degree == degree && op == tree.op)
    count += count_operators(tree.l, Val(degree), Val(op), options)
    if tree.degree == 2
        count += count_operators(tree.r, Val(degree), Val(op), options)
    end
    return count
end

"""Count the max number of times an operator of a given degree is nested"""
function count_max_nestedness(tree::Node, ::Val{degree}, ::Val{op}, options::Options)::Int where {op,degree}
    if tree.degree == 0
        return 0
    elseif tree.degree == 1
        count = (degree == 1 && tree.op == op) ? 1 : 0
        return count + count_max_nestedness(tree.l, Val(degree), Val(op), options)
    else  # tree.degree == 2
        count = (degree == 2 && tree.op == op) ? 1 : 0
        return count + max(
            count_max_nestedness(tree.l, Val(degree), Val(op), options),
            count_max_nestedness(tree.r, Val(degree), Val(op), options)
        )
    end
end

# function fast_max_nestedness(tree::Node, degree::Int, op_idx::Int, nested_degree::Int, nested_op_idx::Int, options::Options)::Int
function fast_max_nestedness(tree::Node, ::Val{degree}, ::Val{op_idx}, ::Val{nested_degree}, ::Val{nested_op_idx}, options::Options)::Int where {degree,op_idx,nested_degree,nested_op_idx}
    # Don't need to branch - once you find operator, run
    # count_max once, then return. Don't need to go deeper!
    if tree.degree == 0
        return 0
    elseif tree.degree == 1
        if degree != tree.degree || tree.op != op_idx
            return fast_max_nestedness(tree.l, Val(degree), Val(op_idx), Val(nested_degree), Val(nested_op_idx), options)
        end
        return count_max_nestedness(tree.l, Val(nested_degree), Val(nested_op_idx), options)
    else
        if degree != tree.degree || tree.op != op_idx
            return max(
                fast_max_nestedness(tree.l, Val(degree), Val(op_idx), Val(nested_degree), Val(nested_op_idx), options),
                fast_max_nestedness(tree.r, Val(degree), Val(op_idx), Val(nested_degree), Val(nested_op_idx), options)
            )
        end
        return max(
            count_max_nestedness(tree.l, Val(nested_degree), Val(nested_op_idx), options),
            count_max_nestedness(tree.r, Val(nested_degree), Val(nested_op_idx), options)
        )
    end
end

"""Check if there are any illegal combinations of operators"""
function flag_illegal_nests(tree::Node, options::Options{A,B,dA,dB,S})::Bool where {A,B,dA,dB,S}
    # We search from the top first, then from child nodes at end.
    nested_constraints = options.nested_constraints
    for (degree, op_idx, nested_constraint) ∈ nested_constraints
        for (nested_degree, nested_op_idx, max_nestedness) ∈ nested_constraint
            nestedness = fast_max_nestedness(tree, Val(degree), Val(op_idx), Val(nested_degree), Val(nested_op_idx), options)
            if nestedness > max_nestedness
                return true
            end
        end
    end
    return false
end

"""Check if user-passed constraints are violated or not"""
function check_constraints(tree::Node, options::Options, maxsize::Int)::Bool
    if countNodes(tree) > maxsize
        return false
    end
    for i=1:options.nbin
        if options.bin_constraints[i] == (-1, -1)
            continue
        elseif flagBinOperatorComplexity(tree, Val(i), options)
            return false
        end
    end
    for i=1:options.nuna
        if options.una_constraints[i] == -1
            continue
        elseif flagUnaOperatorComplexity(tree, Val(i), options)
            return false
        end
    end
    if options.nested_constraints !== nothing && flag_illegal_nests(tree, options)
        return false
    end

    return true
end

function check_constraints(tree::Node, options::Options)::Bool
    check_constraints(tree, options, options.maxsize)
end

end
