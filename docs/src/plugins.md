# Plugins

Plugins let you hook into the search loop without modifying SymbolicRegression.jl
itself. A plugin is a small struct that opts into lifecycle hooks: observing
mutations, biasing selection and acceptance, reshaping mutation sampling,
wrapping whole mutation steps, injecting initial population members, or
tracking statistics across generations.

This page is the complete reference for the plugin interface: every hook, when
it fires, what it receives and returns, and how plugin state moves between the
head node and workers.

!!! warning "Experimental"

    The plugin interface is experimental. Hook signatures may change in minor
    releases until validated by multiple in-tree plugins.

## How the search works

The search maintains multiple **populations** of candidate expressions.
**Workers** (threads or processes) evolve them; a single **head node**
coordinates everything. A search may target several **outputs** (e.g.,
multi-target regression); each output gets its own dataset, populations, and
plugin states.

The head node repeatedly **dispatches** a population, choosing the least-busy
worker in multiprocessing mode. Plugin state belongs to the (output,
population), rather than a fixed worker. One dispatch runs `ncycles` **cycles**
before the population is returned. Each
cycle walks the population for
`ceil(population_size / tournament_selection_n)` **steps**; each step either:

1. picks a member via **tournament selection** (sample a few members, then sample
   a rank using `tournament_selection_p`, default `0.982`; the fittest under
   the adjusted cost wins most often, and is guaranteed only when `p == 1.0`; see
   [`tournament_cost_multiplier`](@ref)), samples a mutation, applies it, and
   decides whether to **accept** the result (see
   [`mutation_acceptance_multiplier`](@ref)); or
2. picks two members and applies a **crossover** (the engine fires no mutation
   hooks inside crossovers, though tournament multipliers fire when selecting
   the two parents).

After a dispatch finishes, the worker sends the updated population (and its
plugin states) back to the head node, which merges results, updates the hall
of fame, and — if cycles remain — re-dispatches the population.

## Using a plugin

Pass plugin instances to `Options` via the `plugins` keyword (a tuple or
vector):

```julia
using SymbolicRegression

options = Options(;
    binary_operators=[+, -, *, /],
    unary_operators=[cos],
    plugins=(MyPlugin(; strength=0.3), AnotherPlugin()),
)
```

Multiple plugins compose. The engine iterates the tuple at each lifecycle
point and dispatches the appropriate hook on each plugin type, in tuple
order.

Several plugins ship with the package and are **enabled by default**:

- [`AdaptiveParsimonyPlugin`](@ref) — biases tournament selection and mutation
  acceptance away from over-represented complexities. Injected when
  `use_frequency` or `use_frequency_in_tournament` is `true` (the defaults).
- [`AdaptiveMutationWeightsPlugin`](@ref) — learns relative mutation weights
  from successful search moves. Always injected. Pass
  `plugins=(AdaptiveMutationWeightsPlugin(adaptation_strength=0),)` to add
  your own copy that disables the learned adaptation, or set
  `default_plugins=()` to disable all automatic plugins.
- [`SimulatedAnnealingPlugin`](@ref) — anneals constant perturbations and
  mutation acceptance over a temperature schedule. Injected when
  `annealing=true`.
- [`MutationBurstPlugin`](@ref) — opt-in retry/compound-burst behavior; not
  injected automatically.

`Options` appends default plugins **after** your plugins, skipping any default
whose type is already present in your tuple. Plugins compose multiplicatively
and in tuple order, so user plugins are consulted first.

## A complete example

The following plugin is self-contained: copy it into a file and run it. It
gives the search a "second wind": after a run of consecutive rejections, it
temporarily boosts acceptance for every evaluated mutation that reaches the
accept/reject draw, regardless of its cost change, and reports progress from
the head node.

