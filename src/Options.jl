module OptionsModule

using DispatchDoctor: @unstable
using Optim: Optim
using DynamicExpressions:
    OperatorEnum,
    AbstractOperatorEnum,
    Expression,
    default_node_type,
    AbstractExpression,
    AbstractExpressionNode
using DynamicExpressions.NodeModule: has_max_degree, with_max_degree
using ADTypes: AbstractADType, ADTypes
using LossFunctions: L2DistLoss, SupervisedLoss
using Optim: Optim
using LineSearches: LineSearches
#TODO - eventually move some of these
# into the SR call itself, rather than
# passing huge options at once.
using ..OperatorsModule:
    plus,
    pow,
    safe_pow,
    mult,
    sub,
    greater,
    less,
    greater_equal,
    less_equal,
    safe_log,
    safe_log10,
    safe_log2,
    safe_log1p,
    safe_sqrt,
    safe_asin,
    safe_acos,
    safe_acosh,
    safe_atanh
using ..MutationWeightsModule: AbstractMutationWeights, MutationWeights, mutations
import ..OptionsStructModule: Options
using ..OptionsStructModule: ComplexityMapping, operator_specialization
using ..UtilsModule: @save_kwargs, @ignore
using ..ExpressionSpecModule:
    AbstractExpressionSpec,
    ExpressionSpec,
    get_expression_type,
    get_expression_options,
    get_node_type

"""Build constraints on operator-level complexity from a user-passed dict."""
@unstable function build_constraints(;
    constraints=nothing,
    una_constraints=nothing,
    bin_constraints=nothing,
    @nospecialize(operators_by_degree::Tuple{Vararg{Any,D}})
) where {D}
    constraints = if constraints !== nothing
        @assert all(isnothing, (una_constraints, bin_constraints))
        constraints
    elseif any(!isnothing, (una_constraints, bin_constraints))
        (una_constraints, bin_constraints)
    else
        ntuple(i -> nothing, Val(D))
    end
    return _build_constraints(constraints, operators_by_degree)
end
@unstable function _build_constraints(
    constraints, @nospecialize(operators_by_degree::Tuple{Vararg{Any,D}})
) where {D}
    # Expect format ((*)=>(-1, 3)), etc.

    is_constraints_already_done = ntuple(Val(D)) do i
        i == 1 && constraints[i] isa Vector{Int} ||
            i > 1 && constraints[i] isa Vector{NTuple{i,Int}}
    end

    _op_constraints = ntuple(Val(D)) do i
        if constraints[i] isa Array && !is_constraints_already_done[i]
            Dict(constraints[i])
        else
            constraints[i]
        end
    end

    return ntuple(Val(D)) do i
        let default_value = i == 1 ? -1 : ntuple(j -> -1, i)
            if isnothing(_op_constraints[i])
                fill(default_value, length(operators_by_degree[i]))
            elseif !is_constraints_already_done[i]
                typeof(default_value)[
                    get(_op_constraints[i], op, default_value) for
                    op in operators_by_degree[i]
                ]
            else
                _op_constraints[i]::Vector{typeof(default_value)}
            end
        end
    end
end

@unstable function build_nested_constraints(;
    nested_constraints, @nospecialize(operators_by_degree)
)
    nested_constraints === nothing && return nested_constraints

    # Check that no operator appears in multiple degrees:
    all_operators = Set()
    for ops in operators_by_degree, op in ops
        if op ∈ all_operators
            error(
                "Operator $(op) appears in multiple degrees. " *
                "You can't use nested constraints.",
            )
        end
        push!(all_operators, op)
    end

    # Convert to dict:
    _nested_constraints = if nested_constraints isa Dict
        nested_constraints
    else
        # Convert to dict:
        nested_constraints = Dict(
            [cons[1] => Dict(cons[2]...) for cons in nested_constraints]...
        )
    end

    for (op, nested_constraint) in _nested_constraints
        if !(op ∈ all_operators)
            error("Operator $(op) is not in the operator set.")
        end
        for (nested_op, max_nesting) in nested_constraint
            if !(nested_op ∈ all_operators)
                error("Operator $(nested_op) is not in the operator set.")
            end
            @assert max_nesting >= -1 && typeof(max_nesting) <: Int
        end
    end

    # Lastly, we clean it up into a dict of (degree,op_idx) => max_nesting.
    return [
        let (degree, idx) = begin
                found_degree = 0
                found_idx = 0
                for (d, ops) in enumerate(operators_by_degree)
                    idx_in_degree = findfirst(isequal(op), ops)
                    if idx_in_degree !== nothing
                        found_degree = d
                        found_idx = idx_in_degree
                        break
                    end
                end
                found_degree == 0 && error("Operator $(op) is not in the operator set.")
                (found_degree, found_idx)
            end,
            new_max_nesting_dict = [
                let (nested_degree, nested_idx) = begin
                        found_degree = 0
                        found_idx = 0
                        for (d, ops) in enumerate(operators_by_degree)
                            idx_in_degree = findfirst(isequal(nested_op), ops)
                            if idx_in_degree !== nothing
                                found_degree = d
                                found_idx = idx_in_degree
                                break
                            end
                        end
                        found_degree == 0 &&
                        error("Operator $(nested_op) is not in the operator set.")
                        (found_degree, found_idx)
                    end
                    (nested_degree, nested_idx, max_nesting)
                end for (nested_op, max_nesting) in nested_constraint
            ]

            (degree, idx, new_max_nesting_dict)
        end for (op, nested_constraint) in _nested_constraints
    ]
