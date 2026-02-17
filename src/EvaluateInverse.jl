module EvaluateInverseModule

using DynamicExpressions:
    DynamicExpressions as DE,
    OperatorEnum,
    AbstractExpressionNode,
    eval_tree_array,
    tree_mapreduce,
    preserve_sharing

using ..InverseFunctionsModule: approx_inverse

# Helper struct for returning results
struct ResultOk{T}
    x::T
    ok::Bool
end

# Helper functions
is_bad_array(x) = any(isnan, x) || any(isinf, x)
get_nuna(operators::OperatorEnum) = length(operators.unaops)
get_nbin(operators::OperatorEnum) = length(operators.binops)

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
    return (result.x, result.ok && !is_bad_array(result.x))
end

@generated function _eval_inverse_tree_array(
    tree::N,
    X::AbstractMatrix{T},
    operators::O,
    node_to_invert_at::N,
    y::AbstractVector{T},
    eval_kws::NamedTuple,
)::ResultOk where {T,N<:AbstractExpressionNode{T},O<:OperatorEnum}
    # Extract operator counts at compile time from the type
    op_type = O.parameters[1]  # Tuple{Tuple{unary...}, Tuple{binary...}}
    nuna = length(op_type.parameters[1].parameters)
    nbin = length(op_type.parameters[2].parameters)
    quote
        if tree === node_to_invert_at
            # This IS the node we want to invert at,
            # so we return immediately.
            return ResultOk(y, true)
        end

        # If we reached a leaf without finding `node_to_invert_at`, return failure.
        # This can happen when the tree contains unsupported operator degrees (e.g., ternary)
        # since we only handle degree 1 and 2 — the descent skips ternary subtrees.
        if tree.degree == 0
            return ResultOk(y, false)
        end

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
    !deg1_invert!(y, op) && return ResultOk(y, false)
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
        deg2_invert_right!(y, result_l, op) || return ResultOk(y, false)
        is_bad_array(y) && return ResultOk(y, false)
        return _eval_inverse_tree_array(
            tree.r, X, operators, node_to_invert_at, y, eval_kws
        )
    else  # any(===(node_to_invert_at), tree.l)
        (result_r, complete_r) = eval_tree_array(tree.r, X, operators; eval_kws...)
        !complete_r && return ResultOk(result_r, complete_r)
        deg2_invert_left!(y, result_r, op) || return ResultOk(y, false)
        is_bad_array(y) && return ResultOk(y, false)
        return _eval_inverse_tree_array(
            tree.l, X, operators, node_to_invert_at, y, eval_kws
        )
    end
end

function deg1_invert!(y::AbstractVector, op::F) where {F}
    op_inv = approx_inverse(op)
    op_inv === nothing && return false
    @inbounds @simd for i in eachindex(y)
        y[i] = op_inv(y[i])
    end
    return true
end

function deg2_invert_right!(y::AbstractVector, l::AbstractVector, op::F) where {F}
    @inbounds for i in eachindex(y, l)
        op_inv = approx_inverse(Base.Fix1(op, l[i]))
        op_inv === nothing && return false
        y[i] = op_inv(y[i])
    end
    return true
end

function deg2_invert_left!(y::AbstractVector, r::AbstractVector, op::F) where {F}
    @inbounds for i in eachindex(y, r)
        op_inv = approx_inverse(Base.Fix2(op, r[i]))
        op_inv === nothing && return false
        y[i] = op_inv(y[i])
    end
    return true
end

end
