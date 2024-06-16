module ComplexityModule

using DynamicExpressions:
    AbstractExpression, AbstractExpressionNode, get_tree, count_nodes, tree_mapreduce
using ..CoreModule: Options, ComplexityMapping

function past_complexity_limit(
    tree::Union{AbstractExpression,AbstractExpressionNode}, options::Options, limit
)::Bool
    return compute_complexity(tree, options) > limit
end

"""
Compute the complexity of a tree.

By default, this is the number of nodes in a tree.
However, it could use the custom settings in options.complexity_mapping
if these are defined.
"""
function compute_complexity(
    tree::AbstractExpression, options::Options; break_sharing=Val(false)
)
    return compute_complexity(get_tree(tree), options; break_sharing)
end
function compute_complexity(
    tree::AbstractExpressionNode, options::Options; break_sharing=Val(false)
)::Int
    if options.complexity_mapping.use
        raw_complexity = _compute_complexity(
            tree, options.complexity_mapping; break_sharing
        )
        return round(Int, raw_complexity)
    else
        return count_nodes(tree; break_sharing)
    end
end

function _compute_complexity(
    tree::AbstractExpressionNode, cmap::ComplexityMapping{CT}; break_sharing=Val(false)
)::CT where {CT}
    return tree_mapreduce(
        let vc = cmap.variable_complexity, cc = cmap.constant_complexity
            if vc isa AbstractVector
                t -> t.constant ? cc : @inbounds(vc[t.feature])
            else
                t -> t.constant ? cc : vc
            end
        end,
        let uc = cmap.unaop_complexities, bc = cmap.binop_complexities
            t -> t.degree == 1 ? @inbounds(uc[t.op]) : @inbounds(bc[t.op])
        end,
        +,
        tree,
        CT;
        break_sharing=break_sharing,
        f_on_shared=(result, is_shared) -> is_shared ? result : zero(CT),
    )
end

end
