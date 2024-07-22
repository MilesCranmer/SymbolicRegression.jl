module EvaluateInverseModule

using DynamicExpressions:
    DynamicExpressions as DE,
    OperatorEnum,
    AbstractExpressionNode,
    eval_tree_array,
    tree_mapreduce,
    preserve_sharing
using DynamicExpressions.UtilsModule: ResultOk, is_bad_array
using DynamicExpressions.EvaluateModule: get_nuna, get_nbin

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
Inverse the tree evaluation at some `node_to_invert_at` in the `tree`,
given some output of the `tree`, `y` and feature values `X`.

For example, inverting `y = cos(x) * 2.1` with `x` as
`node_to_invert_at` would return an evaluation of the
tree `acos(y / 2.1)`.
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
@generated function _eval_inverse_tree_array(
    tree::N,
    X::AbstractMatrix{T},
    operators::OperatorEnum,
    node_to_invert_at::N,
    y::AbstractVector{T},
    eval_kws::NamedTuple,
)::ResultOk where {T,N<:AbstractExpressionNode{T}}
    nuna = get_nuna(operators)
    nbin = get_nbin(operators)
    quote
        if tree === node_to_invert_at
            # This IS the node we want to invert at,
            # so we return immediately.
            return ResultOk(y, true)
        end

        @assert tree.degree > 0 "Did not find `node_to_invert_at` anywhere in tree"

        if tree.degree == 1 && $nuna > 0
            # op = operators.unaops[tree.op]
            op_idx = tree.op
            Base.Cartesian.@nif(
                $nuna,
                i -> i == op_idx,
                i -> let
                    op = operators.unaops[i]
                    return dispatch_deg1(
                        tree, X, op, operators, node_to_invert_at, y, eval_kws
                    )
                end
            )
        elseif $nbin > 0 # && tree.degree == 2
            op_idx = tree.op
            Base.Cartesian.@nif(
                $nbin,
                i -> i == op_idx,
                i -> let
                    op = operators.binops[i]
                    return dispatch_deg2(
                        tree, X, op, operators, node_to_invert_at, y, eval_kws
                    )
                end
            )
        else
            # Will never be reached (except for inference)
            return ResultOk(y, true)
        end
    end
end

function dispatch_deg1(
    tree::N,
    X::AbstractMatrix{T},
    op::F,
    operators::OperatorEnum,
    node_to_invert_at::N,
    y::AbstractVector{T},
    eval_kws::NamedTuple,
) where {F,T,N<:AbstractExpressionNode{T}}
    # Inverse this operator into `y`
    deg1_invert!(y, op)
    is_bad_array(y) && return ResultOk(y, false)
    return _eval_inverse_tree_array(tree.l, X, operators, node_to_invert_at, y, eval_kws)
end
function dispatch_deg2(
    tree::N,
    X::AbstractMatrix{T},
    op::F,
    operators::OperatorEnum,
    node_to_invert_at::N,
    y::AbstractVector{T},
    eval_kws::NamedTuple,
) where {F,T,N<:AbstractExpressionNode{T}}
    if any(Base.Fix1(===, node_to_invert_at), tree.r)
        # The other side of the tree we evaluate normally,
        # so that we can use it in the inverse
        (result_l, complete_l) = eval_tree_array(tree.l, X, operators; eval_kws...)
        !complete_l && return ResultOk(result_l, complete_l)
        deg2_invert_right!(y, result_l, inverter_right(op))
        is_bad_array(y) && return ResultOk(y, false)
        return _eval_inverse_tree_array(
            tree.r, X, operators, node_to_invert_at, y, eval_kws
        )
    else  # any(===(node_to_invert_at), tree.l)
        (result_r, complete_r) = eval_tree_array(tree.r, X, operators; eval_kws...)
        !complete_r && return ResultOk(result_r, complete_r)
        deg2_invert_left!(y, result_r, inverter_left(op))
        is_bad_array(y) && return ResultOk(y, false)
        return _eval_inverse_tree_array(
            tree.l, X, operators, node_to_invert_at, y, eval_kws
        )
    end
end

function deg1_invert!(y::AbstractVector, op::F) where {F}
    op_inv = approx_inverse(op)
    @inbounds @simd for i in eachindex(y)
        y[i] = op_inv(y[i])
    end
    # TODO: Need to account for non-ok evaluations
    return nothing
end
inverter_right(op::F) where {F} = (l, r) -> approx_inverse(Base.Fix1(op, l))(r)
inverter_left(op::F) where {F} = (l, r) -> approx_inverse(Base.Fix2(op, l))(r)
function deg2_invert_right!(y::AbstractVector, l::AbstractVector, op_inv::F) where {F}
    @inbounds @simd for i in eachindex(y, l)
        y[i] = op_inv(l[i], y[i])
    end
    # TODO: Need to account for non-ok evaluations
    return nothing
end
function deg2_invert_left!(y::AbstractVector, r::AbstractVector, op_inv::F) where {F}
    @inbounds @simd for i in eachindex(y, r)
        y[i] = op_inv(r[i], y[i])
    end
    # TODO: Need to account for non-ok evaluations
    return nothing
end

end
