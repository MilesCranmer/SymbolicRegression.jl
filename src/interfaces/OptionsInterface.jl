module OptionsInterfaceModule

"""
    AbstractOptions

An abstract type that stores all search hyperparameters for SymbolicRegression.jl.
The standard implementation is [`Options`](@ref).

You may wish to create a new subtypes of `AbstractOptions` to override certain functions
or create new behavior. Ensure that this new type has all properties of [`Options`](@ref).

For example, if we have new options that we want to add to `Options`:

```julia
Base.@kwdef struct MyNewOptions
    a::Float64 = 1.0
    b::Int = 3
end
```

we can create a combined options type that forwards properties to each corresponding type:

```julia
struct MyOptions{O<:SymbolicRegression.Options} <: SymbolicRegression.AbstractOptions
    new_options::MyNewOptions
    sr_options::O
end
const NEW_OPTIONS_KEYS = fieldnames(MyNewOptions)

# Constructor with both sets of parameters:
function MyOptions(; kws...)
    new_options_keys = filter(k -> k in NEW_OPTIONS_KEYS, keys(kws))
    new_options = MyNewOptions(; NamedTuple(new_options_keys .=> Tuple(kws[k] for k in new_options_keys))...)
    sr_options_keys = filter(k -> !(k in NEW_OPTIONS_KEYS), keys(kws))
    sr_options = SymbolicRegression.Options(; NamedTuple(sr_options_keys .=> Tuple(kws[k] for k in sr_options_keys))...)
    return MyOptions(new_options, sr_options)
end

# Make all `Options` available while also making `new_options` accessible
function Base.getproperty(options::MyOptions, k::Symbol)
    if k in NEW_OPTIONS_KEYS
        return getproperty(getfield(options, :new_options), k)
    else
        return getproperty(getfield(options, :sr_options), k)
    end
end

Base.propertynames(options::MyOptions) = (NEW_OPTIONS_KEYS..., fieldnames(SymbolicRegression.Options)...)
```

which would let you access `a` and `b` from `MyOptions` objects, as well as making
all properties of `Options` available for internal methods in SymbolicRegression.jl
"""
abstract type AbstractOptions end

function create_expression end

end
