module SimulatedAnnealingModule

using DispatchDoctor: @stable, @unstable
using ..CoreModule:
    AbstractPlugin,
    AbstractOptions,
    ConstantMutation,
    ConstantMutationContext,
    MutationAcceptanceContext
import ..CoreModule:
    init_plugin_state,
    on_cycle_start!,
    condition_mutation!,
    mutation_acceptance_multiplier,
    default_simulated_annealing_plugin

"""
    SimulatedAnnealingPlugin(; alpha=0.1)

Couple the search's mutation pipeline to a temperature schedule that
sweeps linearly from `1.0` at the first cycle of an iteration to `0.0` at
the last. The plugin uses its current temperature for two things:

1. **Constant-perturbation magnitude**: via [`condition_mutation!`](@ref),
   the plugin multiplies `ConstantMutationContext.scale` by the current
   temperature.
2. **Mutation acceptance**: via [`mutation_acceptance_multiplier`](@ref),
   the plugin contributes `exp(-(after_cost - before_cost) / (T * alpha))`
   to the engine's combined accept probability — multiple plugins'
   multipliers compose against a single rand draw so the legacy
   `annealing × frequency_parsimony` semantics are preserved.

The "temperature" concept is entirely local to this plugin's mutable
state; nothing else in the engine references it.

!!! warning "Experimental"
"""
struct SimulatedAnnealingPlugin <: AbstractPlugin
    alpha::Float64
end
function SimulatedAnnealingPlugin(; alpha::Real=0.1)::SimulatedAnnealingPlugin
    converted_alpha = Float64(alpha)
    isfinite(converted_alpha) && converted_alpha > 0 ||
        throw(ArgumentError("`alpha` must be finite and positive."))
    return SimulatedAnnealingPlugin(converted_alpha)
end

"""
    SimulatedAnnealingState

Per-population mutable state (forked via `fork_plugin_state`) for
[`SimulatedAnnealingPlugin`](@ref). `temperature`
is recomputed each cycle by [`on_cycle_start!`](@ref) and read by the
plugin's other hooks.
"""
mutable struct SimulatedAnnealingState
    temperature::Float64
end

function init_plugin_state(::SimulatedAnnealingPlugin, options, dataset)
    SimulatedAnnealingState(1.0)
end

function on_cycle_start!(
    s::SimulatedAnnealingState,
    ::SimulatedAnnealingPlugin,
    cycle_idx::Int,
    ncycles::Int,
    options::AbstractOptions,
)
    s.temperature = ncycles > 1 ? LinRange(1.0, 0.0, ncycles)[cycle_idx] : 1.0
    return nothing
end

function condition_mutation!(
    ctx::ConstantMutationContext,
    s::SimulatedAnnealingState,
    ::SimulatedAnnealingPlugin,
    ::ConstantMutation,
    options::AbstractOptions,
)
    ctx.scale *= s.temperature
    return nothing
end

function mutation_acceptance_multiplier(
    s::SimulatedAnnealingState,
    p::SimulatedAnnealingPlugin,
    ctx::MutationAcceptanceContext,
    options::AbstractOptions,
)
    delta = ctx.after_cost - ctx.before_cost
    return exp(-delta / (s.temperature * p.alpha))
end

@stable(
    default_union_limit = 2,
    function default_simulated_annealing_plugin(; annealing::Bool, alpha::Real)
        annealing || return nothing
        return SimulatedAnnealingPlugin(; alpha=Float64(alpha))
    end
)

end  # module SimulatedAnnealingModule
