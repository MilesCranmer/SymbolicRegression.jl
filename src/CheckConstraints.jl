# Check if any binary operator are overly complex
function flagBinOperatorComplexity(tree::Node, op::Int, options::Options)::Bool
    if tree.degree == 0
        return false
    elseif tree.degree == 1
        return flagBinOperatorComplexity(tree.l, op, options)
    else
        if tree.op == op
            overly_complex = (
                    ((options.bin_constraints[op][1] > -1) &&
                     (countNodes(tree.l) > options.bin_constraints[op][1]))
                      ||
                    ((options.bin_constraints[op][2] > -1) &&
                     (countNodes(tree.r) > options.bin_constraints[op][2]))
                )
            if overly_complex
                return true
            end
        end
        return (flagBinOperatorComplexity(tree.l, op, options) || flagBinOperatorComplexity(tree.r, op, options))
    end
end

# Check if any unary operators are overly complex
function flagUnaOperatorComplexity(tree::Node, op::Int, options::Options)::Bool
    if tree.degree == 0
        return false
    elseif tree.degree == 1
        if tree.op == op
            overly_complex = (
                      (options.una_constraints[op] > -1) &&
                      (countNodes(tree.l) > options.una_constraints[op])
                )
            if overly_complex
                return true
            end
        end
        return flagUnaOperatorComplexity(tree.l, op, options)
    else
        return (flagUnaOperatorComplexity(tree.l, op, options) || flagUnaOperatorComplexity(tree.r, op, options))
    end
end