end

const OP_MAP = Dict{Any,Any}(
    plus => (+),
    mult => (*),
    sub => (-),
    div => (/),
    (^) => safe_pow,
    pow => safe_pow,
    Base.:(>) => greater,
    Base.:(<) => less,
    Base.:(>=) => greater_equal,
    Base.:(<=) => less_equal,
    log => safe_log,
    log10 => safe_log10,
    log2 => safe_log2,
    log1p => safe_log1p,
    sqrt => safe_sqrt,
    asin => safe_asin,
    acos => safe_acos,
    acosh => safe_acosh,
    atanh => safe_atanh,
)
const INVERSE_OP_MAP = Dict{Any,Any}(
    safe_pow => (^),
    greater => Base.:(>),
    less => Base.:(<),
    greater_equal => Base.:(>=),
    less_equal => Base.:(<=),
    safe_log => log,
    safe_log10 => log10,
    safe_log2 => log2,
    safe_log1p => log1p,
    safe_sqrt => sqrt,
    safe_asin => asin,
    safe_acos => acos,
    safe_acosh => acosh,
    safe_atanh => atanh,
)

opmap(@nospecialize(op)) = get(OP_MAP, op, op)
inverse_opmap(@nospecialize(op)) = get(INVERSE_OP_MAP, op, op)

recommend_loss_function_expression(expression_type) = false

create_mutation_weights(w::AbstractMutationWeights) = w
create_mutation_weights(w::NamedTuple) = MutationWeights(; w...)

@unstable function with_max_degree_from_context(
    node_type, user_provided_operators, operators
)
    if has_max_degree(node_type)
        # The user passed a node type with an explicit max degree,
        # so we don't override it.
        node_type
    else
        if user_provided_operators
            # We select a degree so that we fit the number of operators
            with_max_degree(node_type, Val(length(operators)))
        else
            with_max_degree(node_type, Val(2))
        end
    end
end

const deprecated_options_mapping = Base.ImmutableDict(
    :mutationWeights => :mutation_weights,
    :hofMigration => :hof_migration,
    :shouldOptimizeConstants => :should_optimize_constants,
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
    :enable_autodiff => :deprecated_enable_autodiff,
    :ns => :tournament_selection_n,
    :loss => :elementwise_loss,
)

# For static analysis tools:
@ignore const DEFAULT_OPTIONS = ()