```julia
using SymbolicRegression
using SymbolicRegression:
    AbstractPlugin, AbstractMutation, MutationEvent, MutationAcceptanceContext

# Configuration (immutable). Fields are the user-tunable settings;
# validate them here so bad values fail fast, before the search starts.
struct SecondWindPlugin <: AbstractPlugin
    stall_threshold::Int   # consecutive rejections before the boost activates
    boost::Float64         # per-stall acceptance boost once active
    max_boost::Float64     # cap on the total boost
    verbose::Bool          # print a head-node report after each dispatch
    function SecondWindPlugin(;
        stall_threshold::Integer=10,
        boost::Real=1.5,
        max_boost::Real=8.0,
        verbose::Bool=false,
    )
        stall_threshold >= 1 || throw(ArgumentError("`stall_threshold` must be ≥ 1."))
        boost > 1 || throw(ArgumentError("`boost` must exceed 1."))
        max_boost >= boost || throw(ArgumentError("`max_boost` must be ≥ `boost`."))
        return new(Int(stall_threshold), Float64(boost), Float64(max_boost), verbose)
    end
end

# Mutable state. The same type plays two roles: instances on workers track
# mutation outcomes; the head-node instance tracks search-wide progress.
mutable struct SecondWindState
    consecutive_rejections::Int
    accepted::Int
    rejected::Int
    best_cost::Float64
    dispatches_received::Int
end

SymbolicRegression.init_plugin_state(::SecondWindPlugin, options, dataset) =
    SecondWindState(0, 0, 0, Inf, 0)

# Worker side: shape the accept/reject decision.
function SymbolicRegression.mutation_acceptance_multiplier(
    s::SecondWindState,
    p::SecondWindPlugin,
    ctx::MutationAcceptanceContext,
    options,
)
    stall = s.consecutive_rejections - p.stall_threshold + 1
    stall <= 0 && return 1.0
    return min(p.boost^stall, p.max_boost)
end

# Worker side: observe every mutation outcome.
function SymbolicRegression.on_mutation_end!(
    s::SecondWindState,
    p::SecondWindPlugin,
    ::AbstractMutation,
    event::MutationEvent,
    dataset,
    options,
)
    if event.accepted
        s.consecutive_rejections = 0
        s.accepted += 1
    else
        s.consecutive_rejections += 1
        s.rejected += 1
    end
    return nothing
end

# Head node: runs serially after each dispatch's result is received.
function SymbolicRegression.on_generation_end!(
    s::SecondWindState,
    p::SecondWindPlugin,
    search_state,
    dataset,
    options,
    ropt,
    returned_pop,
)
    best_cost = minimum(member.cost for member in returned_pop.members)
    s.dispatches_received += 1
    s.best_cost = min(s.best_cost, best_cost)
    if p.verbose
        println("dispatch $(s.dispatches_received): best cost = $(round(best_cost; digits=6))")
    end
    return nothing
end

# Head node: runs once, after the search loop exits.
function SymbolicRegression.on_search_end!(
    s::SecondWindState, p::SecondWindPlugin, search_state, dataset, options, ropt
)
    println(
        "SecondWind finished after $(s.dispatches_received) dispatches; " *
        "best cost seen: $(round(s.best_cost; digits=6))",
    )
    return nothing
end

X = 3randn(4, 100)
y = @. X[1, :] * X[2, :] + cos(X[3, :]) - 1.5

options = Options(;
    binary_operators=[+, *, /],
    unary_operators=[cos],
    maxsize=10,
    plugins=(SecondWindPlugin(; stall_threshold=5, boost=2.0, verbose=true),),
)

hall_of_fame = equation_search(X, y; options=options, niterations=2)
```

Note the two roles of the state: the `mutation_acceptance_multiplier` and
`on_mutation_end!` methods run on **workers** against per-population state
forks, so their counters never reach the head-node instance. The
`on_generation_end!` and `on_search_end!` methods run on the **head** against
the head's own state, so the final report counts received dispatches and only
sees head-side fields. See
[Plugin state across workers](@ref) for how to share data in the other
direction.

## The interface at a glance

