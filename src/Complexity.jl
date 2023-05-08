module ComplexityModule

import DynamicExpressions: Node, count_nodes
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
        raw_complexity = sum(t -> leaf_complexity(t, options.complexity_mapping), tree)::CT
        return round(Int, raw_complexity)
    else
        return count_nodes(tree)
    end
end

@inline function leaf_complexity(node::Node, cmap::ComplexityMapping{CT})::CT where {CT}
    if node.degree == 0
        if node.constant
            return cmap.constant_complexity
        else
            return cmap.variable_complexity
        end
    elseif node.degree == 1
        return cmap.unaop_complexities[node.op]
    else
        return cmap.binop_complexities[node.op]
    end
end

end
