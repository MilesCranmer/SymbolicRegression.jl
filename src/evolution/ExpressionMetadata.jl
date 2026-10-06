module ExpressionMetadataModule

using DispatchDoctor: @unstable
using Compat: Fix
using ...InterfacesModule.OptionsInterfaceModule: AbstractOptions
using ...InterfacesModule.DatasetModule: Dataset
using ...EvaluationModule.ComplexityModule: compute_complexity
using ..PopMemberModule: PopMember, AbstractPopMember, create_child
using ..PopulationModule: Population
using ..HallOfFameModule: HallOfFame
import ...ExpressionsModule.ExpressionBuilderModule: embed_metadata, strip_metadata

@unstable begin
    function embed_metadata(
        member::PM, options::AbstractOptions, dataset::Dataset{T,L}
    ) where {T,L,N,PM<:AbstractPopMember{T,L,N}}
        return create_child(
            member,
            embed_metadata(member.tree, options, dataset),
            member.cost,
            member.loss,
            options;
            complexity=compute_complexity(member, options),
            parent_ref=member.ref,
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
    ) where {T,L,H<:Union{HallOfFame,Population,AbstractPopMember}}
        return map(Fix{2}(Fix{3}(embed_metadata, dataset), options), vec)
    end
end

function strip_metadata(
    member::PopMember, options::AbstractOptions, dataset::Dataset{T,L}
) where {T,L}
    return PopMember(
        strip_metadata(member.tree, options, dataset),
        member.cost,
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

end
