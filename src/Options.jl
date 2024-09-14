module OptionsModule

using Optim: Optim
using Dates: Dates
using StatsBase: StatsBase
using DynamicExpressions: OperatorEnum, Node, string_tree
using Distributed: nworkers
using LossFunctions: L2DistLoss, SupervisedLoss
#TODO - eventually move some of these
# into the SR call itself, rather than
# passing huge options at once.
using ..OperatorsModule:
    plus,
    pow,
    safe_pow,
    mult,
    sub,
    safe_log,
    safe_log10,
    safe_log2,
    safe_log1p,
    safe_sqrt,
    safe_acosh,
    atanh_clip
import ..OptionsStructModule: Options
using ..OptionsStructModule: ComplexityMapping, MutationWeights, mutations
using ..UtilsModule: max_ops, @save_kwargs

"""
         build_constraints(una_constraints, bin_constraints,
                           unary_operators, binary_operators)

Build constraints on operator-level complexity from a user-passed dict.
"""
function build_constraints(
    una_constraints, bin_constraints, unary_operators, binary_operators, nuna, nbin
)::Tuple{Array{Int,1},Array{Tuple{Int,Int},1}}
    # Expect format ((*)=>(-1, 3)), etc.
    # TODO: Need to disable simplification if (*, -, +, /) are constrained?
    #  Or, just quit simplification is constraints violated.

    is_bin_constraints_already_done = typeof(bin_constraints) <: Array{Tuple{Int,Int},1}
    is_una_constraints_already_done = typeof(una_constraints) <: Array{Int,1}

    if typeof(bin_constraints) <: Array && !is_bin_constraints_already_done
        bin_constraints = Dict(bin_constraints)
    end
    if typeof(una_constraints) <: Array && !is_una_constraints_already_done
        una_constraints = Dict(una_constraints)
    end

    if una_constraints === nothing
        una_constraints = [-1 for i in 1:nuna]
    elseif !is_una_constraints_already_done
        una_constraints::Dict
        _una_constraints = Int[]
        for (i, op) in enumerate(unary_operators)
            did_user_declare_constraints = haskey(una_constraints, op)
            if did_user_declare_constraints
                constraint::Int = una_constraints[op]
                push!(_una_constraints, constraint)
            else
                push!(_una_constraints, -1)
            end
        end
        una_constraints = _una_constraints
    end
    if bin_constraints === nothing
        bin_constraints = [(-1, -1) for i in 1:nbin]
    elseif !is_bin_constraints_already_done
        bin_constraints::Dict
        _bin_constraints = Tuple{Int,Int}[]
        for (i, op) in enumerate(binary_operators)
            did_user_declare_constraints = haskey(bin_constraints, op)
            if did_user_declare_constraints
                constraint::Tuple{Int,Int} = bin_constraints[op]
                push!(_bin_constraints, constraint)
            else
                push!(_bin_constraints, (-1, -1))
            end
        end
        bin_constraints = _bin_constraints
    end

    return una_constraints, bin_constraints
end

function binopmap(op::F) where {F}
    if op == plus
        return +
    elseif op == mult
        return *
    elseif op == sub
        return -
    elseif op == div
        return /
    elseif op == ^
        return safe_pow
    elseif op == pow
        return safe_pow
    end
    return op
end
function inverse_binopmap(op::F) where {F}
    if op == safe_pow
        return ^
    end
    return op
end

function unaopmap(op::F) where {F}
    if op == log
        return safe_log
    elseif op == log10
        return safe_log10
    elseif op == log2
        return safe_log2
    elseif op == log1p
        return safe_log1p
    elseif op == sqrt
        return safe_sqrt
    elseif op == acosh
        return safe_acosh
    elseif op == atanh
        return atanh_clip
    end
    return op
