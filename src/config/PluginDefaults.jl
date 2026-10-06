module PluginDefaultsModule

using DispatchDoctor: @unstable

# Forward declarations for factories implemented by concrete plugin modules.
# Legacy-kwarg factories may return `nothing` when the kwarg disables them.
function default_adaptive_parsimony_plugin end
function default_simulated_annealing_plugin end
function default_adaptive_mutation_weights_plugin end

# Append defaults whose type isn't already in the user tuple. Each default
# may be `nothing` (auto-injected plugin disabled by the legacy kwarg) and
# is filtered out.
@unstable function _merge_with_default_plugins(
    @nospecialize(user_plugins::Tuple), @nospecialize(default_plugins...)
)
    actual_defaults = filter(!isnothing, default_plugins)
    novel = filter(dp -> !any(p -> p isa typeof(dp), user_plugins), actual_defaults)
    return (user_plugins..., novel...)
end

end
