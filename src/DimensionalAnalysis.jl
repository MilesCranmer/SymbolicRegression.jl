module DimensionalAnalysisModule

using DynamicExpressions:
    AbstractExpression, AbstractExpressionNode, get_tree, get_child, tree_mapreduce
using DynamicQuantities: Quantity, DimensionError, AbstractQuantity, constructorof

using ..CoreModule: AbstractOptions, Dataset
using ..UtilsModule: safe_call

import DynamicQuantities: dimension, ustrip
import ..CoreModule.OperatorsModule: safe_pow, safe_sqrt

"""
    @maybe_return_call(T, op, (args...))

Basically, we try to evaluate the operator. If
the method is defined AND there is no dimension error,
we return. Otherwise, continue.
"""
macro maybe_return_call(T, op, inputs)
    result = gensym()
    successful = gensym()
    quote
        try
            $(result), $(successful) = safe_call($(esc(op)), $(esc(inputs)), one($(esc(T))))
            $(successful) && valid($(result)) && return $(result)
        catch e
            !isa(e, DimensionError) && rethrow(e)
        end
        false
    end
end

function safe_sqrt(x::Q) where {T,Q<:AbstractQuantity{T}}
    ustrip(x) < 0 && return sqrt(abs(x)) * T(NaN)
    return sqrt(x)
end

"""
    WildcardQuantity{Q<:AbstractQuantity}

A wrapper for a `AbstractQuantity` that allows for a wildcard feature, indicating
there is a free constant whose dimensions are not yet determined.
Also stores a flag indicating whether an expression is dimensionally consistent.
"""
struct WildcardQuantity{Q<:AbstractQuantity}
    val::Q
    wildcard::Bool
    violates::Bool
end

ustrip(w::WildcardQuantity) = ustrip(w.val)
dimension(w::WildcardQuantity) = dimension(w.val)
valid(x::WildcardQuantity) = !x.violates

Base.one(::Type{W}) where {Q,W<:WildcardQuantity{Q}} = return W(one(Q), false, false)
Base.isfinite(w::WildcardQuantity) = isfinite(w.val)

same_dimensions(x::WildcardQuantity, y::WildcardQuantity) = dimension(x) == dimension(y)
has_no_dims(x::Quantity) = iszero(dimension(x))

# Overload *, /, +, -, ^ for WildcardQuantity, as
# we want wildcards to propagate through these operations.
for op in (:(Base.:*), :(Base.:/))
    @eval function $(op)(l::W, r::W) where {W<:WildcardQuantity}
        l.violates && return l
        r.violates && return r
        return W($(op)(l.val, r.val), l.wildcard || r.wildcard, false)
    end
end
for op in (:(Base.:+), :(Base.:-))
    @eval function $(op)(l::W, r::W) where {Q,W<:WildcardQuantity{Q}}
        l.violates && return l
        r.violates && return r
        if same_dimensions(l, r)
            return W($(op)(l.val, r.val), l.wildcard && r.wildcard, false)
        elseif l.wildcard && r.wildcard
            return W(
                constructorof(Q)($(op)(ustrip(l), ustrip(r)), typeof(dimension(l))),
                true,
                false,
            )
        elseif l.wildcard
            return W($(op)(constructorof(Q)(ustrip(l), dimension(r)), r.val), false, false)
        elseif r.wildcard
            return W($(op)(l.val, constructorof(Q)(ustrip(r), dimension(l))), false, false)
        else
            return W(one(Q), false, true)
        end
    end
end
function Base.:^(l::W, r::W) where {Q,W<:WildcardQuantity{Q}}
    l.violates && return l
    r.violates && return r
    if (has_no_dims(l.val) || l.wildcard) && (has_no_dims(r.val) || r.wildcard)
        # Require both base and power to be dimensionless:
        x = ustrip(l)
        y = ustrip(r)
        return W(safe_pow(x, y) * one(Q), false, false)
    else
        return W(one(Q), false, true)
    end
end

function Base.sqrt(l::W) where {W<:WildcardQuantity}
    return l.violates ? l : W(safe_sqrt(l.val), l.wildcard, false)
end
function Base.cbrt(l::W) where {W<:WildcardQuantity}
    return l.violates ? l : W(cbrt(l.val), l.wildcard, false)
end
function Base.abs(l::W) where {W<:WildcardQuantity}
    return l.violates ? l : W(abs(l.val), l.wildcard, false)
end
function Base.inv(l::W) where {W<:WildcardQuantity}
    return l.violates ? l : W(inv(l.val), l.wildcard, false)
end

# Define dimensionally-aware evaluation routine:
@inline function deg0_eval(
    x::AbstractVector{T},
    x_units::Vector{Q},
    t::AbstractExpressionNode{T},
    allow_wildcards::Bool,
) where {T,R,Q<:AbstractQuantity{T,R}}
    if t.constant
        return WildcardQuantity{Q}(Quantity(t.val, R), allow_wildcards, false)
    else
        return WildcardQuantity{Q}(
            (@inbounds x[t.feature]) * (@inbounds x_units[t.feature]), false, false
        )
    end