A plugin has two parts:

- An **immutable configuration struct** subtyping
  [`AbstractPlugin`](@ref). Its fields are the user-tunable settings, and it
  is the dispatch key for every hook. Validate settings in an inner
  constructor, like the shipped plugins do.
- A **mutable state object** of any type you like — a mutable struct, a
  `NamedTuple`, even a `Dict`. State is duck-typed: hooks dispatch on the
  _plugin_ type, so the state needs no supertype. State is created by
  [`init_plugin_state`](@ref) and can be `nothing` for stateless plugins.

Every hook follows a naming taxonomy; the verb shape tells you the contract:

| Category                 | Name shape                 | Contract                                                                                                                                                |
| ------------------------ | -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Observer                 | `on_X_start!`, `on_X_end!` | Engine fires, plugin reacts. Return value ignored.                                                                                                      |
| Multiplier               | `X_multiplier`             | Returns a `Real`. Plugins compose multiplicatively in tuple order.                                                                                      |
| Conditioner              | `condition_X!`             | Mutates a passed struct in place. Composes by sequential in-place mutation.                                                                             |
| Factory (initialization) | `init_X`                   | `init_plugin_state` runs once per (plugin, output); `init_member` runs per initial member.                                                              |
| Factory (per-context)    | `prepare_X`, `fork_X`      | `fork_plugin_state` runs per (output, population); `prepare_mutation_context` runs per sampled mutation and dispatches on the mutation, not the plugin. |
| Defaults                 | `plugin_X`                 | Returns configuration contributed by the plugin when `Options` is constructed.                                                                          |

Hooks generally follow this positional argument-order convention:

```
(mutated_thing_if_any, state, plugin, ...other_context)
```

- `!` functions that mutate one specific thing take it **first**, then
  `state`, then `plugin` (e.g.
  `condition_mutation!(context, state, plugin, mutation, options)`).
- For observers, the state is the mutated thing, so the order is
  `(state, plugin, ...)`.
- Non-`!` hooks that read state (`*_multiplier`, `init_member`) still use
  `(state, plugin, ...)`.
- Constructor hooks that _create_ a state (`init_plugin_state`) have no state
  yet, so the plugin is the dispatch key and goes first.

The exceptions are `refresh_worker_plugin_state(worker_state, latest_head_state,
plugin, dataset)`, which takes two states, and `prepare_mutation_context(mutation)`,
which takes neither state nor plugin.

Default observers and conditioners are no-ops. Multipliers return `1.0`;
`init_member`, `wrap_mutation_step`, `init_plugin_state`, and the generic
`prepare_mutation_context` return `nothing`. `fork_plugin_state` returns a
`deepcopy` of the head state, `refresh_worker_plugin_state` returns the worker
state, and `plugin_mutations` and `plugin_crossovers` return `()`. Override only
what you need.

## The search lifecycle

Here is the order of hook invocations for one output, from `equation_search`
start to finish. Head-node observers run serially; worker hooks run inside the
worker's task or process. With `runtests=true` (the default), each worker process
also runs a small smoke population and five cycles before the search, firing
initialization, cycle, and mutation hooks against the real plugin states.

