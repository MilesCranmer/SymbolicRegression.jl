module MigrationModule

using StatsBase: StatsBase
import ..CoreModule: Options
import ..PopulationModule: Population
import ..PopMemberModule: PopMember, copy_pop_member_reset_birth

"""
    migrate!(migration::Pair{Population{T},Population{T}}, options::Options; frac::AbstractFloat)

Migrate a fraction of the population from one population to the other, creating copies
to do so. The original migrant population is not modified. Pass with, e.g.,
`migrate!(migration_candidates => destination, options; frac=0.1)`
"""
function migrate!(
    migration::Pair{Vector{PopMember{T}},Population{T}},
    options::Options;
    frac::AbstractFloat,
) where {T}
    base_pop = migration.second
    npop = length(base_pop.members)
    num_replace = round(Int, npop * frac)

    migrant_candidates = migration.first

    locations = StatsBase.sample(1:npop, num_replace; replace=true)
    migrants = StatsBase.sample(migrant_candidates, num_replace; replace=true)

    for (i, migrant) in zip(locations, migrants)
        base_pop.members[i] = copy_pop_member_reset_birth(
            migrant; deterministic=options.deterministic
        )
    end
    return nothing
end

end