end
function inverse_unaopmap(op::F) where {F}
    if op == safe_log
        return log
    elseif op == safe_log10
        return log10
    elseif op == safe_log2
        return log2
    elseif op == safe_log1p
        return log1p
    elseif op == safe_sqrt
        return sqrt
    elseif op == safe_acosh
        return acosh
    elseif op == atanh_clip
        return atanh
    end
    return op
end

const deprecated_options_mapping = NamedTuple([
    :mutationWeights => :mutation_weights,
    :hofMigration => :hof_migration,
    :shouldOptimizeConstants => :should_optimize_constants,
    :hofFile => :output_file,
    :perturbationFactor => :perturbation_factor,
    :batchSize => :batch_size,
    :crossoverProbability => :crossover_probability,
    :warmupMaxsizeBy => :warmup_maxsize_by,
    :useFrequency => :use_frequency,
    :useFrequencyInTournament => :use_frequency_in_tournament,
    :ncyclesperiteration => :ncycles_per_iteration,
    :fractionReplaced => :fraction_replaced,
    :fractionReplacedHof => :fraction_replaced_hof,
    :probNegate => :probability_negate_constant,
    :optimize_probability => :optimizer_probability,
    :probPickFirst => :tournament_selection_p,
    :earlyStopCondition => :early_stop_condition,
    :stateReturn => :deprecated_return_state,
    :return_state => :deprecated_return_state,
    :ns => :tournament_selection_n,
    :loss => :elementwise_loss,
])

