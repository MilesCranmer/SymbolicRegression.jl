module AdaptiveMutationWeightsModule

using ..CoreModule:
    AbstractPlugin,
    AbstractOptions,
    AbstractMutation,
    SimplifyMutation,
    DoNothingMutation,
    MutationEvent
import ..CoreModule: init_plugin_state, on_mutation_end!
import ..CoreModule: default_adaptive_mutation_weights_plugin
import ..MutateModule: condition_mutation_weights!

"""
    AdaptiveMutationWeightsPlugin <: AbstractPlugin

Online-adapt per-mutation weights from the search's own success statistics.
For each mutation kind, the plugin tracks attempts and strictly improving
successes in the configured reward metric and adjusts a
multiplicative factor applied to that mutation's base weight, updated each
mutation via an EMA over the smoothed success-ratio with a floor clamp. Only
the sampled mutation's multiplier is updated, then active multipliers are
normalized to unit mean.

Statistics persist independently for each population.

# Fields
- `smoothing::Float64 = 0.02`: EMA factor for the multiplier update.
- `floor::Float64 = 0.05`: clamp range for the sampled mutation's target ratio
  (`[floor, 1/floor]`) before the EMA update and mean normalization.
- `reward::Symbol = :cost`: objective used to count improvements. Supported
  values are `:cost` and `:loss`.
- `adaptation_strength::Float64 = 0.5`: strength of the learned multiplier in
  log space. Zero preserves the original mutation weights, while one applies
  the learned multipliers without regularization.

Mutation kinds excluded from accounting are declared by dispatch on
`skip_in_adaptive_weights`; by default `SimplifyMutation` and
`DoNothingMutation` are skipped. To add your own:

```julia
SymbolicRegression.AdaptiveMutationWeightsModule.skip_in_adaptive_weights(::MyMutation) = true
```

!!! warning "Experimental"
"""
struct AdaptiveMutationWeightsPlugin <: AbstractPlugin
    smoothing::Float64
    floor::Float64
    reward::Symbol
    adaptation_strength::Float64
    function AdaptiveMutationWeightsPlugin(;
        smoothing::Real=0.02,
        floor::Real=0.05,
        reward::Symbol=:cost,
        adaptation_strength::Real=0.5,
    )
        converted_smoothing = Float64(smoothing)
        converted_floor = Float64(floor)
        converted_adaptation_strength = Float64(adaptation_strength)
        0 <= converted_smoothing <= 1 ||
            throw(ArgumentError("`smoothing` must be between 0 and 1."))
        0 < converted_floor <= 1 || throw(ArgumentError("`floor` must be in (0, 1]."))
        reward in (:cost, :loss) ||
            throw(ArgumentError("`reward` must be either `:cost` or `:loss`."))
        0 <= converted_adaptation_strength <= 1 ||
            throw(ArgumentError("`adaptation_strength` must be between 0 and 1."))
        return new(
            converted_smoothing, converted_floor, reward, converted_adaptation_strength
        )
    end
end

# The annotation keeps the forward-declared factory type-stable across
# module boundaries.
default_adaptive_mutation_weights_plugin()::AdaptiveMutationWeightsPlugin = AdaptiveMutationWeightsPlugin()

"""
    skip_in_adaptive_weights(::AbstractMutation) -> Bool

Whether [`AdaptiveMutationWeightsPlugin`](@ref) should exclude a mutation
kind from its success/attempt accounting. Default `false`. Overridden to
`true` for `SimplifyMutation` and `DoNothingMutation` (they accept trivially / don't
represent real search moves).

Extend by dispatch:

```julia
SymbolicRegression.AdaptiveMutationWeightsModule.skip_in_adaptive_weights(::MyMutation) = true
```
"""
skip_in_adaptive_weights(::AbstractMutation) = false  # COV_EXCL_LINE
skip_in_adaptive_weights(::SimplifyMutation) = true  # COV_EXCL_LINE
skip_in_adaptive_weights(::DoNothingMutation) = true  # COV_EXCL_LINE

"""
    AdaptiveMutationWeightsState

Per-population mutable counters and multipliers, parallel to
`options.mutations`.
"""
struct AdaptiveMutationWeightsState
    attempts::Vector{Float64}
    successes::Vector{Float64}
    multipliers::Vector{Float64}
    active::Vector{Bool}
end

function init_plugin_state(::AdaptiveMutationWeightsPlugin, options, dataset)
    n = length(options.mutations)
    active = [!skip_in_adaptive_weights(mutation) for (mutation, _) in options.mutations]
    return AdaptiveMutationWeightsState(zeros(n), zeros(n), ones(n), active)
end

function on_mutation_end!(
    s::AdaptiveMutationWeightsState,
    p::AdaptiveMutationWeightsPlugin,
    mutation::AbstractMutation,
    event::MutationEvent,
    dataset,
    options::AbstractOptions,
)
    idx = event.mutation_idx
    s.active[idx] || return nothing
    s.attempts[idx] += 1.0
    before, after = if p.reward === :cost
        event.before_cost, event.after_cost
    else
        event.before_loss, event.after_loss
    end
    if event.accepted && !isnothing(after) && after < before
        s.successes[idx] += 1.0
    end
    total_successes = 0.0
    total_attempts = 0.0
    n = 0
    @inbounds for i in eachindex(s.attempts)
        s.active[i] || continue
        total_successes += s.successes[i]
        total_attempts += s.attempts[i]
        n += 1
    end
    mean_rate = (total_successes + n) / (total_attempts + 2n)
    f = p.floor
    upper = inv(f)
    rate = (s.successes[idx] + 1.0) / (s.attempts[idx] + 2.0)
    target = clamp(rate / mean_rate, f, upper)
    s.multipliers[idx] = (1 - p.smoothing) * s.multipliers[idx] + p.smoothing * target

    active_multiplier_sum = 0.0
    @inbounds for i in eachindex(s.multipliers)
        s.active[i] || continue
        active_multiplier_sum += s.multipliers[i]
    end
    mean_multiplier = active_multiplier_sum / n
    @inbounds for i in eachindex(s.multipliers)
        s.active[i] || continue
        s.multipliers[i] /= mean_multiplier
    end
    return nothing
end

function condition_mutation_weights!(
    weights::AbstractVector,
    s::AdaptiveMutationWeightsState,
    p::AdaptiveMutationWeightsPlugin,
    member,
    options::AbstractOptions,
    curmaxsize,
    nfeatures,
)
    mutations = options.mutations
    exponent = p.adaptation_strength
    exponent == 0 && return nothing
    @inbounds for i in eachindex(mutations)
        m, w = weights[i]
        effective_multiplier =
            exponent == 0.5 ? sqrt(s.multipliers[i]) : s.multipliers[i]^exponent
        weights[i] = Pair{AbstractMutation,Float64}(m, w * effective_multiplier)
    end
    return nothing
end

end  # module AdaptiveMutationWeightsModule
