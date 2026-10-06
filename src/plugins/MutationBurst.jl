module MutationBurstModule

using ...InterfacesModule.PluginModule: AbstractPlugin
import ...InterfacesModule.PluginModule: wrap_mutation_step

"""
    MutationBurstPlugin(; retry_attempts=4, compound_probability=0.25, compound_max_steps=2)

Per-cycle local-search extensions to the basic single-mutation loop:

- **Retry** (outer): if the engine rejects a mutation, re-run
  `next_generation` against the original parent up to `retry_attempts`
  total times. Break on the first accepted result.
- **Compound burst** (inner): after an accepted mutation, with probability
  `compound_probability` chain another mutation step on the result, up to
  `compound_max_steps` total accepted mutations.

`retry_attempts = 1` disables retry; `compound_probability = 0` disables
compound bursts; the combination reproduces the upstream single-mutation
loop.

Like all hooks, `wrap_mutation_step` composes across plugins in
`options.plugins` tuple order: earlier plugins wrap outside later ones.
The retry-around-compound nesting above is internal to this plugin's own
`wrap_mutation_step` implementation and is not affected by tuple order.

!!! warning "Extra experimental"
    The retry/compound mechanisms and their composition were validated on
    a single benchmark suite — they may change behavior, defaults, or
    config-knob names in minor releases until exercised more broadly.
"""
struct MutationBurstPlugin <: AbstractPlugin
    retry_attempts::Int
    compound_probability::Float64
    compound_max_steps::Int
    function MutationBurstPlugin(;
        retry_attempts::Integer=4,
        compound_probability::Real=0.25,
        compound_max_steps::Integer=2,
    )
        retry_attempts >= 1 || throw(ArgumentError("`retry_attempts` must be at least 1."))
        0 <= compound_probability <= 1 ||
            throw(ArgumentError("`compound_probability` must be between 0 and 1."))
        compound_max_steps >= 1 ||
            throw(ArgumentError("`compound_max_steps` must be at least 1."))
        return new(
            Int(retry_attempts), Float64(compound_probability), Int(compound_max_steps)
        )
    end
end

wrap_mutation_step(_, p::MutationBurstPlugin) = p

function (p::MutationBurstPlugin)(parent_member, next_step)
    result = next_step(parent_member)
    for _ in 2:(p.retry_attempts)
        result.accepted && break
        result = next_step(parent_member)
    end
    result.accepted || return result
    n_steps = 1
    while n_steps < p.compound_max_steps && rand() < p.compound_probability
        next_result = next_step(result.member)
        next_result.accepted || break
        result = next_result
        n_steps += 1
    end
    return result
end

end  # module MutationBurstModule
