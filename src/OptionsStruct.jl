module OptionsStructModule

using Optim: Optim
using DynamicExpressions:
    AbstractOperatorEnum, AbstractExpressionNode, OperatorEnum, GenericOperatorEnum
using LossFunctions: SupervisedLoss

import ..MutationWeightsModule: MutationWeights

"""This struct defines how complexity is calculated."""
struct ComplexityMapping{T<:Real,VV<:Union{T,AbstractVector{T}}}
    """Whether we use custom complexity, or just use 1 for everythign"""
    use::Bool
    """Complexity of each binary operator."""
    binop_complexities::Vector{T}
    """Complexity of each unary operator."""
    unaop_complexities::Vector{T}
    """Complexity of using a variable."""
    variable_complexity::VV
    """Complexity of using a constant."""
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
    variable_complexity = T.(variable_complexity)
    return ComplexityMapping{T,typeof(variable_complexity)}(
        true,
        binop_complexities,
        unaop_complexities,
        variable_complexity,
        constant_complexity,
    )
end

function ComplexityMapping(
    ::Nothing, ::Nothing, ::Nothing, binary_operators, unary_operators
)
    # If no customization provided, then we simply
    # turn off the complexity mapping
    use = false
    return ComplexityMapping{Int,Int}(
        use, zeros(Int, 0), zeros(Int, 0), 0, 0
    )
end
function ComplexityMapping(
    complexity_of_operators,
    complexity_of_variables,
    complexity_of_constants,
    binary_operators,
    unary_operators,
)
    if complexity_of_operators === nothing
        complexity_of_operators = Dict()
    else
        # Convert to dict:
        complexity_of_operators = Dict(complexity_of_operators)
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
    OP_T = promote_type(typeof.(values(complexity_of_operators))...)

    T = promote_type(VAR_T, CONST_T, OP_T)

    # If not in dict, then just set it to 1.
    binop_complexities = T[
        (haskey(complexity_of_operators, op) ? complexity_of_operators[op] : 1) #
        for op in binary_operators
    ]
    unaop_complexities = T[
        (haskey(complexity_of_operators, op) ? complexity_of_operators[op] : 1) #
        for op in unary_operators
    ]

    variable_complexity = if complexity_of_variables !== nothing
        complexity_of_variables
    else
        1
    end
    constant_complexity = if complexity_of_constants !== nothing
        complexity_of_constants
    else
        1
    end

    return ComplexityMapping(;
        binop_complexities, unaop_complexities, variable_complexity, constant_complexity
    )
end

# Controls level of specialization we compile
function operator_specialization end
if VERSION >= v"1.10.0-DEV.0"
    @eval operator_specialization(::Type{<:OperatorEnum}) = OperatorEnum
else
    @eval operator_specialization(O::Type{<:OperatorEnum}) = O
end

struct Options{
    CT,OP<:AbstractOperatorEnum,N<:AbstractExpressionNode,_turbo,_bumper,_return_state,W
}
    operators::OP
    bin_constraints::Vector{Tuple{Int,Int}}
    una_constraints::Vector{Int}
    complexity_mapping::ComplexityMapping{CT}
    tournament_selection_n::Int
    tournament_selection_p::Float32
    tournament_selection_weights::W
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
    output_file::String
    populations::Int
    perturbation_factor::Float32
    annealing::Bool
    batching::Bool
    batch_size::Int
    mutation_weights::MutationWeights
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
    print_precision::Int
    save_to_file::Bool
    probability_negate_constant::Float32
    nuna::Int
    nbin::Int
    seed::Union{Int,Nothing}
    elementwise_loss::Union{SupervisedLoss,Function}
    loss_function::Union{Nothing,Function}
    node_type::Type{N}
    progress::Union{Bool,Nothing}
    terminal_width::Union{Int,Nothing}
    optimizer_algorithm::Optim.AbstractOptimizer
    optimizer_probability::Float32
    optimizer_nrestarts::Int
    optimizer_options::Optim.Options
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

function Base.print(io::IO, options::Options)
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
Base.show(io::IO, ::MIME"text/plain", options::Options) = Base.print(io, options)

end
