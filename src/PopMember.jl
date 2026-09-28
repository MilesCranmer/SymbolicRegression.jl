module PopMemberModule

using DispatchDoctor: @unstable
using DynamicExpressions: AbstractExpression, AbstractExpressionNode, string_tree
import DynamicExpressions: constructorof, with_type_parameters
using Serialization: Serialization
using Distributed: ClusterSerializer
using DynamicExpressions: Expression, Node, get_child
using ..CoreModule:
    AbstractOptions, Dataset, DATA_TYPE, LOSS_TYPE, create_expression, AbstractMutation
import ..CoreModule.OptionsModule: default_popmember_type
import ..ComplexityModule: compute_complexity
using ..UtilsModule: get_birth_order
using ..LossFunctionsModule: eval_cost

"""
    AbstractPopMember{T<:DATA_TYPE,L<:LOSS_TYPE,N<:AbstractExpression{T}}

Abstract type for population members. Defines the interface that all population members must implement.

# Required fields (accessed via getproperty/setproperty!)
- `tree::N`: The expression tree
- `cost::L`: The cost including complexity penalty and normalization
- `loss::L`: The raw loss value
- `birth::Int`: Birth order/generation number
- `ref::Int`: Unique reference ID
- `parent::Int`: Parent reference ID
- `complexity::Int`: Cached complexity (accessed via getfield/setfield! for special handling)
"""
abstract type AbstractPopMember{T<:DATA_TYPE,L<:LOSS_TYPE,N<:AbstractExpression{T}} end

# Define a member of population by equation, cost, and age
mutable struct PopMember{T<:DATA_TYPE,L<:LOSS_TYPE,N<:AbstractExpression{T}} <:
               AbstractPopMember{T,L,N}
    tree::N
    cost::L  # Inludes complexity penalty, normalization
    loss::L  # Raw loss
    birth::Int
    complexity::Int

    # For recording history:
    ref::Int
    parent::Int
end

# Generic interface implementations for AbstractPopMember
@inline function Base.setproperty!(member::AbstractPopMember, field::Symbol, value)
    if field == :complexity
        throw(
            error("Don't set `.complexity` directly. Use `recompute_complexity!` instead.")
        )
    elseif field == :tree
        setfield!(member, :complexity, -1)
    elseif field == :score
        Base.depwarn(
            "deprecated: use `cost` instead of `score`.", Symbol(:setproperty!, :PopMember)
        )
        return setfield!(member, :cost, value)
    end
    return setfield!(member, field, value)
end
@unstable @inline function Base.getproperty(member::AbstractPopMember, field::Symbol)
    if field == :complexity
        throw(
            error("Don't access `.complexity` directly. Use `compute_complexity` instead.")
        )
    elseif field == :score
        Base.depwarn(
            "deprecated: use `cost` instead of `score`.", Symbol(:getproperty, :PopMember)
        )
        return getfield(member, :cost)
    end
    return getfield(member, field)
end
function Base.show(io::IO, p::PopMember{T,L,N}) where {T,L,N}
    shower(x) = sprint(show, x)
    print(io, "PopMember(")
    print(io, "tree = (", string_tree(p.tree), "), ")
    print(io, "loss = ", shower(p.loss), ", ")
    print(io, "cost = ", shower(p.cost))
    print(io, ")")
    return nothing
end

generate_reference() = abs(rand(Int))

"""
    PopMember(t::AbstractExpression{T}, cost::L, loss::L)

Create a population member with a birth date at the current time.
The type of the `Node` may be different from the type of the cost
and loss.

# Arguments

- `t::AbstractExpression{T}`: The tree for the population member.
- `cost::L`: The cost (normalized to a baseline, and offset by a complexity penalty)
- `loss::L`: The raw loss to assign.
"""
function PopMember(
    t::AbstractExpression{T},
    cost::L,
    loss::L,
    options::Union{AbstractOptions,Nothing}=nothing,
    complexity::Union{Int,Nothing}=nothing;
    ref::Int=-1,
    parent::Int=-1,
    deterministic=nothing,
) where {T<:DATA_TYPE,L<:LOSS_TYPE}
    if ref == -1
        ref = generate_reference()
    end
    if !(deterministic isa Bool)
        throw(
            ArgumentError(
                "You must declare `deterministic` as `true` or `false`, it cannot be left undefined.",
            ),
        )
    end
    complexity = complexity === nothing ? -1 : complexity
    return PopMember{T,L,typeof(t)}(
        t,
        cost,
        loss,
        get_birth_order(; deterministic=deterministic),
        complexity,
        ref,
        parent,
    )
