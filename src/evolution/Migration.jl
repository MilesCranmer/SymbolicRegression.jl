module MigrationModule

using ...InterfacesModule: AbstractOptions
using ..PopulationModule: Population
using ..PopMemberModule: AbstractPopMember, PopMember, reset_birth!
using ...UtilsModule: poisson_sample

"""
    migrate!(migration::Pair{Vector,Population}, options::AbstractOptions; frac::AbstractFloat)

Migrate a fraction of the population from one population to the other, creating copies
to do so. The original migrant population is not modified. Candidates are members, or
populations whose members are all candidates. Pass with, e.g.,
`migrate!(migration_candidates => destination, options; frac=0.1)`
"""
function migrate!(
    migration::Pair{<:Union{Vector{PM},Vector{P}},P},
    options::AbstractOptions;
    frac::AbstractFloat,
) where {T,L,N,PM<:AbstractPopMember{T,L,N},P<:Population{T,L,N,PM}}
    base_pop = migration.second
    population_size = length(base_pop.members)
    mean_number_replaced = population_size * frac
    num_replace = poisson_sample(mean_number_replaced)
    # Most calls replace nobody, so only gather the candidates when needed.
    num_replace == 0 && return nothing

    migrant_candidates = if migration.first isa Vector{P}
        [member for pop in migration.first for member in pop.members]
    else
        migration.first
    end

    # Ensure `replace=true` is a valid setting:
    num_replace = min(num_replace, length(migrant_candidates))
    num_replace = min(num_replace, population_size)

    locations = rand(1:population_size, num_replace)
    migrants = rand(migrant_candidates, num_replace)

    for (i, migrant) in zip(locations, migrants)
        base_pop.members[i] = copy(migrant)
        reset_birth!(base_pop.members[i]; options.deterministic)
    end
    return nothing
end

end
