using SymbolicUtils

const AllEquationTypes = Union{ConstantType,SymbolicUtils.Sym{Real},SymbolicUtils.Term{Real},SymbolicUtils.Term{Number}}

function to_symbolic(tree::Node, options::Options;
                     varMap::Union{Array{String, 1}, Nothing}=nothing
                    )::AllEquationTypes
    if tree.degree == 0
        if tree.constant
            return tree.val
        else
            if varMap == nothing
                return SymbolicUtils.Sym{Real}(Symbol("x$(tree.val)"))
            else
                return SymbolicUtils.Sym{Real}(Symbol(varMap[tree.val]))
            end
        end
    elseif tree.degree == 1
        left_side = to_symbolic(tree.l, options, varMap=varMap)
        return options.unaops[tree.op](left_side)
    else
        left_side = to_symbolic(tree.l, options, varMap=varMap)
        right_side = to_symbolic(tree.r, options, varMap=varMap)
        return options.binops[tree.op](left_side, right_side)
    end
end


function to_symbolic(tree::Node, options::Options)
    if options.useVarMap
        throw(AssertionError("Using custom variable names and converting to symbolic form is not supported"))
    end
    return evalTreeSymbolic(tree, options)
end