end

"""
    PopMember(
        dataset::Dataset{T,L},
        t::AbstractExpression{T},
        options::AbstractOptions
    )

Create a population member with a birth date at the current time.
Automatically compute the cost for this tree.

# Arguments

- `dataset::Dataset{T,L}`: The dataset to evaluate the tree on.
- `t::AbstractExpression{T}`: The tree for the population member.
- `options::AbstractOptions`: What options to use.
"""
function PopMember(
    dataset::Dataset{T,L},
    tree::Union{AbstractExpressionNode{T},AbstractExpression{T}},
    options::AbstractOptions,
    complexity::Union{Int,Nothing}=nothing;
    ref::Int=-1,
    parent::Int=-1,
    deterministic=nothing,
) where {T<:DATA_TYPE,L<:LOSS_TYPE}
    ex = create_expression(tree, options, dataset)
    set_complexity = complexity === nothing ? compute_complexity(ex, options) : complexity
    @assert set_complexity != -1
    cost, loss = eval_cost(dataset, ex, options; complexity=set_complexity)
    return PopMember(
        ex,
        cost,
        loss,
        options,
        set_complexity;
        ref=ref,
        parent=parent,
        deterministic=deterministic,
    )
end

function Base.copy(p::PopMember)
    tree = copy(p.tree)
    cost = copy(p.cost)
    loss = copy(p.loss)
    birth = copy(p.birth)
    complexity = copy(getfield(p, :complexity))
    ref = copy(p.ref)
    parent = copy(p.parent)
    return PopMember(tree, cost, loss, birth, complexity, ref, parent)
end

function reset_birth!(p::AbstractPopMember; deterministic::Bool)
    p.birth = get_birth_order(; deterministic)
    return p
end

# Can read off complexity directly from pop members
function compute_complexity(
    member::AbstractPopMember, options::AbstractOptions; break_sharing=Val(false)
)::Int
    complexity = getfield(member, :complexity)
    complexity == -1 && return recompute_complexity!(member, options; break_sharing)
    # TODO: Turn this into a warning, and then return normal compute_complexity instead.
    return complexity
end
function recompute_complexity!(
    member::AbstractPopMember, options::AbstractOptions; break_sharing=Val(false)
)::Int
    complexity = compute_complexity(member.tree, options; break_sharing)
    setfield!(member, :complexity, complexity)
    return complexity
end

"""
    create_child(parent::P, tree::AbstractExpression{T}, cost, loss, options;
                complexity::Union{Int,Nothing}=nothing, parent_ref) where {T,L,P<:PopMember{T,L}}

Create a new PopMember with a potentially different expression type.
Used by embed_metadata where the expression gains metadata.
"""
function create_child(
    parent::P,
    tree::AbstractExpression{T},
    cost::L,
    loss::L,
    options;
    complexity::Union{Int,Nothing}=nothing,
    mutation_choice::Union{AbstractMutation,Nothing}=nothing,
    parent_ref,
) where {T,L,P<:PopMember{T,L}}
    actual_complexity = @something complexity compute_complexity(tree, options)
    return PopMember(
        tree,
        cost,
        loss,
        options,
        actual_complexity;
        parent=parent_ref,
        deterministic=options.deterministic,
    )
end

"""
    create_child(parents::Tuple{P,P}, tree, cost, loss, options;
                complexity::Union{Int,Nothing}=nothing, parent_ref) where P<:AbstractPopMember

Create a new PopMember from two parents (crossover case).
Custom types should override to blend their additional fields.
"""
function create_child(
    parents::Tuple{P,P},
    tree::AbstractExpression{T},
    cost::L,
    loss::L,
    options;
    complexity::Union{Int,Nothing}=nothing,
    mutation_choice::Union{AbstractMutation,Nothing}=nothing,
    parent_ref,
) where {T,L,P<:PopMember{T,L}}
    actual_complexity = @something complexity compute_complexity(tree, options)
    return PopMember(
        tree,
        cost,
        loss,
        options,
        actual_complexity;
        parent=parent_ref,
        deterministic=options.deterministic,
    )
end

# Function to extract PopMember type from Population or HallOfFame types
function popmember_type end

@unstable default_popmember_type() = PopMember
@unstable constructorof(::Type{<:PopMember}) = PopMember

@inline function with_expression_type(
    ::Type{<:PopMember{T,L}}, ::Type{N}
) where {T,L,N<:AbstractExpression{T}}
    return PopMember{T,L,N}
end

