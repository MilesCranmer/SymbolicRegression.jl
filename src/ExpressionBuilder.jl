"""
This module provides functions for creating, initializing, and manipulating
`<:AbstractExpression` instances and their metadata within the SymbolicRegression.jl framework.
"""
module ExpressionBuilderModule

using DispatchDoctor: @unstable
using Compat: Fix
using DynamicExpressions:
    AbstractExpressionNode,
    AbstractExpression,
    Expression,
    constructorof,
    get_tree,
    get_contents,
    get_metadata,
    with_contents,
    with_metadata,
    count_scalar_constants,
    eval_tree_array
using StatsBase: StatsBase
using ..CoreModule: AbstractOptions, Dataset, DATA_TYPE
using ..HallOfFameModule: HallOfFame
using ..PopulationModule: Population
using ..PopMemberModule: PopMember

import DynamicExpressions: get_operators
import ..CoreModule: create_expression

@unstable function create_expression(
    t::T, options::AbstractOptions, dataset::Dataset{T,L}, ::Val{embed}=Val(false)
) where {T,L,embed}
    return create_expression(
        t, options, dataset, options.node_type, options.expression_type, Val(embed)
    )
end
@unstable function create_expression(
    t::AbstractExpressionNode{T},
    options::AbstractOptions,
    dataset::Dataset{T,L},
    ::Val{embed}=Val(false),
) where {T,L,embed}
    return create_expression(
        t, options, dataset, options.node_type, options.expression_type, Val(embed)
    )
end
function create_expression(
    ex::AbstractExpression{T},
    options::AbstractOptions,
    ::Dataset{T,L},
    ::Val{embed}=Val(false),
) where {T,L,embed}
    return ex::options.expression_type
end
@unstable function create_expression(
    t::T,
    options::AbstractOptions,
    dataset::Dataset{T,L},
    ::Type{N},
    ::Type{E},
    ::Val{embed}=Val(false),
) where {T,L,embed,N<:AbstractExpressionNode,E<:AbstractExpression}
    return create_expression(constructorof(N)(; val=t), options, dataset, N, E, Val(embed))
end
@unstable function create_expression(
    t::AbstractExpressionNode{T},
    options::AbstractOptions,
    dataset::Dataset{T,L},
    ::Type{<:AbstractExpressionNode},
    ::Type{E},
    ::Val{embed}=Val(false),
) where {T,L,embed,E<:AbstractExpression}
    return constructorof(E)(t; init_params(options, dataset, nothing, Val(embed))...)
end
@unstable function init_params(
    options::AbstractOptions,
    dataset::Dataset{T,L},
    prototype::Union{Nothing,AbstractExpression},
    ::Val{embed},
) where {T,L,embed}
    consistency_checks(options, prototype)
    raw_params = (;
        operators=embed ? options.operators : nothing,
        variable_names=embed ? dataset.variable_names : nothing,
        extra_init_params(
            options.expression_type, prototype, options, dataset, Val(embed)
        )...,
    )
    return sort_params(raw_params, options.expression_type)
end
function sort_params(raw_params::NamedTuple, ::Type{<:AbstractExpression})
    return raw_params
end
function extra_init_params(
    ::Type{E},
    prototype::Union{Nothing,AbstractExpression},
    options::AbstractOptions,
    dataset::Dataset{T},
    ::Val{embed},
) where {T,embed,E<:AbstractExpression}
    # TODO: Potential aliasing here
    return (; options.expression_options...)
end

consistency_checks(::AbstractOptions, prototype::Nothing) = nothing
function consistency_checks(options::AbstractOptions, prototype)
    @assert(
        prototype isa options.expression_type,
        "Need prototype to be of type $(options.expression_type), but got $(prototype)::$(typeof(prototype))"
    )
    return nothing
end

@unstable begin
    function embed_metadata(
        ex::AbstractExpression, options::AbstractOptions, dataset::Dataset{T,L}
    ) where {T,L}
        return with_metadata(ex; init_params(options, dataset, ex, Val(true))...)
    end
    function embed_metadata(
        member::PopMember, options::AbstractOptions, dataset::Dataset{T,L}
    ) where {T,L}
        return PopMember(
            embed_metadata(member.tree, options, dataset),
            member.score,
            member.loss,
            nothing;
            member.ref,
            member.parent,
            deterministic=options.deterministic,
        )
    end
    function embed_metadata(
        pop::Population, options::AbstractOptions, dataset::Dataset{T,L}
    ) where {T,L}
        return Population(
            map(Fix{2}(Fix{3}(embed_metadata, dataset), options), pop.members)
        )
    end
    function embed_metadata(
        hof::HallOfFame, options::AbstractOptions, dataset::Dataset{T,L}
    ) where {T,L}
        return HallOfFame(
            map(Fix{2}(Fix{3}(embed_metadata, dataset), options), hof.members), hof.exists
        )
    end
    function embed_metadata(
        vec::Vector{H}, options::AbstractOptions, dataset::Dataset{T,L}
    ) where {T,L,H<:Union{HallOfFame,Population,PopMember}}
        return map(Fix{2}(Fix{3}(embed_metadata, dataset), options), vec)
    end
end

"""
Strips all metadata except for top-level information, so that we avoid needing
to copy irrelevant information to the evolution itself (like variable names
stored within an expression).

The opposite of this is `embed_metadata`.
"""
function strip_metadata(
    ex::AbstractExpression, options::AbstractOptions, dataset::Dataset{T,L}
) where {T,L}
    return with_metadata(ex; init_params(options, dataset, ex, Val(false))...)
end
function strip_metadata(
    member::PopMember, options::AbstractOptions, dataset::Dataset{T,L}
) where {T,L}
    return PopMember(
        strip_metadata(member.tree, options, dataset),
        member.score,
        member.loss,
        nothing;
        member.ref,
        member.parent,
        deterministic=options.deterministic,
    )
end
function strip_metadata(
    pop::Population, options::AbstractOptions, dataset::Dataset{T,L}
) where {T,L}
    return Population(map(member -> strip_metadata(member, options, dataset), pop.members))
end
function strip_metadata(
    hof::HallOfFame, options::AbstractOptions, dataset::Dataset{T,L}
) where {T,L}
    return HallOfFame(
        map(member -> strip_metadata(member, options, dataset), hof.members), hof.exists
    )
end

@unstable function get_operators(ex::AbstractExpression, options::AbstractOptions)
    return get_operators(ex, options.operators)
end
@unstable function get_operators(ex::AbstractExpressionNode, options::AbstractOptions)
    return get_operators(ex, options.operators)
end

end
