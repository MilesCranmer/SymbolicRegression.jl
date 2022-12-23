module OptionsModule

using Optim: Optim
import DynamicExpressions: OperatorEnum, Node, string_tree
import Distributed: nworkers
import LossFunctions: L2DistLoss
#TODO - eventually move some of these
# into the SR call itself, rather than
# passing huge options at once.
import ..OperatorsModule:
    plus,
    pow,
    safe_pow,
    mult,
    sub,
    div,
    safe_log,
    safe_log10,
    safe_log2,
    safe_log1p,
    safe_sqrt,
    safe_acosh,
    atanh_clip
import ..OptionsStructModule: Options, ComplexityMapping, MutationWeights, mutations
import ..UtilsModule: max_ops

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

function binopmap(op)
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

function unaopmap(op)
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
    :stateReturn => :return_state,
    :ns => :tournament_selection_n,
    :loss => :elementwise_loss,
])

"""
    Options(;kws...)

Construct options for `EquationSearch` and other functions.
The current arguments have been tuned using the median values from
https://github.com/MilesCranmer/PySR/discussions/115.

# Arguments
- `binary_operators`: Vector of binary operators (functions) to use.
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
    for a particular expression. Take a look at `_eval_loss` in
    the file `src/LossFunctions.jl` for an example.
- `npopulations`: How many populations of equations to use. By default
    this is set equal to the number of cores
- `npop`: How many equations in each population.
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
- `use_frequency`: Whether to use a parsimony that adapts to the
    relative proportion of equations at each complexity; this will
    ensure that there are a balanced number of equations considered
    for every complexity.
- `use_frequency_in_tournament`: Whether to use the adaptive parsimony described
    above inside the score, rather than just at the mutation accept/reject stage.
- `adaptive_parsimony_scaling`: How much to scale the adaptive parsimony term
    in the loss. Increase this if the search is spending too much time
    optimizing the most complex equations.
- `fast_cycle`: Whether to thread over subsamples of equations during
    regularized evolution. Slightly improves performance, but is a different
    algorithm.
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
function Options(;
    binary_operators=[+, -, /, *],
    unary_operators=[],
    constraints=nothing,
    elementwise_loss=nothing,
    loss_function=nothing,
    tournament_selection_n=12, #1 sampled from every tournament_selection_n per mutation
    tournament_selection_p=0.86f0,
    topn=12, #samples to return per population
    complexity_of_operators=nothing,
    complexity_of_constants::Union{Nothing,Real}=nothing,
    complexity_of_variables::Union{Nothing,Real}=nothing,
    parsimony=0.0032f0,
    alpha=0.100000f0,
    maxsize=20,
    maxdepth=nothing,
    fast_cycle=false,
    turbo=false,
    migration=true,
    hof_migration=true,
    should_optimize_constants=true,
    output_file=nothing,
    npopulations=15,
    perturbation_factor=0.076f0,
    annealing=false,
    batching=false,
    batch_size=50,
    mutation_weights::Union{MutationWeights,AbstractVector}=MutationWeights(),
    crossover_probability=0.066f0,
    warmup_maxsize_by=0.0f0,
    use_frequency=true,
    use_frequency_in_tournament=true,
    adaptive_parsimony_scaling=20.0,
    npop=33,
    ncycles_per_iteration=550,
    fraction_replaced=0.00036f0,
    fraction_replaced_hof=0.035f0,
    verbosity=convert(Int, 1e9),
    save_to_file=true,
    probability_negate_constant=0.01f0,
    seed=nothing,
    bin_constraints=nothing,
    una_constraints=nothing,
    progress=true,
    terminal_width=nothing,
    optimizer_algorithm="BFGS",
    optimizer_nrestarts=2,
    optimizer_probability=0.14f0,
    optimizer_iterations=nothing,
    optimizer_options::Union{Dict,NamedTuple,Optim.Options,Nothing}=nothing,
    recorder=nothing,
    recorder_file="pysr_recorder.json",
    early_stop_condition::Union{Function,Real,Nothing}=nothing,
    return_state::Bool=false,
    timeout_in_seconds=nothing,
    max_evals=nothing,
    skip_mutation_failures::Bool=true,
    enable_autodiff::Bool=false,
    nested_constraints=nothing,
    deterministic=false,
    # Not search options; just construction options:
    define_helper_functions=true,
    # Deprecated args:
    kws...,
)
    for k in keys(kws)
        !haskey(deprecated_options_mapping, k) && error("Unknown keyword argument: $k")
        new_key = deprecated_options_mapping[k]
        Base.depwarn(
            "The keyword argument `$(k)` is deprecated. Use `$(new_key)` instead.", :Options
        )
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
        k == :stateReturn && (return_state = kws[k]; true) && continue
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

    if elementwise_loss === nothing
        elementwise_loss = L2DistLoss()
    else
        if loss_function !== nothing
            error("You cannot specify both `elementwise_loss` and `loss_function`.")
        end
    end

    if output_file === nothing
        output_file = "hall_of_fame.csv" #TODO - put in date/time string here
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
        # TODO: This is redundant with the checks in EquationSearch
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
    if use_complexity_mapping
        if complexity_of_operators === nothing
            complexity_of_operators = Dict()
        else
            # Convert to dict:
            complexity_of_operators = Dict(complexity_of_operators)
        end

        # Get consistent type:
        promoted_type = promote_type(
            (complexity_of_variables !== nothing) ? typeof(complexity_of_variables) : Int,
            (complexity_of_constants !== nothing) ? typeof(complexity_of_constants) : Int,
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

        complexity_mapping = ComplexityMapping(;
            binop_complexities=binop_complexities,
            unaop_complexities=unaop_complexities,
            variable_complexity=variable_complexity,
            constant_complexity=constant_complexity,
        )
    else
        complexity_mapping = ComplexityMapping(false)
    end
    # Finish defining complexities

    if maxdepth === nothing
        maxdepth = maxsize
    end

    if npopulations === nothing
        npopulations = nworkers()
    end

    binary_operators = map(binopmap, binary_operators)
    unary_operators = map(unaopmap, unary_operators)

    operators = OperatorEnum(;
        binary_operators=binary_operators,
        unary_operators=unary_operators,
        enable_autodiff=enable_autodiff,
        define_helper_functions=define_helper_functions,
    )

    if progress
        verbosity = 0
    end

    if recorder === nothing
        recorder = haskey(ENV, "PYSR_RECORDER") && (ENV["PYSR_RECORDER"] == "1")
    end

    if typeof(early_stop_condition) <: Real
        # Need to make explicit copy here for this to work:
        stopping_point = Float64(early_stop_condition)
        early_stop_condition = (loss, complexity) -> loss < stopping_point
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

    options = Options{eltype(complexity_mapping)}(
        operators,
        bin_constraints,
        una_constraints,
        complexity_mapping,
        tournament_selection_n,
        tournament_selection_p,
        parsimony,
        alpha,
        maxsize,
        maxdepth,
        fast_cycle,
        turbo,
        migration,
        hof_migration,
        should_optimize_constants,
        output_file,
        npopulations,
        perturbation_factor,
        annealing,
        batching,
        batch_size,
        mutation_weights,
        crossover_probability,
        warmup_maxsize_by,
        use_frequency,
        use_frequency_in_tournament,
        adaptive_parsimony_scaling,
        npop,
        ncycles_per_iteration,
        fraction_replaced,
        fraction_replaced_hof,
        topn,
        verbosity,
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
        recorder,
        recorder_file,
        tournament_selection_p,
        early_stop_condition,
        return_state,
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