| #   | Location                 | When                                                                                      | Hook(s)                                                                                                                                                                                                                                                                                                            |
| --- | ------------------------ | ----------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 0   | Head                     | `Options` construction, once                                                              | `plugin_mutations`, `plugin_crossovers` are consulted to build the weighted mutation/crossover lists                                                                                                                                                                                                               |
| 1   | Head                     | Search start, once per (plugin, output)                                                   | `init_plugin_state` (via `init_plugin_states`) builds the head state                                                                                                                                                                                                                                               |
| 2   | Head                     | After initialization, before warmup and the main loop                                     | `on_search_start!`                                                                                                                                                                                                                                                                                                 |
| 3   | Head                     | Before each population's first dispatch                                                   | `fork_plugin_state` builds the worker state for each (output, population)                                                                                                                                                                                                                                          |
| 4   | Population-creation task | Per initial member in each new population                                                 | `init_member` (via `resolve_init_member`), using shared head state with threads or a serialized copy on a remote process; see below                                                                                                                                                                                |
| 5   | Worker                   | Start of each cycle in the dispatch                                                       | `on_cycle_start!`                                                                                                                                                                                                                                                                                                  |
| 6   | Worker                   | Once per cycle, before the first step                                                     | `wrap_mutation_step` — middlewares are composed around every `next_generation` call                                                                                                                                                                                                                                |
| 7   | Worker                   | Per step, during tournament selection                                                     | `tournament_cost_multiplier`                                                                                                                                                                                                                                                                                       |
| 8   | Worker                   | Per step, before mutation sampling                                                        | `condition_mutation_weights!` plugin methods (after the engine's legality conditioning — see [Customization](customization.md))                                                                                                                                                                                    |
| 9   | Worker                   | Per step, after sampling, before mutating                                                 | `prepare_mutation_context`, then `condition_mutation!` per plugin (only if a context was built)                                                                                                                                                                                                                    |
| 10  | Worker                   | Per step, at the end of the mutation, on every exit path                                  | `MutationEvent` is built, then `on_mutation_end!` fires right before returning; `mutation_acceptance_multiplier` is consulted just before the accept/reject draw only on the ordinary path after a successful, non-NaN cost evaluation. Successful `return_immediately` results skip it and are accepted directly. |
| 11  | Worker                   | End of each cycle                                                                         | `on_cycle_end!`                                                                                                                                                                                                                                                                                                    |
| 12  | Head                     | After each dispatch's result is received (hall of fame already updated, before migration) | `on_generation_end!`                                                                                                                                                                                                                                                                                               |
| 13  | Head                     | Before re-dispatching the same population                                                 | `refresh_worker_plugin_state`                                                                                                                                                                                                                                                                                      |
| 14  | Head                     | After the main loop exits, before tearing down workers                                    | `on_search_end!`                                                                                                                                                                                                                                                                                                   |

A few precise details behind the table:

- **`on_generation_end!` vs `on_cycle_end!`.** `on_cycle_end!` fires on the
  worker at the end of _each inner cycle_ of a dispatch. `on_generation_end!`
  fires on the head once per _received dispatch_ — by which point `ncycles`
  inner cycles have run. It receives the population the worker produced, and
  runs _before_ migration mixes in members from outside this dispatch.
- **Mutation acceptance.** The engine takes the product of
  `mutation_acceptance_multiplier` across all plugins and draws **one**
  `rand()`; the mutation is rejected if the product is below the draw. Multiple
  plugins therefore compose without introducing independent random draws.
- **`on_mutation_end!` coverage.** It fires exactly once per
  `next_generation` call, including rejections from constraint checks, NaN
  losses, and the acceptance draw. `event.mutation_idx` indexes into
  `options.mutations` (and the conditioned weight vector, which shares its
  order).
- **`init_member` timing.** It is consulted per initial member inside the
  population-creation task spawned by `@sr_spawner` (also for worker smoke
  populations). Threads may call it concurrently on the shared per-output
  head state; remote processes use a serialized copy, whose mutations never
  reach the head. At most one plugin may return a member; two or more providers
  is an error. If all return `nothing`, the engine generates a random tree as usual.

## Hook reference

### Initialization and state management

```@docs
init_plugin_state
init_plugin_states
fork_plugin_state
refresh_worker_plugin_state
```

### Search lifecycle observers

```@docs
on_search_start!
on_search_end!
on_generation_end!
on_cycle_start!
on_cycle_end!
```

### Mutation observers

```@docs
MutationEvent
on_mutation_end!
```

### Selection and acceptance biases

```@docs
tournament_cost_multiplier
mutation_acceptance_multiplier
```

### Mutation conditioning

```@docs
prepare_mutation_context
condition_mutation!
```

[`condition_mutation_weights!`](@ref) is a related conditioner that reshapes
the _sampling weights_ before a mutation is drawn (rather than configuring the
selected mutation afterwards). Because it is intertwined with the mutation
system, its documentation lives on the [Customization](customization.md) page.

### Wrapping mutation steps

`wrap_mutation_step` returns _mutation middleware_: a callable that receives
`(parent_member, next_step)` and may invoke `next_step` one or many times,
returning one of its `MutationStepResult`s. This enables retry loops, compound
bursts, MCMC-style proposals, or ensemble voting around the engine's
single-mutation step. Plugins compose as **nested middleware in tuple order**:
plugin 1 wraps plugin 2, which wraps `next_generation`, so earlier plugins see
the composed behavior of later ones. A middleware must return a result that
came from `next_step`; evaluation accounting, hall-of-fame updates, and tracing
remain owned by the engine.

### Population seeding

```@docs
init_member
```

### Operation defaults

Plugins may contribute weighted mutation and crossover defaults, as
`mutation => weight` pairs:

```@docs
plugin_mutations
plugin_crossovers
```

Precedence, from strongest to weakest: explicit entries in
`Options(; mutations=..., crossovers=...)`, then plugin contributions, then
built-in defaults. Passing `default_mutations`/`default_crossovers` overrides
_all_ automatic defaults, including plugin contributions.

## Plugin state across workers

The state quadruple divides responsibilities as follows:

| Function                      | Runs on | When                                      | Role                                                    |
| ----------------------------- | ------- | ----------------------------------------- | ------------------------------------------------------- |
| `init_plugin_state`           | Head    | Once per (plugin, output) at search start | Creates the head state.                                 |
| `fork_plugin_state`           | Head    | Before each population's first dispatch   | Creates the worker state for that (output, population). |
| `refresh_worker_plugin_state` | Head    | Before each _re_-dispatch                 | Decides what worker state the next dispatch will see.   |
| `init_plugin_states`          | Head    | Convenience wrapper                       | Maps `init_plugin_state` over all plugins, per output.  |

Key behaviors:

- **Worker states persist.** A fork is built once per (output, population) and
  retained across that population's later dispatches; it is not rebuilt every
  time. The default `fork_plugin_state` is a `deepcopy` — a full snapshot of
  the head state.
- **Worker states round-trip.** When a dispatch finishes, the worker's final
  state is shipped back to the head alongside the population.
  `refresh_worker_plugin_state` then receives both that returned state _and_
  the latest head state, and returns whatever the next dispatch should use.
  The default keeps the worker state as-is;
  [`AdaptiveParsimonyPlugin`](@ref) instead re-forks from the latest head
  state, pushing fresh frequency statistics down to workers.
- **Workers never construct their own state.** In multiprocessing mode, plugin
  configuration travels via `options.plugins`, and worker states are forked on
  the head and serialized with the dispatch.
- **Head observers receive head state.** `on_generation_end!`,
  `on_search_start!`, and `on_search_end!` receive it serially. `init_member`
  receives the same object in concurrent population-creation tasks with threads,
  or a serialized copy with multiprocessing; mutations to that copy never
  reach the head. Worker hooks (`on_cycle_start!`, `on_cycle_end!`, `on_mutation_end!`,
  `tournament_cost_multiplier`, `mutation_acceptance_multiplier`,
  `condition_mutation!`, `wrap_mutation_step`) receive the worker fork, so any
  counters they bump stay worker-local unless you deliberately share.

To aggregate worker-side events onto the head, share a `Channel` (or
`RemoteChannel` in multiprocessing mode) and hand it to workers in
`fork_plugin_state`. The test suite uses exactly this pattern:

```julia
# Default fork_plugin_state deepcopies, which would isolate the channel
# and lose worker-side events. Returning the head state itself shares it.
SymbolicRegression.fork_plugin_state(
    head::LifecyclePluginState, ::LifecyclePlugin, dataset
) = head
```

(Here the state holds a `Channel{Any}` passed to the plugin; both head and worker
hooks `put!` events into it, and the test drains it after `equation_search`
returns. A head hook could instead consume available events during the search.
A plain `Channel` does not span processes; use `RemoteChannel` in multiprocessing mode.)

## Error handling

Hooks are invoked synchronously, in plugin tuple order, with no error
isolation: an exception thrown inside a hook propagates to its caller. On the
head node this aborts the search; on a worker it surfaces when the head
retrieves the dispatch's result, also aborting the search.

Practical consequences:

- Validate configuration eagerly in the plugin's constructor (the shipped
  plugins with numeric settings throw `ArgumentError` for bad settings), so
  failures happen when the plugin is constructed rather than mid-search.