const OPTION_DESCRIPTIONS = """- `defaults`: What set of defaults to use for `Options`. The default,
    `nothing`, will simply take the default options from the current version of SymbolicRegression.
    However, you may also select the defaults from an earlier version, such as `v"0.24.5"`.
- `binary_operators`: Vector of binary operators (functions) to use.
    Each operator should be defined for two input scalars,
    and one output scalar. All operators
    need to be defined over the entire real line (excluding infinity - these
    are stopped before they are input), or return `NaN` where not defined.
    For speed, define it so it takes two reals
    of the same type as input, and outputs the same type. For the SymbolicUtils
    simplification backend, you will need to define a generic method of the
    operator so it takes arbitrary types.
- `operator_enum_constructor`: Constructor function to use for creating the operators enum.
    By default, OperatorEnum is used, but you can provide a different constructor like
    GenericOperatorEnum. The constructor must accept the keyword arguments 'binary_operators'
    and 'unary_operators'.
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
    as any function of `tree::AbstractExpressionNode{T}`, `dataset::Dataset{T}`,
    and `options::AbstractOptions`, so long as you output a non-negative
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

- `loss_function_expression`: Similar to `loss_function`, but takes `AbstractExpression` instead of `AbstractExpressionNode` as its first argument. Useful for `TemplateExpressionSpec`.
- `loss_scale`: Determines how loss values are scaled when computing scores. Options are:
    - `:log` (default): Uses logarithmic scaling of loss ratios. This mode requires non-negative loss values
        and is ideal for traditional loss functions that are always positive.
    - `:linear`: Uses direct differences between losses. This mode handles any loss values (including negative)
        and is useful for custom loss functions, especially those based on likelihoods.
- `expression_spec::AbstractExpressionSpec`: A specification of what types of expressions to use in the
    search. For example, `ExpressionSpec()` (default). You can also see `TemplateExpressionSpec` and
    `ParametricExpressionSpec` for specialized cases.
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
- `complexity_of_variables`: What complexity should be assigned to use of a variable,
    which can also be a vector indicating different per-variable complexity.
    By default, this is 1.
- `complexity_mapping`: Alternatively, you can pass a function that takes
    the expression as input and returns the complexity. Make sure that
    this operates on `AbstractExpression` (and unpacks to `AbstractExpressionNode`),
    and returns an integer.
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
- `dimensionless_constants_only`: Whether to only allow dimensionless
    constants.
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
- `bumper`: Whether to use Bumper.jl for faster evaluation. *Experimental!*
- `migration`: Whether to migrate equations between processes.
- `hof_migration`: Whether to migrate equations from the hall of fame
    to processes.
- `fraction_replaced`: What fraction of each population to replace with
    migrated equations at the end of each cycle.
- `fraction_replaced_hof`: What fraction to replace with hall of fame
    equations at the end of each cycle.
- `fraction_replaced_guesses`: What fraction to replace with user-provided
    guess expressions at the end of each cycle.
- `should_simplify`: Whether to simplify equations. If you
    pass a custom objective, this will be set to `false`.
- `should_optimize_constants`: Whether to use an optimization algorithm
    to periodically optimize constants in equations.
- `optimizer_algorithm`: Select algorithm to use for optimizing constants. Default
    is `Optim.BFGS(linesearch=LineSearches.BackTracking())`.
- `optimizer_nrestarts`: How many different random starting positions to consider
    for optimization of constants.
- `optimizer_probability`: Probability of performing optimization of constants at
    the end of a given iteration.
- `optimizer_iterations`: How many optimization iterations to perform. This gets
    passed to `Optim.Options` as `iterations`. The default is 8.
- `optimizer_f_calls_limit`: How many function calls to allow during optimization.
    This gets passed to `Optim.Options` as `f_calls_limit`. The default is
    `10_000`.
- `optimizer_options`: General options for the constant optimization. For details
    we refer to the documentation on `Optim.Options` from the `Optim.jl` package.
    Options can be provided here as `NamedTuple`, e.g. `(iterations=16,)`, as a
    `Dict`, e.g. Dict(:x_tol => 1.0e-32,), or as an `Optim.Options` instance.
- `autodiff_backend`: The backend to use for differentiation, which should be
    an instance of `AbstractADType` (see `ADTypes.jl`).
    Default is `nothing`, which means `Optim.jl` will estimate gradients (likely
    with finite differences). You can also pass a symbolic version of the backend
    type, such as `:Zygote` for Zygote.jl or `:Mooncake` for Mooncake.jl. Most backends
    will not work, and many will never work due to incompatibilities, though
    support for some is gradually being added.
- `perturbation_factor`: When mutating a constant, either
    multiply or divide by (1+perturbation_factor)^(rand()+1).
- `probability_negate_constant`: Probability of negating a constant in the equation
    when mutating it.
- `mutation_weights`: Relative probabilities of the mutations. The struct
    `MutationWeights` (or any `AbstractMutationWeights`) should be passed to these options.
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
- `output_directory`: The base directory to save output files to. Files
    will be saved in a subdirectory according to the run ID. By default,
    this is `./outputs`.
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
- `input_stream`: the stream to read user input from. By default, this is `stdin`. If you encounter issues
    with reading from `stdin`, like a hang, you can simply pass `devnull` to this argument.
- `skip_mutation_failures`: Whether to simply skip over mutations that fail or are rejected, rather than to replace the mutated
    expression with the original expression and proceed normally.
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
    Options(;kws...) <: AbstractOptions

Construct options for `equation_search` and other functions.
The current arguments have been tuned using the median values from
https://github.com/MilesCranmer/PySR/discussions/115.

# Arguments
$(OPTION_DESCRIPTIONS)
"""
@unstable @save_kwargs DEFAULT_OPTIONS function Options(;
    # Note: We can only `@nospecialize` on the first 32 arguments, which is why
    #       we have to declare some of these later on.
    @nospecialize(defaults::Union{VersionNumber,Nothing} = nothing),
    # Search options:
    ## 1. Creating the Search Space:
    @nospecialize(operators::Union{Nothing,AbstractOperatorEnum} = nothing),
    @nospecialize(maxsize::Union{Nothing,Integer} = nothing),
    @nospecialize(maxdepth::Union{Nothing,Integer} = nothing),
    @nospecialize(expression_spec::Union{Nothing,AbstractExpressionSpec} = nothing),
    ## 2. Setting the Search Size:
    @nospecialize(populations::Union{Nothing,Integer} = nothing),
    @nospecialize(population_size::Union{Nothing,Integer} = nothing),
    @nospecialize(ncycles_per_iteration::Union{Nothing,Integer} = nothing),
    ## 3. The Objective:
    @nospecialize(elementwise_loss::Union{Function,SupervisedLoss,Nothing} = nothing),
    @nospecialize(loss_function::Union{Function,Nothing} = nothing),
    @nospecialize(loss_function_expression::Union{Function,Nothing} = nothing),
    ###           [model_selection - only used in MLJ interface]
    @nospecialize(dimensional_constraint_penalty::Union{Nothing,Real} = nothing),
    ###           dimensionless_constants_only
    ## 4. Working with Complexities:
    @nospecialize(parsimony::Union{Nothing,Real} = nothing),
    @nospecialize(constraints = nothing),
    @nospecialize(nested_constraints = nothing),
    @nospecialize(complexity_of_operators = nothing),
    @nospecialize(complexity_of_constants::Union{Nothing,Real} = nothing),
    @nospecialize(complexity_of_variables::Union{Nothing,Real,AbstractVector} = nothing),
    ###           complexity_mapping
    @nospecialize(warmup_maxsize_by::Union{Real,Nothing} = nothing),
    ###           use_frequency
    ###           use_frequency_in_tournament
    @nospecialize(adaptive_parsimony_scaling::Union{Real,Nothing} = nothing),
    ###           should_simplify
    ## 5. Mutations:
    @nospecialize(
        operator_enum_constructor::Union{Nothing,Type{<:AbstractOperatorEnum},Function} =
            nothing
    ),
    @nospecialize(
        mutation_weights::Union{AbstractMutationWeights,AbstractVector,NamedTuple,Nothing} =
            nothing
    ),
    @nospecialize(crossover_probability::Union{Real,Nothing} = nothing),
    @nospecialize(annealing::Union{Bool,Nothing} = nothing),
    @nospecialize(alpha::Union{Nothing,Real} = nothing),
    ###           perturbation_factor
    ###           probability_negate_constant
    ###           skip_mutation_failures
    ## 6. Tournament Selection:
    @nospecialize(tournament_selection_n::Union{Nothing,Integer} = nothing),
    @nospecialize(tournament_selection_p::Union{Nothing,Real} = nothing),
    ## 7. Constant Optimization:
    ###           optimizer_algorithm
    ###           optimizer_nrestarts
    ###           optimizer_probability
    ###           optimizer_iterations
    ###           optimizer_f_calls_limit
    ###           optimizer_options
    ###           should_optimize_constants
    ## 8. Migration between Populations:
    ###           migration
    ###           hof_migration
    ###           fraction_replaced
    ###           fraction_replaced_hof
    ###           topn
    ## 9. Data Preprocessing:
    ###           [none]
    ## 10. Stopping Criteria:
    ###           timeout_in_seconds
    ###           max_evals
    @nospecialize(early_stop_condition::Union{Function,Real,Nothing} = nothing),
    ## 11. Performance and Parallelization:
    ###           [others, passed to `equation_search`]
    @nospecialize(batching::Union{Bool,Nothing} = nothing),
    @nospecialize(batch_size::Union{Nothing,Integer} = nothing),
    ###           turbo
    ###           bumper
    ###           autodiff_backend
    ## 12. Determinism:
    ###           [others, passed to `equation_search`]
    ###           deterministic
    ###           seed
    ## 13. Monitoring:
    ###           verbosity
    ###           print_precision
    ###           progress
    ## 14. Environment:
    ###           [none]
    ## 15. Exporting the Results:
    ###           [others, passed to `equation_search`]
    ###           output_directory
    ###           save_to_file

    # Other search, but no specializations (since Julia limits us to 32!)
    ## 1. Search Space:
    ## 2. Setting the Search Size:
    ## 3. The Objective:
    dimensionless_constants_only::Bool=false,
    loss_scale::Symbol=:log,
    ## 4. Working with Complexities:
    complexity_mapping::Union{Function,ComplexityMapping,Nothing}=nothing,
    use_frequency::Bool=true,
    use_frequency_in_tournament::Bool=true,
    should_simplify::Union{Nothing,Bool}=nothing,
    ## 5. Mutations:
    perturbation_factor::Union{Nothing,Real}=nothing,
    probability_negate_constant::Union{Real,Nothing}=nothing,
    skip_mutation_failures::Bool=true,
    ## 6. Tournament Selection
    ## 7. Constant Optimization:
    optimizer_algorithm::Union{AbstractString,Optim.AbstractOptimizer}=Optim.BFGS(;
        linesearch=LineSearches.BackTracking()
    ),
    optimizer_nrestarts::Int=2,
    optimizer_probability::AbstractFloat=0.14,
    optimizer_iterations::Union{Nothing,Integer}=nothing,
    optimizer_f_calls_limit::Union{Nothing,Integer}=nothing,
    optimizer_options::Union{Dict,NamedTuple,Optim.Options,Nothing}=nothing,
    should_optimize_constants::Bool=true,
    ## 8. Migration between Populations:
    migration::Bool=true,
    hof_migration::Bool=true,
    fraction_replaced::Union{Real,Nothing}=nothing,
    fraction_replaced_hof::Union{Real,Nothing}=nothing,
    fraction_replaced_guesses::Union{Real,Nothing}=nothing,
    topn::Union{Nothing,Integer}=nothing,
    ## 9. Data Preprocessing:
    ## 10. Stopping Criteria:
    timeout_in_seconds::Union{Nothing,Real}=nothing,
    max_evals::Union{Nothing,Integer}=nothing,
    input_stream::IO=stdin,
    ## 11. Performance and Parallelization:
    turbo::Bool=false,
    bumper::Bool=false,
    autodiff_backend::Union{AbstractADType,Symbol,Nothing}=nothing,
    ## 12. Determinism:
    deterministic::Bool=false,
    seed=nothing,
    ## 13. Monitoring:
    verbosity::Union{Integer,Nothing}=nothing,
    print_precision::Integer=5,
    progress::Union{Bool,Nothing}=nothing,
    ## 14. Environment:
    ## 15. Exporting the Results:
    output_directory::Union{Nothing,String}=nothing,
    save_to_file::Bool=true,
    ## Undocumented features:
    bin_constraints=nothing,
    una_constraints=nothing,
    terminal_width::Union{Nothing,Integer}=nothing,
    use_recorder::Bool=false,
    recorder_file::AbstractString="pysr_recorder.json",
    ### Not search options; just construction options:
    define_helper_functions::Bool=true,
    #########################################
    # Deprecated args: ######################
    expression_type::Union{Nothing,Type{<:AbstractExpression}}=nothing,
    expression_options::Union{Nothing,NamedTuple}=nothing,
    node_type::Union{Nothing,Type{<:AbstractExpressionNode}}=nothing,
    output_file::Union{Nothing,AbstractString}=nothing,
    fast_cycle::Bool=false,
    npopulations::Union{Nothing,Integer}=nothing,
    npop::Union{Nothing,Integer}=nothing,
    deprecated_return_state::Union{Bool,Nothing}=nothing,
    unary_operators=nothing,
    binary_operators=nothing,
    kws...,
    #########################################
)
    for k in keys(kws)
        !haskey(deprecated_options_mapping, k) && error("Unknown keyword argument: $k")
        new_key = deprecated_options_mapping[k]
        if startswith(string(new_key), "deprecated_")
            Base.depwarn("The keyword argument `$(k)` is deprecated.", :Options)
            if string(new_key) != "deprecated_return_state"
                # This one we actually want to use
                continue
            end
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
        k == :enable_autodiff && continue
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
    if npop !== nothing
        Base.depwarn("`npop` is deprecated. Use `population_size` instead.", :Options)
        population_size = npop
    end
    if npopulations !== nothing
        Base.depwarn("`npopulations` is deprecated. Use `populations` instead.", :Options)
        populations = npopulations
    end
    if optimizer_algorithm isa AbstractString
        Base.depwarn(
            "The `optimizer_algorithm` argument should be an `AbstractOptimizer`, not a string.",
            :Options,
        )
        optimizer_algorithm = if optimizer_algorithm == "NelderMead"
            Optim.NelderMead(; linesearch=LineSearches.BackTracking())
        else
            Optim.BFGS(; linesearch=LineSearches.BackTracking())
        end
    end
    if output_file !== nothing
        error("`output_file` is deprecated. Use `output_directory` instead.")
    end
    user_provided_operators = !isnothing(operators)

    if user_provided_operators
        @assert binary_operators === nothing
        @assert unary_operators === nothing
        @assert operator_enum_constructor === nothing
    end

    @assert(
        count(!isnothing, [elementwise_loss, loss_function, loss_function_expression]) <= 1,
        "You cannot specify more than one of `elementwise_loss`, `loss_function`, and `loss_function_expression`."
    )

    if !isnothing(loss_function) && recommend_loss_function_expression(expression_type)
        @warn(
            "You are using `loss_function` with `$(expression_type)`. " *
                "You should use `loss_function_expression` instead, as it is designed to work with expressions directly."
        )
    end

    elementwise_loss = something(elementwise_loss, L2DistLoss())

    if complexity_mapping !== nothing
        @assert all(
            isnothing,
            [complexity_of_operators, complexity_of_constants, complexity_of_variables],
        )
    end

    #################################
    #### Supply defaults ############
    #! format: off
    _default_options = default_options(defaults)
    maxsize = something(maxsize, _default_options.maxsize)
    populations = something(populations, _default_options.populations)
    population_size = something(population_size, _default_options.population_size)
    ncycles_per_iteration = something(ncycles_per_iteration, _default_options.ncycles_per_iteration)
    parsimony = something(parsimony, _default_options.parsimony)
    warmup_maxsize_by = something(warmup_maxsize_by, _default_options.warmup_maxsize_by)
    adaptive_parsimony_scaling = something(adaptive_parsimony_scaling, _default_options.adaptive_parsimony_scaling)
    mutation_weights = something(mutation_weights, _default_options.mutation_weights)
    crossover_probability = something(crossover_probability, _default_options.crossover_probability)
    annealing = something(annealing, _default_options.annealing)
    alpha = something(alpha, _default_options.alpha)
    perturbation_factor = something(perturbation_factor, _default_options.perturbation_factor)
    probability_negate_constant = something(probability_negate_constant, _default_options.probability_negate_constant)
    tournament_selection_n = something(tournament_selection_n, _default_options.tournament_selection_n)
    tournament_selection_p = something(tournament_selection_p, _default_options.tournament_selection_p)
    fraction_replaced = something(fraction_replaced, _default_options.fraction_replaced)
    fraction_replaced_hof = something(fraction_replaced_hof, _default_options.fraction_replaced_hof)
    fraction_replaced_guesses = something(fraction_replaced_guesses, _default_options.fraction_replaced_guesses)
    topn = something(topn, _default_options.topn)
    batching = something(batching, _default_options.batching)
    batch_size = something(batch_size, _default_options.batch_size)
    if !user_provided_operators
        binary_operators = something(binary_operators, _default_options.operators.ops[2])
        unary_operators = something(unary_operators, _default_options.operators.ops[1])
    end
    #! format: on
    #################################

    if should_simplify === nothing
        should_simplify = (
            loss_function === nothing &&
            nested_constraints === nothing &&
            constraints === nothing &&
            bin_constraints === nothing &&
            una_constraints === nothing
        )
    end

    @assert maxsize > 3
    @assert warmup_maxsize_by >= 0.0f0
    @assert tournament_selection_n < population_size "`tournament_selection_n` must be less than `population_size`"
    @assert loss_scale in (:log, :linear) "`loss_scale` must be either log or linear"

    # Make sure nested_constraints contains functions within our operator set:
    _nested_constraints = if user_provided_operators
        build_nested_constraints(; nested_constraints, operators_by_degree=operators.ops)
    else
        # Convert binary/unary to generic format for backwards compatibility
        operators_tuple = (unary_operators, binary_operators)
        build_nested_constraints(; nested_constraints, operators_by_degree=operators_tuple)
    end

    if typeof(constraints) <: Tuple
        constraints = Dict(constraints)
    elseif constraints isa AbstractVector
        constraints = Dict(constraints)
    end
    if constraints !== nothing
        @assert all(isnothing, (bin_constraints, una_constraints))
        if user_provided_operators
            # For generic degree interface, constraints should be handled by the generic function
            # Don't set bin_constraints/una_constraints as they shouldn't be used
            all_operators = Set()
            for ops in operators.ops
                for op in ops
                    if op ∈ all_operators
                        error(
                            "Operator $(op) appears in multiple degrees. " *
                            "You can't use constraints.",
                        )
                    end
                    push!(all_operators, op)
                end
            end
        else
            for op in binary_operators
                @assert !(op in unary_operators)
            end
            for op in unary_operators
                @assert !(op in binary_operators)
            end
            bin_constraints = constraints
            una_constraints = constraints
        end
    else
        # When constraints is nothing, we might still have individual bin_constraints/una_constraints
        if user_provided_operators
            @assert(
                all(isnothing, (bin_constraints, una_constraints)),
                "When using user_provided_operators=true, use the 'constraints' parameter instead of 'bin_constraints' and 'una_constraints'"
            )
        end
    end

    if expression_spec !== nothing
        @assert expression_type === nothing
        @assert expression_options === nothing
        @assert node_type === nothing

        expression_type = get_expression_type(expression_spec)
        expression_options = get_expression_options(expression_spec)
        node_type = get_node_type(expression_spec)
    else
        if !all(isnothing, (expression_type, expression_options, node_type))
            Base.depwarn(
                "The `expression_type`, `expression_options`, and `node_type` arguments are deprecated. Use `expression_spec` instead, which populates these automatically.",
                :Options,
            )
        end
        _default_expression_spec = ExpressionSpec()
        expression_type = @something(
            expression_type, get_expression_type(_default_expression_spec)
        )
        expression_options = @something(
            expression_options, get_expression_options(_default_expression_spec)
        )
        node_type = @something(node_type, default_node_type(expression_type))
    end

    node_type = with_max_degree_from_context(node_type, user_provided_operators, operators)

    operators = if user_provided_operators && operators isa OperatorEnum
        # Apply opmap to user-provided operators (e.g., log -> safe_log)
        mapped_operators_by_degree = ntuple(length(operators.ops)) do i
            map(opmap, operators.ops[i])
        end
        OperatorEnum(mapped_operators_by_degree)
    else
        operators
    end

    op_constraints = if user_provided_operators
        @assert(
            all(isnothing, (una_constraints, bin_constraints)),
            "When using user_provided_operators=true, use the 'constraints' parameter instead of 'una_constraints' and 'bin_constraints'"
        )

        build_constraints(; constraints, operators_by_degree=operators.ops)
    else
        # Convert binary/unary to generic format for backwards compatibility
        build_constraints(;
            una_constraints,
            bin_constraints,
            operators_by_degree=(unary_operators, binary_operators),
        )
    end

    complexity_mapping = @something(
        complexity_mapping,
        ComplexityMapping(
            complexity_of_operators,
            complexity_of_variables,
            complexity_of_constants,
            if user_provided_operators
                operators.ops
            else
                (unary_operators, binary_operators)
            end,
        )
    )

    maxdepth = something(maxdepth, maxsize)

    if define_helper_functions && !user_provided_operators
        # We call here so that mapped operators, like `^`
        # are correctly overloaded, rather than overloading
        # operators like "safe_pow", etc.
        OperatorEnum(;
            binary_operators=binary_operators,
            unary_operators=unary_operators,
            define_helper_functions=true,
            empty_old_operators=true,
        )
    end

    operators = if user_provided_operators
        operators
    else
        binary_operators = map(opmap, binary_operators)
        unary_operators = map(opmap, unary_operators)
        if operator_enum_constructor !== nothing
            operator_enum_constructor(;
                binary_operators=binary_operators, unary_operators=unary_operators
            )
        else
            OperatorEnum(;
                binary_operators=binary_operators,
                unary_operators=unary_operators,
                define_helper_functions=define_helper_functions,
                empty_old_operators=false,
            )
        end
    end

    early_stop_condition = if typeof(early_stop_condition) <: Real
        # Need to make explicit copy here for this to work:
        stopping_point = Float64(early_stop_condition)
        Base.Fix2(<, stopping_point) ∘ first ∘ tuple # Equivalent to (l, c) -> l < stopping_point
    else
        early_stop_condition
    end

    # Parse optimizer options
    if !isa(optimizer_options, Optim.Options)
        optimizer_iterations = something(optimizer_iterations, 8)
        optimizer_f_calls_limit = something(optimizer_f_calls_limit, 10_000)
        extra_kws = hasfield(Optim.Options, :show_warnings) ? (; show_warnings=false) : ()
        optimizer_options = Optim.Options(;
            iterations=optimizer_iterations,
            f_calls_limit=optimizer_f_calls_limit,
            extra_kws...,
            something(optimizer_options, ())...,
        )
    else
        @assert optimizer_iterations === nothing && optimizer_f_calls_limit === nothing
    end
    if hasfield(Optim.Options, :show_warnings) && optimizer_options.show_warnings
        @warn "Optimizer warnings are turned on. This might result in a lot of warnings being printed from NaNs, as these are common during symbolic regression"
    end

    set_mutation_weights = create_mutation_weights(mutation_weights)

    @assert print_precision > 0

    _autodiff_backend = if autodiff_backend isa Union{Nothing,AbstractADType}
        autodiff_backend
    else
        ADTypes.Auto(autodiff_backend)
    end

    _output_directory =
        if output_directory === nothing &&
            get(ENV, "SYMBOLIC_REGRESSION_IS_TESTING", "false") == "true"
            mktempdir()
        else
            output_directory
        end

    nops = map(length, operators.ops)

    options = Options{
        typeof(complexity_mapping),
        operator_specialization(typeof(operators), expression_type),
        typeof(nops),
        typeof(op_constraints),
        node_type,
        expression_type,
        typeof(expression_options),
        typeof(set_mutation_weights),
        turbo,
        bumper,
        deprecated_return_state::Union{Bool,Nothing},
        typeof(_autodiff_backend),
        print_precision,
    }(
        operators,
        op_constraints,
        _nested_constraints,
        complexity_mapping,
        tournament_selection_n,
        tournament_selection_p,
        parsimony,
        dimensional_constraint_penalty,
        dimensionless_constants_only,
        alpha,
        maxsize,
        maxdepth,
        Val(turbo),
        Val(bumper),
        migration,
        hof_migration,
        should_simplify,
        should_optimize_constants,
        _output_directory,
        populations,
        perturbation_factor,
        annealing,
        batching,
        batch_size,
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
        fraction_replaced_guesses,
        topn,
        verbosity,
        Val(print_precision),
        save_to_file,
        probability_negate_constant,
        nops,
        seed,
        elementwise_loss,
        loss_function,
        loss_function_expression,
        loss_scale,
        node_type,
        expression_type,
        expression_options,
        progress,
        terminal_width,
        optimizer_algorithm,
        optimizer_probability,
        optimizer_nrestarts,
        optimizer_options,
        _autodiff_backend,
        recorder_file,
        tournament_selection_p,
        early_stop_condition,
        Val(deprecated_return_state),
        timeout_in_seconds,
        max_evals,
        input_stream,
        skip_mutation_failures,
        deterministic,
        define_helper_functions,
        use_recorder,
    )

    return options
