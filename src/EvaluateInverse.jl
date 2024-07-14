module EvaluateInverseModule

using DynamicExpressions:
    DynamicExpressions as DE,
    OperatorEnum,
    AbstractExpressionNode,
    eval_tree_array,
    tree_mapreduce,
    preserve_sharing
using DynamicExpressions.UtilsModule: ResultOk, is_bad_array

using ..InverseFunctionsModule: approx_inverse

# To invert the evaluation around a given node `n`
# 1. We need to evaluate all nodes which do not depend on `n`, by checking
#    at each node whether they contain it as a dependency.
# 2. In the "main branch" containing `n`, we then need to invert the evaluation
#    back up the tree. We can do this by descending until we reach `n`, and then
#    doing some kind of inverse evaluation up the tree, depending on parent values,
#    which get passed down. The parent values will be computed using `dataset.y` in
#    addition to `dataset.X`.
# 3. Nodes which have no dependence on `n` are simply evaluated normally.

"""
Inverse the tree at some `node` given some
expected
"""
function eval_inverse_tree_array(
    tree::N,
    X::AbstractMatrix{T},
    operators::OperatorEnum,
    node_to_invert_at::N,
    y::AbstractVector{T};
    eval_kws...,
) where {T,N<:AbstractExpressionNode{T}}
    @assert !preserve_sharing(tree) "Not yet tested with shared nodes"
    result = _eval_inverse_tree_array(
        tree, X, operators, node_to_invert_at, copy(y), (; eval_kws...)
    )
    return (result.x, result.ok)
end
function _eval_inverse_tree_array(
    tree::N,
    X::AbstractMatrix{T},
    operators::OperatorEnum,
    node_to_invert_at::N,
    y::AbstractVector{T},
    eval_kws::NamedTuple,
)::ResultOk where {T,N<:AbstractExpressionNode{T}}
    if tree === node_to_invert_at
        # This IS the node we want to invert at,
        # so we return immediately.
        return ResultOk(y, true)
    end

    @assert tree.degree > 0 "Did not find `node_to_invert_at` anywhere in tree"

    if tree.degree == 1
        op = operators.unaops[tree.op]
        # Inverse this operator into `y`
        eval_inverse_deg1!(y, op)
        is_bad_array(y) && return ResultOk(y, false)
        return _eval_inverse_tree_array(
            tree.l, X, operators, node_to_invert_at, y, eval_kws
        )
    else  # tree.degree == 2
        op = operators.binops[tree.op]
        if any(n -> n === node_to_invert_at, tree.r)
            # The other side of the tree we evaluate normally,
            # so that we can use it in the inverse
            (result_l, complete_l) = eval_tree_array(tree.l, X, operators; eval_kws...)
            !complete_l && return ResultOk(result_l, complete_l)
            eval_inverse_deg2_right!(y, result_l, op)
            is_bad_array(y) && return ResultOk(y, false)
            return _eval_inverse_tree_array(
                tree.r, X, operators, node_to_invert_at, y, eval_kws
            )
        else  # any(===(node_to_invert_at), tree.l)
            (result_r, complete_r) = eval_tree_array(tree.r, X, operators; eval_kws...)
            !complete_r && return ResultOk(result_r, complete_r)
            eval_inverse_deg2_left!(y, result_r, op)
            is_bad_array(y) && return ResultOk(y, false)
            return _eval_inverse_tree_array(
                tree.l, X, operators, node_to_invert_at, y, eval_kws
            )
        end
    end
end

function eval_inverse_deg1!(y::AbstractVector, op::F) where {F}
    op_inv = approx_inverse(op)
    @inbounds @simd for i in eachindex(y)
        y[i] = op_inv(y[i])
    end
    # TODO: Need to account for non-ok evaluations
    return y
end
function eval_inverse_deg2_right!(y::AbstractVector, l::AbstractVector, op::F) where {F}
    @inbounds @simd for i in eachindex(y, l)
        y[i] = approx_inverse(Base.Fix1(op, l[i]))(y[i])
    end
    # TODO: Need to account for non-ok evaluations
    return y
end
function eval_inverse_deg2_left!(y::AbstractVector, r::AbstractVector, op::F) where {F}
    @inbounds @simd for i in eachindex(y, r)
        y[i] = approx_inverse(Base.Fix2(op, r[i]))(y[i])
    end
    # TODO: Need to account for non-ok evaluations
    return y
end

end

using TestItems: @testitem

@testitem "Basic inversion" begin
    using SymbolicRegression
    using SymbolicRegression.EvaluateInverseModule: eval_inverse_tree_array, ResultOk

    X = randn(3, 32)
    y = randn(32)
    options = Options()
    x1 = Node{Float64}(; feature=1)

    (y_for_x1, complete) = eval_inverse_tree_array(x1, X, options.operators, x1, y)
    @test complete
    @show y_for_x1 ≈ y
end

@testitem "Inversion with operators" begin
    using SymbolicRegression
    using SymbolicRegression.EvaluateInverseModule: eval_inverse_tree_array
    using Random: MersenneTwister

    rng = MersenneTwister(0)
    X = randn(rng, 3, 32)
    y = rand(rng, 32) .- 10
    options = Options(; binary_operators=[+, -, *, /], unary_operators=[cos, exp])

    x1, x2, x3 = map(i -> Node{Float64}(; feature=i), 1:3)

    base_tree = cos(x2 * 5.0)
    # ^We wish to invert the function at this node
    tree = cos(x1) - exp(base_tree * 2.1)

    true_inverse_for_base_tree = @. log(cos(X[1, :]) - y) / 2.1

    (y_for_base_tree, complete) = eval_inverse_tree_array(
        tree, X, options.operators, base_tree, y
    )
    @test y_for_base_tree ≈ true_inverse_for_base_tree
end

@testitem "Inversion with invalid values" begin
    using SymbolicRegression
    using SymbolicRegression.EvaluateInverseModule: eval_inverse_tree_array
    using Random: MersenneTwister

    rng = MersenneTwister(0)
    X = randn(rng, 3, 32)
    y = rand(rng, 32) .- 10
    options = Options(; binary_operators=[+, -, *, /], unary_operators=[cos, exp])

    x1 = Node{Float64}(; feature=1)
    # Impossible to reach `y`
    tree = exp(x1)
    (_, complete) = eval_inverse_tree_array(tree, X, options.operators, x1, y)
    @test !complete

    tree = cos(x1)
    (_, complete) = eval_inverse_tree_array(tree, X, options.operators, x1, y)
    @test !complete
end
