module OptionsStructModule

using DispatchDoctor: @unstable
using Optim: Optim
using DynamicExpressions:
    AbstractOperatorEnum, AbstractExpressionNode, AbstractExpression, OperatorEnum
using LossFunctions: SupervisedLoss

import ..MutationWeightsModule: AbstractMutationWeights

"""
This struct defines how complexity is calculated.

# Fields
- `use`: Shortcut indicating whether we use custom complexities,
    or just use 1 for everything.
- `binop_complexities`: Complexity of each binary operator.
- `unaop_complexities`: Complexity of each unary operator.
- `variable_complexity`: Complexity of using a variable.
- `constant_complexity`: Complexity of using a constant.
"""
struct ComplexityMapping{T<:Real,VC<:Union{T,AbstractVector{T}}}
    use::Bool
    binop_complexities::Vector{T}
    unaop_complexities::Vector{T}
    variable_complexity::VC
    constant_complexity::T
end

Base.eltype(::ComplexityMapping{T}) where {T} = T

"""Promote type when defining complexity mapping."""
function ComplexityMapping(;
    binop_complexities::Vector{T1},
    unaop_complexities::Vector{T2},
    variable_complexity::Union{T3,AbstractVector{T3}},
    constant_complexity::T4,
) where {T1<:Real,T2<:Real,T3<:Real,T4<:Real}
    T = promote_type(T1, T2, T3, T4)
    vc = map(T, variable_complexity)
    return ComplexityMapping{T,typeof(vc)}(
        true,
        map(T, binop_complexities),
        map(T, unaop_complexities),
        vc,
        T(constant_complexity),
    )
end

function ComplexityMapping(
    ::Nothing, ::Nothing, ::Nothing, binary_operators, unary_operators
)
    # If no customization provided, then we simply
    # turn off the complexity mapping
    use = false
    return ComplexityMapping{Int,Int}(use, zeros(Int, 0), zeros(Int, 0), 0, 0)
end
function ComplexityMapping(
    complexity_of_operators,
    complexity_of_variables,
    complexity_of_constants,
    binary_operators,
    unary_operators,
)
    _complexity_of_operators = if complexity_of_operators === nothing
        Dict{Function,Int64}()
    else
        # Convert to dict:
        Dict(complexity_of_operators)
    end

    VAR_T = if (complexity_of_variables !== nothing)
        if complexity_of_variables isa AbstractVector
            eltype(complexity_of_variables)
        else
            typeof(complexity_of_variables)
        end
    else
        Int
    end
    CONST_T = if (complexity_of_constants !== nothing)
        typeof(complexity_of_constants)
    else
        Int
    end
    OP_T = eltype(_complexity_of_operators).parameters[2]

    T = promote_type(VAR_T, CONST_T, OP_T)

    # If not in dict, then just set it to 1.
    binop_complexities = T[
        (haskey(_complexity_of_operators, op) ? _complexity_of_operators[op] : one(T)) #
        for op in binary_operators
    ]
    unaop_complexities = T[
        (haskey(_complexity_of_operators, op) ? _complexity_of_operators[op] : one(T)) #
        for op in unary_operators
    ]

    variable_complexity = if complexity_of_variables !== nothing
        map(T, complexity_of_variables)
    else
        one(T)
    end
    constant_complexity = if complexity_of_constants !== nothing
        map(T, complexity_of_constants)
    else
        one(T)
    end

    return ComplexityMapping(;
        binop_complexities, unaop_complexities, variable_complexity, constant_complexity
    )
end

"""
Controls level of specialization we compile into `Options`.

Overload if needed for custom expression types.
"""
operator_specialization(
    ::Type{O}, ::Type{<:AbstractExpression}
) where {O<:AbstractOperatorEnum} = O
@unstable operator_specialization(::Type{<:OperatorEnum}, ::Type{<:AbstractExpression}) =
    OperatorEnum

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

