module EvaluateInverseModule

using DynamicExpressions:
    OperatorEnum,
    AbstractExpressionNode,
    eval_tree_array,
    get_child,
    preserve_sharing,
    EvalContext
using DynamicExpressions.EvaluateModule: get_op, get_nops

using ..InverseFunctionsModule: approx_inverse

# Helper struct for returning results
struct ResultOk{T}
    x::T
    ok::Bool
end

# Helper struct for masked results: `valid[i]` marks rows where the
# inversion stayed on-domain through the entire path from the root.
struct ResultMasked{T}
    x::T
    valid::BitVector
end

@inline function _masked_eval_context(eval_context::EvalContext)
    return EvalContext(;
        turbo=eval_context.turbo,
        bumper=eval_context.bumper,
        early_exit=false,
        buffer=eval_context.buffer,
        use_fused=eval_context.use_fused,
    )
end

@inline function _masked_eval_kws(eval_kws::NamedTuple)
    eval_context = get(eval_kws, :eval_context, nothing)
    if eval_context !== nothing
        return merge(eval_kws, (; eval_context=_masked_eval_context(eval_context)))
    end

    eval_options = get(eval_kws, :eval_options, nothing)
    if eval_options !== nothing
        masked_eval_context = _masked_eval_context(eval_options)
        if haskey(eval_kws, :turbo) || haskey(eval_kws, :bumper)
            return merge(eval_kws, (; eval_context=masked_eval_context))
        end
        remaining_kws = Base.structdiff(eval_kws, (; eval_options=nothing))
        return merge(remaining_kws, (; eval_context=masked_eval_context))
    end

    masked_eval_context = EvalContext(;
        turbo=get(eval_kws, :turbo, Val(false)),
        bumper=get(eval_kws, :bumper, Val(false)),
        early_exit=false,
    )
    remaining_kws = Base.structdiff(eval_kws, (; turbo=nothing, bumper=nothing))
    return merge(remaining_kws, (; eval_context=masked_eval_context))
end

@inline function _reset_eval_buffer!(eval_kws::NamedTuple)
    buffer = eval_kws.eval_context.buffer
    isnothing(buffer) || (buffer.index[] = 0)
    return nothing
end

"""
Inverse the tree evaluation at some `node_to_invert_at` in the `tree`,
given some output of the `tree`, `y` and feature values `X`.

For example, inverting `y = cos(x) * 2.1` with `x` as
`node_to_invert_at` would return an evaluation of the
tree `acos(y / 2.1)`.

!!! warning
    This API supports an experimental mutation and will change in minor version
    increments.
"""
function eval_inverse_tree_array(
    tree::N,
    X::AbstractMatrix{T},
    operators::OperatorEnum,
    node_to_invert_at::N,
    y::AbstractVector{T};
    eval_kws...,
) where {T,D,N<:AbstractExpressionNode{T,D}}
    if preserve_sharing(tree)
        throw(
            ArgumentError(
                "eval_inverse_tree_array does not currently support shared-node expressions.",
            ),
        )
    end
    masked_eval_kws = _masked_eval_kws((; eval_kws...))
    result = _eval_inverse_tree_array_masked(
        tree, X, operators, node_to_invert_at, copy(y), isfinite.(y), masked_eval_kws
    )
    return (result.x, all(result.valid))
end

"""
    eval_inverse_tree_array_masked(tree, X, operators, node_to_invert_at, y)
        -> (values, valid::BitVector)

Like [`eval_inverse_tree_array`](@ref), but instead of failing when any row
leaves the domain of an inverse operator, it returns a per-row validity mask.
Row `i` is valid only if every inversion step from the root down to
`node_to_invert_at` produced a finite value for that row (and every sibling
subtree evaluated to a finite value there). Rows outside the principal branch
of a non-injective operator (e.g. `log` of a negative value) are marked
invalid rather than poisoning the whole inversion.

A structural failure (an operator with no inverse, a sibling subtree that
fails to evaluate, or the node not being present) yields an all-false mask.

!!! warning
    This API supports an experimental mutation and will change in minor
    version increments.
"""
function eval_inverse_tree_array_masked(
    tree::N,
    X::AbstractMatrix{T},
    operators::OperatorEnum,
    node_to_invert_at::N,
    y::AbstractVector{T};
    eval_kws...,
) where {T,D,N<:AbstractExpressionNode{T,D}}
    if preserve_sharing(tree)
        throw(
            ArgumentError(
                "eval_inverse_tree_array does not currently support shared-node expressions.",
            ),
        )
    end
    masked_eval_kws = _masked_eval_kws((; eval_kws...))
    result = _eval_inverse_tree_array_masked(
        tree, X, operators, node_to_invert_at, copy(y), isfinite.(y), masked_eval_kws
    )
    return (result.x, result.valid)
end

function _eval_inverse_tree_array(
    tree::N,
    X::AbstractMatrix{T},
    operators::OperatorEnum,
    node_to_invert_at::N,
    y::AbstractVector{T},
    eval_kws::NamedTuple,
) where {T,D,N<:AbstractExpressionNode{T,D}}
    result = _eval_inverse_tree_array_masked(
        tree, X, operators, node_to_invert_at, y, isfinite.(y), _masked_eval_kws(eval_kws)
    )
    return ResultOk(result.x, all(result.valid))