@inline function with_type_parameters(
    ::Type{<:PopMember}, ::Type{T}, ::Type{L}, ::Type{N}
) where {T,L,N}
    return PopMember{T,L,N}
end

@inline function expression_type(::Type{<:AbstractPopMember{<:Any,<:Any,N}}) where {N}
    return N
end

# Worker transfers avoid a type tag for every Nullable child of a Node.
function _pack_node!(
    node::Node{T,D}, degrees, leaf_types, constants, features, ops
) where {T,D}
    push!(degrees, node.degree)
    if node.degree == 0
        push!(leaf_types, UInt8(node.constant))
        if node.constant
            push!(constants, node.val)
        else
            push!(features, node.feature)
        end
    else
        push!(ops, node.op)
        for i in 1:node.degree
            _pack_node!(get_child(node, i), degrees, leaf_types, constants, features, ops)
        end
    end
    return nothing
end

function _serialize_member_tree(
    s::Serialization.AbstractSerializer, ex::Expression{T,N}
) where {T,N<:Node}
    write(s.io, UInt8(1))
    Serialization.serialize(s, getfield(ex, :metadata))
    degrees = UInt8[]
    leaf_types = UInt8[]
    constants = T[]
    features = UInt16[]
    ops = UInt8[]
    _pack_node!(getfield(ex, :tree), degrees, leaf_types, constants, features, ops)
    for values in (degrees, leaf_types, constants, features, ops)
        Serialization.serialize(s, values)
    end
    return nothing
end
function _serialize_member_tree(s::Serialization.AbstractSerializer, ex::AbstractExpression)
    write(s.io, UInt8(0))
    Serialization.serialize(s, ex)
    return nothing
end

function _unpack_node(
    ::Type{N}, degrees, leaf_types, constants, features, ops, positions
) where {T,D,N<:Node{T,D}}
    degree = degrees[positions[1]]
    positions[1] += 1
    degree <= D || throw(ArgumentError("Invalid packed Node degree $degree"))
    if degree == 0
        leaf_type = leaf_types[positions[2]]
        positions[2] += 1
        if leaf_type == 1
            value = constants[positions[3]]
            positions[3] += 1
            return N(; val=value)
        elseif leaf_type == 0
            feature = features[positions[4]]
            positions[4] += 1
            return N(; feature)
        else
            throw(ArgumentError("Invalid packed Node leaf type $leaf_type"))
        end
    end
    op = ops[positions[5]]
    positions[5] += 1
    children = ntuple(
        _ -> _unpack_node(N, degrees, leaf_types, constants, features, ops, positions),
        Int(degree),
    )
    return N(; op, children)
end

function _deserialize_member_tree(
    s::Serialization.AbstractSerializer, ::Type{E}
) where {T,N<:Node,E<:Expression{T,N}}
    read(s.io, UInt8) == 1 || throw(ArgumentError("Expected compact Node expression"))
    metadata = Serialization.deserialize(s)
    degrees, leaf_types, constants, features, ops = (
        Serialization.deserialize(s) for _ in 1:5
    )
    positions = ones(Int, 5)
    tree = _unpack_node(N, degrees, leaf_types, constants, features, ops, positions)
    for (position, values) in
        zip(positions, (degrees, leaf_types, constants, features, ops))
        position == length(values) + 1 || throw(ArgumentError("Trailing packed Node data"))
    end
    return E(tree, metadata)
end
function _deserialize_member_tree(
    s::Serialization.AbstractSerializer, ::Type{E}
) where {E<:AbstractExpression}
    read(s.io, UInt8) == 0 || throw(ArgumentError("Expected uncompressed expression"))
    return Serialization.deserialize(s)::E
end

function Serialization.serialize(s::ClusterSerializer, member::P) where {P<:PopMember}
    Serialization.serialize_cycle_header(s, member) && return nothing
    write(s.io, UInt8(0xA4))
    _serialize_member_tree(s, getfield(member, :tree))
    for field in fieldnames(P)
        field === :tree && continue
        Serialization.serialize(s, getfield(member, field))
    end
    return nothing
end
function Serialization.deserialize(s::ClusterSerializer, ::Type{P}) where {P<:PopMember}
    read(s.io, UInt8) == 0xA4 || throw(ArgumentError("Unsupported PopMember encoding"))
    member = ccall(:jl_new_struct_uninit, Any, (Any,), P)::P
    Serialization.deserialize_cycle(s, member)
    setfield!(member, :tree, _deserialize_member_tree(s, fieldtype(P, :tree)))
    for field in fieldnames(P)
        field === :tree && continue
        setfield!(member, field, Serialization.deserialize(s))
    end
    return member
end
end