- Wrap fallible external calls (I/O, logging systems, network) in your own
  `try`/`catch` if a transient failure should not kill a long search.

## Thread and process safety

| Hook                                                                         | Runs on                  | Concurrency                                          | State seen                                                          |
| ---------------------------------------------------------------------------- | ------------------------ | ---------------------------------------------------- | ------------------------------------------------------------------- |
| `on_search_start!` / `on_search_end!`                                        | Head                     | Serial                                               | Head state                                                          |
| `on_generation_end!`                                                         | Head                     | Serial; safe to mutate state                         | Head state                                                          |
| `init_member`                                                                | Population-creation task | Concurrent with threads; remote with multiprocessing | Shared head state (threads); serialized head-state copy (processes) |
| `on_cycle_start!` / `on_cycle_end!`                                          | Worker                   | Concurrent across workers; serial within one         | Worker fork                                                         |
| `on_mutation_end!`, `condition_mutation!`, multipliers, `wrap_mutation_step` | Worker                   | Within the worker's evolution loop                   | Worker fork                                                         |
| `fork_plugin_state`                                                          | Head                     | Serial                                               | Head state                                                          |
| `refresh_worker_plugin_state`                                                | Head                     | Serial                                               | Worker state + head state                                           |

Rules of thumb:

- Keep `init_member` read-only or make it thread-safe (multiple
  population-creation tasks may call it concurrently in multithreading mode).
