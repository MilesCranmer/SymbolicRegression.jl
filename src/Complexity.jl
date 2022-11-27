module ComplexityModule

import DynamicExpressions: Node, count_nodes
import ..CoreModule: Options

"""
Compute the complexity of a tree.

By default, this is the number of nodes in a tree.
However, it could use the custom settings in options.complexity_mapping
if these are defined.
"""
function compute_complexity(tree::Node, options::Options)::Int
    if options.complexity_mapping.use
        return round(Int, _compute_complexity(tree, options))
    else
        return count_nodes(tree)
    end
end

function _compute_complexity(tree::Node, options::Options{CT})::CT where {CT<:Real}
    if tree.degree == 0
        if tree.constant
            return options.complexity_mapping.constant_complexity
        else
            return options.complexity_mapping.variable_complexity
        end
    elseif tree.degree == 1
        return (
            options.complexity_mapping.unaop_complexities[tree.op] +
            _compute_complexity(tree.l, options)
        )
    else # tree.degree == 2
        return (
            options.complexity_mapping.binop_complexities[tree.op] +
            _compute_complexity(tree.l, options) +
            _compute_complexity(tree.r, options)
        )
    end
end

end
