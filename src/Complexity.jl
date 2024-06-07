module ComplexityModule

using TestItems: @testitem
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
    constant_complexity = cmap.constant_complexity
    variable_complexity = cmap.variable_complexity
    unaop_complexities = cmap.unaop_complexities
    binop_complexities = cmap.binop_complexities
    return tree_mapreduce(
        t -> t.constant ? constant_complexity : variable_complexity[t.feature],
        t -> t.degree == 1 ? unaop_complexities[t.op] : binop_complexities[t.op],
        +,
        tree,
        CT;
        break_sharing=break_sharing,
        f_on_shared=(result, is_shared) -> is_shared ? result : zero(CT),
    )
end

@testitem "complexity of variables" begin
    using SymbolicRegression

    options = Options(
        binary_operators=[+, *],
        unary_operators=[sin, cos],
        complexity_of_variables=[1, 2, 3],
        complexity_of_operators=[(+) => 5, (*) => 2]
    )
    x1, x2, x3 = [Node{Float64}(feature=i) for i=1:3]
    tree = x1 + x2 * x3
    @test compute_complexity(tree, options) == 1 + 5 + 2 + 2 + 3
end

end