- Worker hooks may run concurrently _across_ workers; use only worker-local
  state, or coordinate via `Channel`/`RemoteChannel`.
- `on_search_end!` runs before workers are torn down, but multiprocessing
  cycles may still be in flight when it fires — do not assume all dispatched
  work has returned.

## Worked examples from the shipped plugins

The three other in-tree plugins (besides
[`AdaptiveParsimonyPlugin`](@ref)) each exercise a different corner of the
interface. All snippets below are abridged from `src/plugins/`.

### `SimulatedAnnealingPlugin`: cycle-scoped state and acceptance

Temperature is recomputed once per cycle in `on_cycle_start!`, then consumed
by two other hooks — the pattern for any per-cycle schedule:

```julia
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

function mutation_acceptance_multiplier(
    s::SimulatedAnnealingState,
    p::SimulatedAnnealingPlugin,
    ctx::MutationAcceptanceContext,
    options::AbstractOptions,
)
    delta = ctx.after_cost - ctx.before_cost
    return exp(-delta / (s.temperature * p.alpha))
end
```

The same plugin conditions the already-selected mutation: it scales the
constant-perturbation magnitude by dispatching
`condition_mutation!` on `ConstantMutationContext` (built by the engine's
default `prepare_mutation_context` for `ConstantMutation`):

```julia
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
```

### `AdaptiveMutationWeightsPlugin`: accounting with `MutationEvent`

The plugin tracks attempts and strict improvements per mutation kind, keyed by
`event.mutation_idx`, inside `on_mutation_end!`, excluding `SimplifyMutation`
and `DoNothingMutation` via `skip_in_adaptive_weights`:

```julia
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
```

