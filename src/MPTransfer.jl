module MPTransferModule
using DispatchDoctor: @unstable

using DynamicExpressions: Expression, Node, get_child, get_metadata, get_tree
using ..PopMemberModule: PopMember
using ..PopulationModule: Population
using ..HallOfFameModule: HallOfFame

struct PackedMembers{T,L,PM,N,M}
    metadata::M
    ends::Vector{Int}
    degrees::Vector{UInt8}
    leaf_types::Vector{UInt8}
    constants::Vector{T}
    features::Vector{UInt16}
    ops::Vector{UInt8}
    costs::Vector{L}
    losses::Vector{L}
    births::Vector{Int}
    complexities::Vector{Int}
    refs::Vector{Int}
    parents::Vector{Int}
end

struct PackedPopulation{P}
    members::P
    n::Int
end

struct PackedHallOfFame{P}
    members::P
    exists::Vector{Bool}
end

function _pack_node!(node::Node, degrees, leaf_types, constants, features, ops)
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

@unstable function _pack_members(
    members::Vector{PM}
) where {T,L,N<:Node{T},E<:Expression{T,N},PM<:PopMember{T,L,E}}
    isempty(members) && return nothing
    metadata = get_metadata(first(members).tree)
    all(member -> get_metadata(member.tree) === metadata, members) || return nothing
    n = length(members)
    ends = Vector{Int}(undef, n)
    degrees = UInt8[]
    leaf_types = UInt8[]
    constants = T[]
    features = UInt16[]
    ops = UInt8[]
    costs = Vector{L}(undef, n)
    losses = Vector{L}(undef, n)
    births = Vector{Int}(undef, n)
    complexities = Vector{Int}(undef, n)
    refs = Vector{Int}(undef, n)
    parents = Vector{Int}(undef, n)
    for (i, member) in enumerate(members)
        _pack_node!(get_tree(member.tree), degrees, leaf_types, constants, features, ops)
        ends[i] = length(degrees)
        costs[i] = member.cost
        losses[i] = member.loss
        births[i] = member.birth
        complexities[i] = getfield(member, :complexity)
        refs[i] = member.ref
        parents[i] = member.parent
    end
    return PackedMembers{T,L,PM,N,typeof(metadata)}(
        metadata,
        ends,
        degrees,
        leaf_types,
        constants,
        features,
        ops,
        costs,
        losses,
        births,
        complexities,
        refs,
        parents,
    )
end
_pack_members(::Vector) = nothing

function _unpack_node(::Type{N}, packed::PackedMembers, positions) where {N<:Node}
    degree = packed.degrees[positions[1]]
    positions[1] += 1
    if degree == 0
        is_constant = packed.leaf_types[positions[2]] != 0
        positions[2] += 1
        if is_constant
            val = packed.constants[positions[3]]
            positions[3] += 1
            return N(; val)
        else
            feature = packed.features[positions[4]]
            positions[4] += 1
            return N(; feature)
        end
    end
    op = packed.ops[positions[5]]
    positions[5] += 1
    children = ntuple(_ -> _unpack_node(N, packed, positions), Int(degree))
    return N(; op, children)
end

function _unpack_members(
    packed::PackedMembers{T,L,PM,N}
) where {T,L,E,N,PM<:PopMember{T,L,E}}
    members = Vector{PM}(undef, length(packed.ends))
    positions = ones(Int, 5)
    for i in eachindex(members)
        tree = _unpack_node(N, packed, positions)
        members[i] = PM(
            E(tree, packed.metadata),
            packed.costs[i],
            packed.losses[i],
            packed.births[i],
            packed.complexities[i],
            packed.refs[i],
            packed.parents[i],
        )
    end
    return members
end

pack_population(pop::Population) = pop
@unstable function pack_population(
    pop::Population{T,L,E,PM}
) where {T,L,N<:Node{T},E<:Expression{T,N},PM<:PopMember{T,L,E}}
    packed = _pack_members(pop.members)
    return packed === nothing ? pop : PackedPopulation(packed, pop.n)
end
pack_population(pop, ::Val{false}) = pop
@unstable pack_population(pop, ::Val{true}) = pack_population(pop)
unpack_population(pop::Population) = pop
unpack_population(pop::PackedPopulation) = Population(_unpack_members(pop.members), pop.n)

pack_hall_of_fame(hof::HallOfFame) = hof
@unstable function pack_hall_of_fame(
    hof::HallOfFame{T,L,E,PM}
) where {T,L,N<:Node{T},E<:Expression{T,N},PM<:PopMember{T,L,E}}
    packed = _pack_members(hof.members)
    return packed === nothing ? hof : PackedHallOfFame(packed, hof.exists)
end
unpack_hall_of_fame(hof::HallOfFame) = hof
function unpack_hall_of_fame(hof::PackedHallOfFame)
    HallOfFame(_unpack_members(hof.members), hof.exists)
end

pack_worker_output(output, ::Val{false}) = output
@unstable function pack_worker_output(
    output::Tuple{<:Population,<:HallOfFame,Any,Float64,<:Tuple}, ::Val{true}
)
    pop, hof, trace, num_evals, plugin_states = output
    packed_pop = pack_population(pop)
    packed_hof = pack_hall_of_fame(hof)
    return if packed_pop === pop && packed_hof === hof
        output
    else
        (packed_pop, packed_hof, trace, num_evals, plugin_states)
    end
end
@unstable function unpack_worker_output(output::Tuple)
    pop, hof, trace, num_evals, plugin_states = output
    unpacked_pop = unpack_population(pop)
    unpacked_hof = unpack_hall_of_fame(hof)
    return if unpacked_pop === pop && unpacked_hof === hof
        output
    else
        (unpacked_pop, unpacked_hof, trace, num_evals, plugin_states)
    end
end

end
