module InvertNodeModule

using DynamicExpressions:
    DynamicExpressions as DE,
    OperatorEnum,
    AbstractExpressionNode,
    eval_tree_array,
    tree_mapreduce,
    preserve_sharing

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

struct ResultOk{A}
    x::A
    ok::Bool
end

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
    eval_kws...
) where {T,N<:AbstractExpressionNode{T}}
    @assert !preserve_sharing(tree) "Not yet tested with shared nodes"
    return _eval_inverse_tree_array(
        tree, X, operators, node_to_invert_at, copy(y), (; eval_kws...)
    )
end
function _eval_inverse_tree_array(
    tree::N,
    X::AbstractMatrix{T},
    operators::OperatorEnum,
    node_to_invert_at::N,
    y::AbstractVector{T},
    eval_kws::NamedTuple
) where {T,N<:AbstractExpressionNode{T}}
    if tree === node_to_invert_at
        # This IS the node we want to invert at,
        # so we return immediately.
        return ResultOk(y, true)
    end

    @assert tree.degree != 0 "Did not find `node_to_invert_at` anywhere in tree"

    if tree.degree == 1
        op = operators.unaops[tree.op]
        # Inverse this operator into `y`
        eval_inverse_deg1!(y, op)
        return _eval_inverse_tree_array(
            tree.l, X, operators, node_to_invert_at, y, eval_kws
        )
    else  # tree.degree == 2
        op = operators.binops[tree.op]
        if any(===(node_to_invert_at), tree.r)
            # The other side of the tree we evaluate normally,
            # so that we can use it in the inverse
            result_l = eval_tree_array(tree.l, X, operators; eval_kws...)
            !result_l.ok && return result_l
            eval_inverse_deg2_right!(y, result_l, op)
            return _eval_inverse_tree_array(
                tree.r, X, operators, node_to_invert_at, y, eval_kws
            )
        else  # any(===(node_to_invert_at), tree.l)
            result_r = eval_tree_array(tree.r, X, operators; eval_kws...)
            !result_r.ok && return result_r
            eval_inverse_deg2_left!(y, result_r, op)
            return _eval_inverse_tree_array(
                tree.l, X, operators, node_to_invert_at, y, eval_kws
            )
        end
    end
end

function eval_inverse_deg1!(y::AbstractVector, op::F) where {F}
    op_inv = approx_inverse(op)
    @simd @inbounds for i in eachindex(y)
        y[i] = op_inv(y[i])
    end
    # TODO: Need to account for non-ok evaluations
    return y
end
function eval_inverse_deg2_right!(y::AbstractVector, l::AbstractVector, op::F) where {F}
    @simd @inbounds for i in eachindex(y, l)
        op_inv = approx_inverse(Base.Fix1(op, l[i]))
        y[i] = op_inv(y[i])
    end
    # TODO: Need to account for non-ok evaluations
    return y
end
function eval_inverse_deg2_left!(y::AbstractVector, r::AbstractVector, op::F) where {F}
    @simd @inbounds for i in eachindex(y, r)
        op_inv = approx_inverse(Base.Fix2(op, r[i]))
        y[i] = op_inv(y[i])
    end
    # TODO: Need to account for non-ok evaluations
    return y
end

end