end
@generated function degn_eval(
    op::F, _arg::W, _args::Vararg{W,Nm1}
) where {F,Nm1,T,Q<:AbstractQuantity{T},W<:WildcardQuantity{Q}}
    N = Nm1 + 1
    quote
        args = (_arg, _args...)
        Base.Cartesian.@nextract($N, arg, args)
        Base.Cartesian.@nexprs($N, i -> arg_i.violates && return arg_i)
        # ^For N = 2:
        # ```
        #      arg_1.violates && return arg_1
        #      arg_2.violates && return arg_2
        # ```
        Base.Cartesian.@nany($N, i -> !isfinite(arg_i)) && return W(one(Q), false, true)
        # ^For N = 2:
        # ```
        #      !isfinite(arg_1) || !isfinite(arg_2) && return W(one(Q), false, true)
        # ```
        # COV_EXCL_START
        Base.Cartesian.@nexprs(
            $(2^N),
            i -> begin
                # Get indices of N-d matrix of types:
                Base.Cartesian.@nexprs(
                    $N, j -> lattice_j = compute_lattice(Val($N), Val(i), Val(j))
                )

                # (e.g., for N = 3, this would be (0, 0, 0), (0, 0, 1), ..., (1, 1, 1))
                #! format: off
                if hasmethod(op, Tuple{Base.Cartesian.@ntuple($N, j -> lattice_j == 0 ? W : T)...}) &&
                        Base.Cartesian.@nall($N, j -> lattice_j == 0 ? true : arg_j.wildcard)

                    # if on last one, we always evaluate (assuming wildcards are on):
                    if i == $(2^N)
                        return W(
                            op(Base.Cartesian.@ntuple($N, j -> ustrip(arg_j))...)::T,
                            false,
                            false,
                        )
                    else
                        @maybe_return_call(
                            W,
                            op,
                            Base.Cartesian.@ntuple(
                                $N, j -> lattice_j == 0 ? arg_j : ustrip(arg_j)
                            )
                        )
                    end
                end
                #! format: on
            end
        )
        # COV_EXCL_STOP
        # ^For N = 2:
        # ```
        #     hasmethod(op, Tuple{W,W}) && @maybe_return_call(W, op, (arg_1, arg_2))
        #     hasmethod(op, Tuple{W,T}) && arg_2.wildcard && @maybe_return_call(W, op, (arg_1, ustrip(arg_2)))
        #     hasmethod(op, Tuple{T,W}) && arg_1.wildcard && @maybe_return_call(W, op, (ustrip(arg_1), arg_2))
        #     hasmethod(op, Tuple{T,T}) && arg_1.wildcard && arg_2.wildcard && W(op(ustrip(arg_1), ustrip(arg_2))::T, false, false)
        # ```
        return W(one(Q), false, true)
    end
end
@generated function compute_lattice(::Val{N}, ::Val{i}, ::Val{j}) where {N,i,j}
    return div(i - 1, (2^(N - j))) % 2
end

function violates_dimensional_constraints_dispatch(
    tree::AbstractExpressionNode{T,D},
    x_units::Vector{Q},
    x::AbstractVector{T},
    operators,
    allow_wildcards,
) where {T,Q<:AbstractQuantity{T},D}
    #! format: off
    return tree_mapreduce(
        leaf -> deg0_eval(x, x_units, leaf, allow_wildcards)::WildcardQuantity{Q},
        branch -> branch,
        (branch, children...) -> degn_eval((@inbounds operators.ops[branch.degree][branch.op]), children...)::WildcardQuantity{Q},
        tree;
        break_sharing=Val(true),
    )
    #! format: on
end

"""
    violates_dimensional_constraints(tree::AbstractExpressionNode, dataset::Dataset, options::AbstractOptions)

Checks whether an expression violates dimensional constraints.
"""
function violates_dimensional_constraints(
    tree::AbstractExpressionNode, dataset::Dataset, options::AbstractOptions
)
    X = dataset.X
    return violates_dimensional_constraints(
        tree, dataset.X_units, dataset.y_units, (@view X[:, 1]), options
    )
end
function violates_dimensional_constraints(
    tree::AbstractExpression, dataset::Dataset, options::AbstractOptions
)
    return violates_dimensional_constraints(get_tree(tree), dataset, options)
end
function violates_dimensional_constraints(
    tree::AbstractExpressionNode{T},
    X_units::AbstractVector{<:Quantity},
    y_units::Union{Quantity,Nothing},
    x::AbstractVector{T},
    options::AbstractOptions,
) where {T}
    allow_wildcards = !(options.dimensionless_constants_only)
    dimensional_output = violates_dimensional_constraints_dispatch(
        tree, X_units, x, options.operators, allow_wildcards
    )
    # ^ Eventually do this with map_treereduce. However, right now it seems
    # like we are passing around too many arguments, which slows things down.
    violates = dimensional_output.violates
    if y_units !== nothing
        violates |= (
            !dimensional_output.wildcard &&
            dimension(dimensional_output) != dimension(y_units)
        )
    end
    return violates
end
function violates_dimensional_constraints(
    ::AbstractExpressionNode{T},
    ::Nothing,
    ::Quantity,
    ::AbstractVector{T},
    ::AbstractOptions,
) where {T}
    return error("This should never happen. Please submit a bug report.")
end
function violates_dimensional_constraints(
    ::AbstractExpressionNode{T},
    ::Nothing,
    ::Nothing,
    ::AbstractVector{T},
    ::AbstractOptions,
) where {T}
    return false
end

end
