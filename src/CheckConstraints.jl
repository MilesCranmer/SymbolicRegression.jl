using FromFile
@from "Core.jl" import Node, Options
@from "EquationUtils.jl" import countNodes

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

"""Check if user-passed constraints are violated or not"""
function check_constraints(tree::Node, options::Options)::Bool
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
    return true
end