const OPTION_DESCRIPTIONS = """- `binary_operators`: Vector of binary operators (functions) to use.
    Each operator should be defined for two input scalars,
    and one output scalar. All operators
    need to be defined over the entire real line (excluding infinity - these
    are stopped before they are input), or return `NaN` where not defined.
    For speed, define it so it takes two reals
    of the same type as input, and outputs the same type. For the SymbolicUtils
    simplification backend, you will need to define a generic method of the
    operator so it takes arbitrary types.
- `unary_operators`: Same, but for
    unary operators (one input scalar, gives an output scalar).
- `constraints`: Array of pairs specifying size constraints
    for each operator. The constraints for a binary operator should be a 2-tuple
    (e.g., `(-1, -1)`) and the constraints for a unary operator should be an `Int`.
    A size constraint is a limit to the size of the subtree
    in each argument of an operator. e.g., `[(^)=>(-1, 3)]` means that the
    `^` operator can have arbitrary size (`-1`) in its left argument,
    but a maximum size of `3` in its right argument. Default is
    no constraints.
- `batching`: Whether to evolve based on small mini-batches of data,
    rather than the entire dataset.
- `batch_size`: What batch size to use if using batching.
- `elementwise_loss`: What elementwise loss function to use. Can be one of
    the following losses, or any other loss of type
    `SupervisedLoss`. You can also pass a function that takes
    a scalar target (left argument), and scalar predicted (right
    argument), and returns a scalar. This will be averaged
    over the predicted data. If weights are supplied, your
    function should take a third argument for the weight scalar.
    Included losses:
        Regression:
            - `LPDistLoss{P}()`,
            - `L1DistLoss()`,
            - `L2DistLoss()` (mean square),
            - `LogitDistLoss()`,
            - `HuberLoss(d)`,
            - `L1EpsilonInsLoss(ϵ)`,
            - `L2EpsilonInsLoss(ϵ)`,
            - `PeriodicLoss(c)`,
            - `QuantileLoss(τ)`,
        Classification:
            - `ZeroOneLoss()`,
            - `PerceptronLoss()`,
            - `L1HingeLoss()`,
            - `SmoothedL1HingeLoss(γ)`,
            - `ModifiedHuberLoss()`,
            - `L2MarginLoss()`,
            - `ExpLoss()`,
            - `SigmoidLoss()`,
            - `DWDMarginLoss(q)`.
- `loss_function`: Alternatively, you may redefine the loss used
    as any function of `tree::Node{T}`, `dataset::Dataset{T}`,
    and `options::Options`, so long as you output a non-negative
    scalar of type `T`. This is useful if you want to use a loss
    that takes into account derivatives, or correlations across
    the dataset. This also means you could use a custom evaluation
    for a particular expression. If you are using
    `batching=true`, then your function should
    accept a fourth argument `idx`, which is either `nothing`
    (indicating that the full dataset should be used), or a vector
    of indices to use for the batch.
    For example,

        function my_loss(tree, dataset::Dataset{T,L}, options)::L where {T,L}
            prediction, flag = eval_tree_array(tree, dataset.X, options)
            if !flag
                return L(Inf)
            end
            return sum((prediction .- dataset.y) .^ 2) / dataset.n
        end

- `populations`: How many populations of equations to use.
- `population_size`: How many equations in each population.
- `ncycles_per_iteration`: How many generations to consider per iteration.
- `tournament_selection_n`: Number of expressions considered in each tournament.
- `tournament_selection_p`: The fittest expression in a tournament is to be
    selected with probability `p`, the next fittest with probability `p*(1-p)`,
    and so forth.
- `topn`: Number of equations to return to the host process, and to
    consider for the hall of fame.
- `complexity_of_operators`: What complexity should be assigned to each operator,
    and the occurrence of a constant or variable. By default, this is 1
    for all operators. Can be a real number as well, in which case
    the complexity of an expression will be rounded to the nearest integer.
    Input this in the form of, e.g., [(^) => 3, sin => 2].
- `complexity_of_constants`: What complexity should be assigned to use of a constant.
    By default, this is 1.
- `complexity_of_variables`: What complexity should be assigned to each variable.
    By default, this is 1.
- `alpha`: The probability of accepting an equation mutation
    during regularized evolution is given by exp(-delta_loss/(alpha * T)),
    where T goes from 1 to 0. Thus, alpha=infinite is the same as no annealing.
- `maxsize`: Maximum size of equations during the search.
- `maxdepth`: Maximum depth of equations during the search, by default
    this is set equal to the maxsize.
- `parsimony`: A multiplicative factor for how much complexity is
    punished.
- `dimensional_constraint_penalty`: An additive factor if the dimensional
    constraint is violated.
- `use_frequency`: Whether to use a parsimony that adapts to the
    relative proportion of equations at each complexity; this will
    ensure that there are a balanced number of equations considered
    for every complexity.
- `use_frequency_in_tournament`: Whether to use the adaptive parsimony described
    above inside the score, rather than just at the mutation accept/reject stage.
- `adaptive_parsimony_scaling`: How much to scale the adaptive parsimony term
    in the loss. Increase this if the search is spending too much time
    optimizing the most complex equations.
- `turbo`: Whether to use `LoopVectorization.@turbo` to evaluate expressions.
    This can be significantly faster, but is only compatible with certain
    operators. *Experimental!*
- `migration`: Whether to migrate equations between processes.
- `hof_migration`: Whether to migrate equations from the hall of fame
    to processes.
- `fraction_replaced`: What fraction of each population to replace with
    migrated equations at the end of each cycle.
- `fraction_replaced_hof`: What fraction to replace with hall of fame
    equations at the end of each cycle.
- `should_simplify`: Whether to simplify equations. If you
    pass a custom objective, this will be set to `false`.
- `should_optimize_constants`: Whether to use an optimization algorithm
    to periodically optimize constants in equations.
- `optimizer_nrestarts`: How many different random starting positions to consider
    for optimization of constants.
- `optimizer_algorithm`: Select algorithm to use for optimizing constants. Default
    is "BFGS", but "NelderMead" is also supported.
- `optimizer_options`: General options for the constant optimization. For details
    we refer to the documentation on `Optim.Options` from the `Optim.jl` package.
    Options can be provided here as `NamedTuple`, e.g. `(iterations=16,)`, as a
    `Dict`, e.g. Dict(:x_tol => 1.0e-32,), or as an `Optim.Options` instance.
- `output_file`: What file to store equations to, as a backup.
- `perturbation_factor`: When mutating a constant, either
    multiply or divide by (1+perturbation_factor)^(rand()+1).
- `probability_negate_constant`: Probability of negating a constant in the equation
    when mutating it.
- `mutation_weights`: Relative probabilities of the mutations. The struct
    `MutationWeights` should be passed to these options.
    See its documentation on `MutationWeights` for the different weights.
- `crossover_probability`: Probability of performing crossover.
- `annealing`: Whether to use simulated annealing.
- `warmup_maxsize_by`: Whether to slowly increase the max size from 5 up to
    `maxsize`. If nonzero, specifies the fraction through the search
    at which the maxsize should be reached.
- `verbosity`: Whether to print debugging statements or
    not.
- `print_precision`: How many digits to print when printing
    equations. By default, this is 5.
- `save_to_file`: Whether to save equations to a file during the search.
- `bin_constraints`: See `constraints`. This is the same, but specified for binary
    operators only (for example, if you have an operator that is both a binary
    and unary operator).
- `una_constraints`: Likewise, for unary operators.
- `seed`: What random seed to use. `nothing` uses no seed.
- `progress`: Whether to use a progress bar output (`verbosity` will
    have no effect).
- `early_stop_condition`: Float - whether to stop early if the mean loss gets below this value.
    Function - a function taking (loss, complexity) as arguments and returning true or false.
- `timeout_in_seconds`: Float64 - the time in seconds after which to exit (as an alternative to the number of iterations).
- `max_evals`: Int (or Nothing) - the maximum number of evaluations of expressions to perform.
- `skip_mutation_failures`: Whether to simply skip over mutations that fail or are rejected, rather than to replace the mutated
    expression with the original expression and proceed normally.
- `enable_autodiff`: Whether to enable automatic differentiation functionality. This is turned off by default.
    If turned on, this will be turned off if one of the operators does not have well-defined gradients.
- `nested_constraints`: Specifies how many times a combination of operators can be nested. For example,
    `[sin => [cos => 0], cos => [cos => 2]]` specifies that `cos` may never appear within a `sin`,
    but `sin` can be nested with itself an unlimited number of times. The second term specifies that `cos`
    can be nested up to 2 times within a `cos`, so that `cos(cos(cos(x)))` is allowed (as well as any combination
    of `+` or `-` within it), but `cos(cos(cos(cos(x))))` is not allowed. When an operator is not specified,
    it is assumed that it can be nested an unlimited number of times. This requires that there is no operator
    which is used both in the unary operators and the binary operators (e.g., `-` could be both subtract, and negation).
    For binary operators, both arguments are treated the same way, and the max of each argument is constrained.
- `deterministic`: Use a global counter for the birth time, rather than calls to `time()`. This gives
    perfect resolution, and is therefore deterministic. However, it is not thread safe, and must be used
    in serial mode.
- `define_helper_functions`: Whether to define helper functions
    for constructing and evaluating trees.
"""

