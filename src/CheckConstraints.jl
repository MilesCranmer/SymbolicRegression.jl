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
function count_max_nestedness(tree::Node, degree::Int, op::Int, options::Options)::Int
    if tree.degree == 0
        return 0
    elseif tree.degree == 1
        return Int(degree == 1 && tree.op == op) + count_max_nestedness(tree.l, degree, op, options)
    else  # tree.degree == 2
        return Int(degree == 2 && tree.op == op) + max(count_max_nestedness(tree.l, degree, op, options), count_max_nestedness(tree.r, degree, op, options))
    end
end


"""Check if there are any illegal combinations of operators"""
function flag_illegal_nests(tree::Node, options::Options)::Bool
    if tree.degree == 0
        return false
    end

    # We search from the top first, then from child nodes at end.
    op = tree.degree == 1 ? options.unaops[tree.op] : options.binops[tree.op]
    nested_constraints = options.nested_constraints

    if haskey(nested_constraints, op)
        # Now, we count max nesting of any operator specified.
        for (nest_op, max_nesting) ∈ nested_constraints[op]
            nest_op_degree = nest_op ∈ options.unaops ? 1 : 2
            nest_op_idx = nest_op_degree == 1 ? findfirst(isequal(nest_op), options.unaops) : findfirst(isequal(nest_op), options.binops)
            nestedness = count_max_nestedness(tree.l, nest_op_degree, nest_op_idx, options)
            if tree.degree == 2
                nestedness = max(nestedness, count_max_nestedness(tree.r, nest_op_degree, nest_op_idx, options))
            end
            if nestedness > max_nesting
                return true
            end
        end
    end

    if tree.degree == 1
        return flag_illegal_nests(tree.l, options)
    else  # tree.degree == 2
        return (flag_illegal_nests(tree.l, options) || flag_illegal_nests(tree.r, options))
    end
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
    if flag_illegal_nests(tree, options)
        return false
    end

    return true
end

function check_constraints(tree::Node, options::Options)::Bool
    check_constraints(tree, options, options.maxsize)
end

end
