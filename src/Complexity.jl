module ComplexityModule

import DynamicExpressions: Node, count_nodes, tree_mapreduce
import ..CoreModule: Options, ComplexityMapping

function past_complexity_limit(tree::Node, options::Options{CT}, limit)::Bool where {CT}
    return compute_complexity(tree, options) > limit
end

"""
Compute the complexity of a tree.

By default, this is the number of nodes in a tree.
However, it could use the custom settings in options.complexity_mapping
if these are defined.
"""
function compute_complexity(tree::Node, options::Options{CT})::Int where {CT}
    if options.complexity_mapping.use
        raw_complexity = _compute_complexity(tree, options)
        return round(Int, raw_complexity)
    else
        return count_nodes(tree)
    end
end

function _compute_complexity(tree::Node, options::Options{CT})::CT where {CT}
    cmap = options.complexity_mapping
    return tree_mapreduce(
        t -> t.constant ? cmap.constant_complexity : cmap.variable_complexity,
        t -> t.degree == 1 ? cmap.unaop_complexities[t.op] : cmap.binop_complexities[t.op],
        +,
        tree,
        CT,
    )
end

end