end

# This forms an if statement over the degree of a given node.
@generated function _eval_inverse_tree_array_masked(
    tree::N,
    X::AbstractMatrix{T},
    operators::O,
    node_to_invert_at::N,
    y::AbstractVector{T},
    valid::BitVector,
    eval_kws::NamedTuple,
)::ResultMasked where {T,D,N<:AbstractExpressionNode{T,D},O<:OperatorEnum}
    return quote
        tree === node_to_invert_at && return ResultMasked(y, valid)

        tree.degree == 0 && return ResultMasked(y, falses(length(y)))

        degree = tree.degree
        return Base.Cartesian.@nif(
            $D,
            d -> d == degree,  # COV_EXCL_LINE
            d -> begin  # COV_EXCL_LINE
                inner_dispatch_degn_masked(
                    tree, X, Val(d), operators, node_to_invert_at, y, valid, eval_kws
                )
            end,
        )
    end
end

# This forms an if statement over the choice of operator.
@generated function inner_dispatch_degn_masked(
    tree::N,
    X::AbstractMatrix{T},
    ::Val{degree},
    operators::O,
    node_to_invert_at::N,
    y::AbstractVector{T},
    valid::BitVector,
    eval_kws::NamedTuple,
)::ResultMasked where {T,D,N<:AbstractExpressionNode{T,D},degree,O<:OperatorEnum}
    nops = get_nops(O, Val(degree))
    if nops == 0
        msg = "eval_inverse_tree_array cannot invert node degree $degree with the configured operators."
        return quote
            throw(ArgumentError($msg))
        end
    end
    return quote
        op_idx = tree.op
        return Base.Cartesian.@nif(
            $nops,
            i -> i == op_idx,  # COV_EXCL_LINE
            i -> begin  # COV_EXCL_LINE
                dispatch_degn_masked(
                    tree,
                    X,
                    Val($degree),
                    get_op(operators, Val($degree), Val(i)),
                    operators,
                    node_to_invert_at,
                    y,
                    valid,
                    eval_kws,
                )
            end,
        )
    end
end

@generated function dispatch_degn_masked(
    tree::N,
    X::AbstractMatrix{T},
    ::Val{degree},
    op::F,
    operators::OperatorEnum,
    node_to_invert_at::N,
    y::AbstractVector{T},
    valid::BitVector,
    eval_kws::NamedTuple,
) where {degree,F,T,D,N<:AbstractExpressionNode{T,D}}
    degree == 1 && return quote
        complete_inv = degn_invert!(y, (y,), op, Val(1), Val(1))
        !complete_inv && return ResultMasked(y, falses(length(y)))
        valid .&= isfinite.(y)
        any(valid) || return ResultMasked(y, valid)
        return _eval_inverse_tree_array_masked(
            get_child(tree, 1), X, operators, node_to_invert_at, y, valid, eval_kws
        )
    end
    quote
        n = length(y)

        child_to_invert = 0
        Base.Cartesian.@nexprs $(degree - 1) i -> begin
            if child_to_invert == 0 &&
                any(Base.Fix1(===, node_to_invert_at), get_child(tree, i))
                child_to_invert = i
            end
        end
        child_to_invert == 0 && (child_to_invert = $degree)

        # A single reset for the whole sibling group: each sibling has to keep
        # its own slice of the evaluation buffer while the others are computed.
        _reset_eval_buffer!(eval_kws)
        siblings = Base.Cartesian.@ntuple $degree i -> if i == child_to_invert
            y  # placeholder; `degn_invert!` substitutes `y[row]` at position `i`
        else
            (result_i, complete_i) = eval_tree_array(
                get_child(tree, i), X, operators; eval_kws...
            )
            !complete_i && return ResultMasked(y, falses(n))
            valid .&= isfinite.(result_i)
            result_i
        end
        any(valid) || return ResultMasked(y, valid)

        Base.Cartesian.@nif(
            $degree,
            i -> i == child_to_invert,
            i -> begin
                complete_inv = degn_invert!(y, siblings, op, Val($degree), Val(i))
                !complete_inv && return ResultMasked(y, falses(n))
                valid .&= isfinite.(y)
                any(valid) || return ResultMasked(y, valid)
                return _eval_inverse_tree_array_masked(
                    get_child(tree, i),
                    X,
                    operators,
                    node_to_invert_at,
                    y,
                    valid,
                    eval_kws,
                )
            end
        )
    end
end

# Fast general implementation of inverting `op` with respect to its `I`-th
# argument, with the remaining arguments taken row-wise from `siblings`.
# `siblings[I]` is ignored; that slot is supplied by `y`.
@generated function degn_invert!(
    y::AbstractVector, siblings::Tuple, op::F, ::Val{degree}, ::Val{I}
) where {F,degree,I}
    quote
        Base.Cartesian.@nexprs($degree, i -> sibling_i = siblings[i])
        @inbounds for row in eachindex(y)
            args = Base.Cartesian.@ntuple($degree, i -> i == $I ? y[row] : sibling_i[row])
            op_inv = approx_inverse(op, Val($I), args)
            op_inv === nothing && return false
            y[row] = op_inv(y[row])
        end  # COV_EXCL_LINE
        return true
    end
end

end
