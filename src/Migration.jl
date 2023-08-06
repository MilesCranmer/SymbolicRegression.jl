module MigrationModule

using StatsBase: StatsBase
import ..CoreModule: Options, DATA_TYPE, LOSS_TYPE
import ..PopulationModule: Population
import ..PopMemberModule: PopMember, copy_pop_member_reset_birth
import ..UtilsModule: poisson_sample

"""
    migrate!(migration::Pair{Population{T,L},Population{T,L}}, options::Options; frac::AbstractFloat)

Migrate a fraction of the population from one population to the other, creating copies
to do so. The original migrant population is not modified. Pass with, e.g.,
`migrate!(migration_candidates => destination, options; frac=0.1)`
"""
function migrate!(
    migration::Pair{Vector{PopMember{T,L}},Population{T,L}},
    options::Options;
    frac::AbstractFloat,
) where {T<:DATA_TYPE,L<:LOSS_TYPE}
    base_pop = migration.second
    population_size = length(base_pop.members)
    mean_number_replaced = population_size * frac
    num_replace = poisson_sample(mean_number_replaced)

    migrant_candidates = migration.first

    # Ensure `replace=true` is a valid setting:
    num_replace = min(num_replace, length(migrant_candidates))
    num_replace = min(num_replace, population_size)

    locations = StatsBase.sample(1:population_size, num_replace; replace=true)
    migrants = StatsBase.sample(migrant_candidates, num_replace; replace=true)

    for (i, migrant) in zip(locations, migrants)
        base_pop.members[i] = copy_pop_member_reset_birth(
            migrant; deterministic=options.deterministic
        )
    end
    return nothing
end

end