struct Options{
    CM<:Union{ComplexityMapping,Function},
    OP<:AbstractOperatorEnum,
    N<:AbstractExpressionNode,
    E<:AbstractExpression,
    EO<:NamedTuple,
    MW<:AbstractMutationWeights,
    _turbo,
    _bumper,
    _return_state,
    AD,
    print_precision,
} <: AbstractOptions
    operators::OP
    bin_constraints::Vector{Tuple{Int,Int}}
    una_constraints::Vector{Int}
    complexity_mapping::CM
    tournament_selection_n::Int
    tournament_selection_p::Float32
    parsimony::Float32
    dimensional_constraint_penalty::Union{Float32,Nothing}
    dimensionless_constants_only::Bool
    alpha::Float32
    maxsize::Int
    maxdepth::Int
    turbo::Val{_turbo}
    bumper::Val{_bumper}
    migration::Bool
    hof_migration::Bool
    should_simplify::Bool
    should_optimize_constants::Bool
    output_directory::Union{String,Nothing}
    populations::Int
    perturbation_factor::Float32
    annealing::Bool
    batching::Bool
    batch_size::Int
    mutation_weights::MW
    crossover_probability::Float32
    warmup_maxsize_by::Float32
    use_frequency::Bool
    use_frequency_in_tournament::Bool
    adaptive_parsimony_scaling::Float64
    population_size::Int
    ncycles_per_iteration::Int
    fraction_replaced::Float32
    fraction_replaced_hof::Float32
    topn::Int
    verbosity::Union{Int,Nothing}
    v_print_precision::Val{print_precision}
    save_to_file::Bool
    probability_negate_constant::Float32
    nuna::Int
    nbin::Int
    seed::Union{Int,Nothing}
    elementwise_loss::Union{SupervisedLoss,Function}
    loss_function::Union{Nothing,Function}
    node_type::Type{N}
    expression_type::Type{E}
    expression_options::EO
    progress::Union{Bool,Nothing}
    terminal_width::Union{Int,Nothing}
    optimizer_algorithm::Optim.AbstractOptimizer
    optimizer_probability::Float32
    optimizer_nrestarts::Int
    optimizer_options::Optim.Options
    autodiff_backend::AD
    recorder_file::String
    prob_pick_first::Float32
    early_stop_condition::Union{Function,Nothing}
    return_state::Val{_return_state}
    timeout_in_seconds::Union{Float64,Nothing}
    max_evals::Union{Int,Nothing}
    skip_mutation_failures::Bool
    nested_constraints::Union{Vector{Tuple{Int,Int,Vector{Tuple{Int,Int,Int}}}},Nothing}
    deterministic::Bool
    define_helper_functions::Bool
    use_recorder::Bool
end

function Base.print(io::IO, @nospecialize(options::Options))
    return print(
        io,
        "Options(" *
        "binops=$(options.operators.binops), " *
        "unaops=$(options.operators.unaops), "
        # Fill in remaining fields automatically:
        *
        join(
            [
                if fieldname in (:optimizer_options, :mutation_weights)
                    "$(fieldname)=..."
                else
                    "$(fieldname)=$(getfield(options, fieldname))"
                end for
                fieldname in fieldnames(Options) if fieldname ∉ [:operators, :nuna, :nbin]
            ],
            ", ",
        ) *
        ")",
    )
end
function Base.show(io::IO, ::MIME"text/plain", @nospecialize(options::Options))
    return Base.print(io, options)
end

specialized_options(options::AbstractOptions) = options
@unstable function specialized_options(options::Options)
    return _specialized_options(options, options.operators)
end
@generated function _specialized_options(
    options::O, operators::OP
) where {O<:Options,OP<:AbstractOperatorEnum}
    # Return an options struct with concrete operators
    type_parameters = O.parameters
    fields = Any[:(getfield(options, $(QuoteNode(k)))) for k in fieldnames(O)]
    quote
        Options{$(type_parameters[1]),$(OP),$(type_parameters[3:end]...)}($(fields...))
    end
end

end