The learned multipliers reach the sampler through
[`condition_mutation_weights!`](@ref) (see the
[Customization](customization.md) page), and `event.after_cost === nothing` is
handled as "no valid evaluation occurred" — always guard the `after` fields.

### `MutationBurstPlugin`: middleware with `wrap_mutation_step`

The plugin _is_ the middleware: `wrap_mutation_step` returns the plugin
instance, and the plugin is callable. It retries rejected mutations against
the same parent, then chains extra mutations after an acceptance:

```julia
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
```

### `AdaptiveParsimonyPlugin`: the full state lifecycle

This plugin shows all four state functions cooperating. It snapshots and
normalizes its frequency table when forking, pushes the latest head
statistics to workers on every re-dispatch, updates frequencies on the head in
`on_generation_end!`, and reads them in both multipliers:

```julia
function fork_plugin_state(
    head_state::AdaptiveParsimonyState, ::AdaptiveParsimonyPlugin, dataset
)
    snapshot = deepcopy(head_state.rss)::RunningSearchStatistics
    normalize_frequencies!(snapshot)
    return AdaptiveParsimonyState(snapshot)
end

function refresh_worker_plugin_state(
    worker_state::AdaptiveParsimonyState,
    latest_head_state::AdaptiveParsimonyState,
    plugin::AdaptiveParsimonyPlugin,
    dataset,
)
    return fork_plugin_state(latest_head_state, plugin, dataset)
end

function tournament_cost_multiplier(
    s::AdaptiveParsimonyState,
    p::AdaptiveParsimonyPlugin,
    member::AbstractPopMember{T,L,N},
    options::AbstractOptions,
) where {T,L,N}
    p.tournament || return one(L)
    sz = compute_complexity(member, options)
    frequency = if (0 < sz <= options.maxsize)
        L(s.rss.normalized_frequencies[sz])
    else
        zero(L)
    end
    return exp(L(options.adaptive_parsimony_scaling) * frequency)
end
```

## Testing your plugin

The package's own test suite (`test/unit/`) shows two useful patterns:

- **Unit-test the default contracts without a search.** Instantiate your
  plugin against `Options(...; default_plugins=())` and assert each hook's
  default: observers return `nothing`, multipliers return `1.0`,
  `init_member` returns `nothing`, `wrap_mutation_step` returns `nothing`, and
  `fork_plugin_state` deepcopies. See
  `test/unit/misc/test_plugin_interface.jl`.
- **Run a tiny real search.** Pass a `Channel` in your plugin, share it via
  `fork_plugin_state` (see above), and count hook firings under
  `parallelism=:serial`. The lifecycle test asserts `on_search_start!` and
  `on_search_end!` fire exactly once, while cycle hooks fire in matching
  pairs. See the `"Plugin interface: lifecycle hooks called for each plugin"`
  test item.

## Dispatching on mutation types

`on_mutation_end!` receives the mutation as a typed argument, so you can write
specific methods for individual mutation types:

```julia
function SymbolicRegression.on_mutation_end!(
    state::MyState,
    ::MyPlugin,
    ::ConstantMutation,
    event::MutationEvent,
    dataset,
    options,
)
    # handle constant mutations specifically
end
```

Available mutation types: `ConstantMutation`, `OperatorMutation`,
`FeatureMutation`, `SwapOperandsMutation`, `AddNodeMutation`,
`InsertNodeMutation`, `DeleteNodeMutation`, `FormConnectionMutation`,
`BreakConnectionMutation`, `RotateTreeMutation`, `BacksolveMutation`,
`SimplifyMutation`, `RandomizeMutation`, `OptimizeMutation`,
`DoNothingMutation`. Use `::AbstractMutation` for a generic catch-all.

## Built-in plugins

```@docs
AdaptiveParsimonyPlugin
AdaptiveMutationWeightsPlugin
SimulatedAnnealingPlugin
MutationBurstPlugin
```

## Abstract type

```@docs
AbstractPlugin
```