"""
    Options(;kws...)

Construct options for `equation_search` and other functions.
The current arguments have been tuned using the median values from
https://github.com/MilesCranmer/PySR/discussions/115.

# Arguments
$(OPTION_DESCRIPTIONS)
"""
function Options end
@save_kwargs DEFAULT_OPTIONS function Options(;
    binary_operators=[+, -, /, *],
    unary_operators=[],
    constraints=nothing,
    elementwise_loss::Union{Function,SupervisedLoss,Nothing}=nothing,
    loss_function::Union{Function,Nothing}=nothing,
    tournament_selection_n::Integer=12, #1 sampled from every tournament_selection_n per mutation
    tournament_selection_p::Real=0.86,
    topn::Integer=12, #samples to return per population
    complexity_of_operators=nothing,
    complexity_of_constants::Union{Nothing,Real}=nothing,
    complexity_of_variables::Union{Nothing,Real}=nothing,
    parsimony::Real=0.0032,
    dimensional_constraint_penalty::Union{Nothing,Real}=nothing,
    alpha::Real=0.100000,
    maxsize::Integer=20,
    maxdepth::Union{Nothing,Integer}=nothing,
    turbo::Bool=false,
    migration::Bool=true,
    hof_migration::Bool=true,
    should_simplify::Union{Nothing,Bool}=nothing,
    should_optimize_constants::Bool=true,
    output_file::Union{Nothing,AbstractString}=nothing,
    populations::Integer=15,
    perturbation_factor::Real=0.076,
    annealing::Bool=false,
    batching::Bool=false,
    batch_size::Integer=50,
    allocation::Bool=false,
    eval_probability::Bool=false,
    adjmatrix::Union{Nothing, Array{Float64,2}}=nothing,
    ori_sep::Union{Nothing, Array{Int}}=nothing,
    optimize_hof::Bool=false,
    mutation_weights::Union{MutationWeights,AbstractVector,NamedTuple}=MutationWeights(),
    crossover_probability::Real=0.066,
    warmup_maxsize_by::Real=0.0,
    use_frequency::Bool=true,
    use_frequency_in_tournament::Bool=true,
    adaptive_parsimony_scaling::Real=20.0,
    population_size::Integer=33,
    ncycles_per_iteration::Integer=550,
    fraction_replaced::Real=0.00036,
    fraction_replaced_hof::Real=0.035,
    verbosity::Union{Integer,Nothing}=nothing,
    print_precision::Integer=5,
    save_to_file::Bool=true,
    probability_negate_constant::Real=0.01,
    seed=nothing,
    bin_constraints=nothing,
    una_constraints=nothing,
    progress::Union{Bool,Nothing}=nothing,
    terminal_width::Union{Nothing,Integer}=nothing,
    optimizer_algorithm::AbstractString="BFGS",
    optimizer_nrestarts::Integer=2,
    optimizer_probability::Real=0.14,
    optimizer_iterations::Union{Nothing,Integer}=nothing,
    optimizer_options::Union{Dict,NamedTuple,Optim.Options,Nothing}=nothing,
    val_recorder::Val{use_recorder}=Val(false),
    recorder_file::AbstractString="pysr_recorder.json",
    early_stop_condition::Union{Function,Real,Nothing}=nothing,
    timeout_in_seconds::Union{Nothing,Real}=nothing,
    max_evals::Union{Nothing,Integer}=nothing,
    skip_mutation_failures::Bool=true,
    enable_autodiff::Bool=false,
    nested_constraints=nothing,
    deterministic::Bool=false,
    # Not search options; just construction options:
    define_helper_functions::Bool=true,
    deprecated_return_state=nothing,
    # Deprecated args:
    fast_cycle::Bool=false,
    npopulations::Union{Nothing,Integer}=nothing,
    npop::Union{Nothing,Integer}=nothing,
    kws...,
) where {use_recorder}
    for k in keys(kws)
        !haskey(deprecated_options_mapping, k) && error("Unknown keyword argument: $k")
        new_key = deprecated_options_mapping[k]
        if startswith(string(new_key), "deprecated_")
            Base.depwarn("The keyword argument `$(k)` is deprecated.", :Options)
        else
            Base.depwarn(
                "The keyword argument `$(k)` is deprecated. Use `$(new_key)` instead.",
                :Options,
            )
        end
        # Now, set the new key to the old value:
        #! format: off
        k == :hofMigration && (hof_migration = kws[k]; true) && continue
        k == :shouldOptimizeConstants && (should_optimize_constants = kws[k]; true) && continue
        k == :hofFile && (output_file = kws[k]; true) && continue
        k == :perturbationFactor && (perturbation_factor = kws[k]; true) && continue
        k == :batchSize && (batch_size = kws[k]; true) && continue
        k == :crossoverProbability && (crossover_probability = kws[k]; true) && continue
        k == :warmupMaxsizeBy && (warmup_maxsize_by = kws[k]; true) && continue
        k == :useFrequency && (use_frequency = kws[k]; true) && continue
        k == :useFrequencyInTournament && (use_frequency_in_tournament = kws[k]; true) && continue
        k == :ncyclesperiteration && (ncycles_per_iteration = kws[k]; true) && continue
        k == :fractionReplaced && (fraction_replaced = kws[k]; true) && continue
        k == :fractionReplacedHof && (fraction_replaced_hof = kws[k]; true) && continue
        k == :probNegate && (probability_negate_constant = kws[k]; true) && continue
        k == :optimize_probability && (optimizer_probability = kws[k]; true) && continue
        k == :probPickFirst && (tournament_selection_p = kws[k]; true) && continue
        k == :earlyStopCondition && (early_stop_condition = kws[k]; true) && continue
        k == :return_state && (deprecated_return_state = kws[k]; true) && continue
        k == :stateReturn && (deprecated_return_state = kws[k]; true) && continue
        k == :ns && (tournament_selection_n = kws[k]; true) && continue
        k == :loss && (elementwise_loss = kws[k]; true) && continue
        if k == :mutationWeights
            if typeof(kws[k]) <: AbstractVector
                _mutation_weights = kws[k]
                if length(_mutation_weights) < length(mutations)
                    # Pad with zeros:
                    _mutation_weights = vcat(
                        _mutation_weights,
                        zeros(length(mutations) - length(_mutation_weights))
                    )
                end
                mutation_weights = MutationWeights(_mutation_weights...)
            else
                mutation_weights = kws[k]
            end
            continue
        end
        #! format: on
        error(
            "Unknown deprecated keyword argument: $k. Please update `Options(;)` to transfer this key.",
        )
    end
    fast_cycle && Base.depwarn("`fast_cycle` is deprecated and has no effect.", :Options)
    if npop !== nothing
        Base.depwarn("`npop` is deprecated. Use `population_size` instead.", :Options)
        population_size = npop
    end
    if npopulations !== nothing
        Base.depwarn("`npopulations` is deprecated. Use `populations` instead.", :Options)
        populations = npopulations
    end

    if elementwise_loss === nothing
        elementwise_loss = L2DistLoss()
    else
        if loss_function !== nothing
            error("You cannot specify both `elementwise_loss` and `loss_function`.")
        end
    end

    if should_simplify === nothing
        should_simplify = (
            loss_function === nothing &&
            nested_constraints === nothing &&
            constraints === nothing &&
            bin_constraints === nothing &&
            una_constraints === nothing
        )
    end

    if output_file === nothing
        # "%Y-%m-%d_%H%M%S.%f"
        date_time_str = Dates.format(Dates.now(), "yyyy-mm-dd_HHMMSS.sss")
        output_file = "hall_of_fame_" * date_time_str * ".csv"
    end

    nuna = length(unary_operators)
    nbin = length(binary_operators)
    @assert maxsize > 3
    @assert warmup_maxsize_by >= 0.0f0
    @assert nuna <= max_ops && nbin <= max_ops

    # Make sure nested_constraints contains functions within our operator set:
    if nested_constraints !== nothing
        # Check that intersection of binary operators and unary operators is empty:
        for op in binary_operators
            if op ∈ unary_operators
                error(
                    "Operator $(op) is both a binary and unary operator. " *
                    "You can't use nested constraints.",
                )
            end
        end

        # Convert to dict:
        if !(typeof(nested_constraints) <: Dict)
            # Convert to dict:
            nested_constraints = Dict(
                [cons[1] => Dict(cons[2]...) for cons in nested_constraints]...
            )
        end
        for (op, nested_constraint) in nested_constraints
            if !(op ∈ binary_operators || op ∈ unary_operators)
                error("Operator $(op) is not in the operator set.")
            end
            for (nested_op, max_nesting) in nested_constraint
                if !(nested_op ∈ binary_operators || nested_op ∈ unary_operators)
                    error("Operator $(nested_op) is not in the operator set.")
                end
                @assert nested_op ∈ binary_operators || nested_op ∈ unary_operators
                @assert max_nesting >= -1 && typeof(max_nesting) <: Int
            end
        end

        # Lastly, we clean it up into a dict of (degree,op_idx) => max_nesting.
        new_nested_constraints = []
        # Dict()
        for (op, nested_constraint) in nested_constraints
            (degree, idx) = if op ∈ binary_operators
                2, findfirst(isequal(op), binary_operators)
            else
                1, findfirst(isequal(op), unary_operators)
            end
            new_max_nesting_dict = []
            # Dict()
            for (nested_op, max_nesting) in nested_constraint
                (nested_degree, nested_idx) = if nested_op ∈ binary_operators
                    2, findfirst(isequal(nested_op), binary_operators)
                else
                    1, findfirst(isequal(nested_op), unary_operators)
                end
                # new_max_nesting_dict[(nested_degree, nested_idx)] = max_nesting
                push!(new_max_nesting_dict, (nested_degree, nested_idx, max_nesting))
            end
            # new_nested_constraints[(degree, idx)] = new_max_nesting_dict
            push!(new_nested_constraints, (degree, idx, new_max_nesting_dict))
        end
        nested_constraints = new_nested_constraints
    end

    if typeof(constraints) <: Tuple
        constraints = collect(constraints)
    end
    if constraints !== nothing
        @assert bin_constraints === nothing
        @assert una_constraints === nothing
        # TODO: This is redundant with the checks in equation_search
        for op in binary_operators
            @assert !(op in unary_operators)
        end
        for op in unary_operators
            @assert !(op in binary_operators)
        end
        bin_constraints = constraints
        una_constraints = constraints
    end

    una_constraints, bin_constraints = build_constraints(
        una_constraints, bin_constraints, unary_operators, binary_operators, nuna, nbin
    )

    # Define the complexities of everything.
    use_complexity_mapping = (
        complexity_of_constants !== nothing ||
        complexity_of_variables !== nothing ||
        complexity_of_operators !== nothing
    )
    complexity_mapping = if use_complexity_mapping
        if complexity_of_operators === nothing
            complexity_of_operators = Dict()
        else
            # Convert to dict:
            complexity_of_operators = Dict(complexity_of_operators)
        end

        # Get consistent type:
        promoted_type = promote_type(
            if (complexity_of_variables !== nothing)
                typeof(complexity_of_variables)
            else
                Int
            end,
            if (complexity_of_constants !== nothing)
                typeof(complexity_of_constants)
            else
                Int
            end,
            (x -> typeof(x)).(values(complexity_of_operators))...,
        )

        # If not in dict, then just set it to 1.
        binop_complexities = promoted_type[
            (haskey(complexity_of_operators, op) ? complexity_of_operators[op] : 1) #
            for op in binary_operators
        ]
        unaop_complexities = promoted_type[
            (haskey(complexity_of_operators, op) ? complexity_of_operators[op] : 1) #
            for op in unary_operators
        ]

        variable_complexity = (
            (complexity_of_variables !== nothing) ? complexity_of_variables : 1
        )
        constant_complexity = (
            (complexity_of_constants !== nothing) ? complexity_of_constants : 1
        )

        ComplexityMapping(;
            binop_complexities=binop_complexities,
            unaop_complexities=unaop_complexities,
            variable_complexity=variable_complexity,
            constant_complexity=constant_complexity,
        )
    else
        ComplexityMapping(false)
    end
    # Finish defining complexities

    if maxdepth === nothing
        maxdepth = maxsize
    end

    if define_helper_functions
        # We call here so that mapped operators, like ^
        # are correctly overloaded, rather than overloading
        # operators like "safe_pow", etc.
        OperatorEnum(;
            binary_operators=binary_operators,
            unary_operators=unary_operators,
            enable_autodiff=false,  # Not needed; we just want the constructors
            define_helper_functions=true,
            empty_old_operators=true,
        )
    end

    binary_operators = map(binopmap, binary_operators)
    unary_operators = map(unaopmap, unary_operators)

    operators = OperatorEnum(;
        binary_operators=binary_operators,
        unary_operators=unary_operators,
        enable_autodiff=enable_autodiff,
        define_helper_functions=define_helper_functions,
        empty_old_operators=false,
    )

    early_stop_condition = if typeof(early_stop_condition) <: Real
        # Need to make explicit copy here for this to work:
        stopping_point = Float64(early_stop_condition)
        (loss, complexity) -> loss < stopping_point
    else
        early_stop_condition
    end

    # Parse optimizer options
    default_optimizer_iterations = 8
    if !isa(optimizer_options, Optim.Options)
        if isnothing(optimizer_iterations)
            optimizer_iterations = default_optimizer_iterations
        end
        if isnothing(optimizer_options)
            optimizer_options = Optim.Options(; iterations=optimizer_iterations)
        else
            if haskey(optimizer_options, :iterations)
                optimizer_iterations = optimizer_options[:iterations]
            end
            optimizer_options = Optim.Options(;
                optimizer_options..., iterations=optimizer_iterations
            )
        end
    end

    ## Create tournament weights:6
    tournament_selection_weights =
        let n = tournament_selection_n, p = tournament_selection_p
            k = collect(0:(n - 1))
            prob_each = p * ((1 - p) .^ k)

            StatsBase.Weights(prob_each, sum(prob_each))
        end

    # Create mutation weights:
    set_mutation_weights = if typeof(mutation_weights) <: NamedTuple
        MutationWeights(; mutation_weights...)
    else
        mutation_weights
    end

    @assert print_precision > 0

    # Allocation mode requires ori_sep
    if allocation  
        if ori_sep !== nothing
            num_places = size(ori_sep, 1) 
            pushfirst!(ori_sep, 0)
        else
            @assert adjmat !== nothing
            @assert size(adjmatrix, 1) == size(adjmatrix, 2)
            num_places = size(adjmatrix, 1)
            ori_sep = Vector{Int}()
            push!(ori_sep, 0)
            flow_count = 0
            for id_origin in 1:n_places
                id_dest = findall(adjmatrix[id_origin, :] .> 0)
                flow_count += length(id_dest)
                push!(partition, flow_count)
            end
        end
    else
        num_places = -1
    end

    options = Options{
        eltype(complexity_mapping),
        typeof(operators),
        use_recorder,
        typeof(optimizer_options),
        typeof(tournament_selection_weights),
    }(
        operators,
        bin_constraints,
        una_constraints,
        complexity_mapping,
        tournament_selection_n,
        tournament_selection_p,
        tournament_selection_weights,
        parsimony,
        dimensional_constraint_penalty,
        alpha,
        maxsize,
        maxdepth,
        turbo,
        migration,
        hof_migration,
        should_simplify,
        should_optimize_constants,
        output_file,
        populations,
        perturbation_factor,
        annealing,
        batching,
        batch_size,
        allocation,
        eval_probability,
        ori_sep,
        num_places,
        optimize_hof,
        set_mutation_weights,
        crossover_probability,
        warmup_maxsize_by,
        use_frequency,
        use_frequency_in_tournament,
        adaptive_parsimony_scaling,
        population_size,
        ncycles_per_iteration,
        fraction_replaced,
        fraction_replaced_hof,
        topn,
        verbosity,
        print_precision,
        save_to_file,
        probability_negate_constant,
        nuna,
        nbin,
        seed,
        elementwise_loss,
        loss_function,
        progress,
        terminal_width,
        optimizer_algorithm,
        optimizer_probability,
        optimizer_nrestarts,
        optimizer_options,
        recorder_file,
        tournament_selection_p,
        early_stop_condition,
        deprecated_return_state,
        timeout_in_seconds,
        max_evals,
        skip_mutation_failures,
        nested_constraints,
        deterministic,
        define_helper_functions,
    )

    return options
end

end
