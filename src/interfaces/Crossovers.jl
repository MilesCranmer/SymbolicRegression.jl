module CrossoversModule

"""
    AbstractCrossover

A crossover kind is a struct (often `Base.@kwdef` for per-crossover config)
subtyping `AbstractCrossover`. The engine dispatches the per-event
`crossover` method on the crossover's type; weight sampling keys off
the type.

To add a new crossover kind, define a struct + a `crossover` method:

```julia
struct MyCrossover <: AbstractCrossover end

function SymbolicRegression.crossover(
    member1, member2, ::MyCrossover, options; kws...
)
    child1, child2 = ...  # combine the parents' trees
    return SymbolicRegression.CrossoverResult{typeof(child1)}(; child1, child2)
end
```

Then include it in `Options(; crossovers = [MyCrossover() => 0.1])`. An
explicit crossover replaces a default of the same type; new crossover types
are added. Pass `default_crossovers=()` to disable every automatic default.

!!! warning "Experimental"
"""
abstract type AbstractCrossover end

"""Swap a random subtree of one parent with a random subtree of the other."""
struct SubtreeCrossover <: AbstractCrossover end

const BUILTIN_CROSSOVER_TYPES = (SubtreeCrossover,)

"""
    default_crossovers() -> Vector{Pair{AbstractCrossover,Float64}}

Default weighted crossover list.
"""
function default_crossovers()
    return Pair{AbstractCrossover,Float64}[SubtreeCrossover() => 1.0]
end

end  # module CrossoversModule