end

function default_options(@nospecialize(version::Union{VersionNumber,Nothing} = nothing))
    version isa VersionNumber &&
        version < v"1.0.0" &&
        return (;
            # Creating the Search Space
            operators=OperatorEnum(((), (+, -, /, *))),
            maxsize=20,
            # Setting the Search Size
            populations=15,
            population_size=33,
            ncycles_per_iteration=550,
            # Working with Complexities
            parsimony=0.0032,
            warmup_maxsize_by=0.0,
            adaptive_parsimony_scaling=20.0,
            # Mutations
            mutation_weights=MutationWeights(;
                mutate_constant=0.048,
                mutate_operator=0.47,
                swap_operands=0.1,
                rotate_tree=0.0,
                add_node=0.79,
                insert_node=5.1,
                delete_node=1.7,
                simplify=0.0020,
                randomize=0.00023,
                do_nothing=0.21,
                optimize=0.0,
                form_connection=0.5,
                break_connection=0.1,
            ),
            crossover_probability=0.066,
            annealing=false,
            alpha=0.1,
            perturbation_factor=0.076,
            probability_negate_constant=0.01,
            # Tournament Selection
            tournament_selection_n=12,
            tournament_selection_p=0.86,
            # Migration between Populations
            fraction_replaced=0.00036,
            fraction_replaced_hof=0.035,
            fraction_replaced_guesses=0.001,
            topn=12,
            # Performance and Parallelization
            batching=false,
            batch_size=50,
        )

    defaults = (;
        # Creating the Search Space
        operators=OperatorEnum(((), (+, -, /, *))),
        maxsize=30,
        # Setting the Search Size
        populations=31,
        population_size=27,
        ncycles_per_iteration=380,
        # Working with Complexities
        parsimony=0.0,
        warmup_maxsize_by=0.0,
        adaptive_parsimony_scaling=1040.0,
        # Mutations
        mutation_weights=MutationWeights(;
            mutate_constant=0.0346,
            mutate_operator=0.293,
            swap_operands=0.198,
            rotate_tree=4.26,
            add_node=2.47,
            insert_node=0.0112,
            delete_node=0.870,
            simplify=0.00209,
            randomize=0.000502,
            do_nothing=0.273,
            optimize=0.0,
            form_connection=0.5,
            break_connection=0.1,
        ),
        crossover_probability=0.0259,
        annealing=true,
        alpha=3.17,
        perturbation_factor=0.129,
        probability_negate_constant=0.00743,
        # Tournament Selection
        tournament_selection_n=15,
        tournament_selection_p=0.982,
        # Migration between Populations
        fraction_replaced=0.00036,
        ## ^Note: the optimal value found was 0.00000425,
        ## but I thought this was a symptom of doing the sweep on such
        ## a small problem, so I increased it to the older value of 0.00036
        fraction_replaced_hof=0.0614,
        fraction_replaced_guesses=0.001,
        topn=12,
        # Performance and Parallelization
        batching=false,
        batch_size=50,
    )

    if version isa VersionNumber && version >= v"2.0.0-"
        defaults = (; defaults..., adaptive_parsimony_scaling=20.0)
    end

    return defaults
end

end
