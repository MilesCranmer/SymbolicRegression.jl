module ComplexityModule

using DynamicExpressions: AbstractExpressionNode, count_nodes, tree_mapreduce
using ..CoreModule: Options, ComplexityMapping

function past_complexity_limit(
    tree::AbstractExpressionNode, options::Options{CT}, limit
)::Bool where {CT}
    return compute_complexity(tree, options) > limit
end

"""
Compute the complexity of a tree.

By default, this is the number of nodes in a tree.
However, it could use the custom settings in options.complexity_mapping
if these are defined.
"""
function compute_complexity(
    tree::AbstractExpressionNode, options::Options{CT}; break_sharing=Val(false)
)::Int where {CT}
    if options.complexity_mapping.use
        raw_complexity = _compute_complexity(tree, options; break_sharing)
        return round(Int, raw_complexity)
    else
        return count_nodes(tree; break_sharing)
    end
end

function _compute_complexity(
    tree::AbstractExpressionNode, options::Options{CT}; break_sharing=Val(false)
)::CT where {CT}
    cmap = options.complexity_mapping
    return tree_mapreduce(
        let vc=cmap.variable_complexity, cc=cmap.constant_complexity
            t -> if t.constant
                cc
            else
                if vc isa AbstractVector
                    vc[t.feature]
                else
                    vc
                end
            end
        end,
        let uc=cmap.unaop_complexities, bc=cmap.binop_complexities
            t -> t.degree == 1 ? uc[t.op] : bc[t.op]
        end,
        +,
        tree,
        CT;
        break_sharing=break_sharing,
        f_on_shared=(result, is_shared) -> is_shared ? result : zero(CT),
    )
end

end
