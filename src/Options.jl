module OptionsModule

using Optim: Optim
import Distributed: nworkers
import LossFunctions: L2DistLoss
import Zygote: gradient
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
import ..EquationModule: Node, string_tree
import ..OptionsStructModule: Options, ComplexityMapping

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

"""
    Options(;kws...)

Construct options for `EquationSearch` and other functions.
The current arguments have been tuned using the median values from
https://github.com/MilesCranmer/PySR/discussions/115.

# Arguments
- `binary_operators`: Tuple of binary operators to use. Each operator should
    be defined for two input scalars, and one output scalar. All operators
    need to be defined over the entire real line (excluding infinity - these
    are stopped before they are input), or return `NaN` where not defined.
    Thus, `log` should be replaced with `safe_log`, etc.
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
- `batchSize`: What batch size to use if using batching.
- `loss`: What loss function to use. Can be one of
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
- `npopulations`: How many populations of equations to use. By default
    this is set equal to the number of cores
- `npop`: How many equations in each population.
- `ncyclesperiteration`: How many generations to consider per iteration.
- `ns`: Number of equations in each subsample during regularized evolution.
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
- `useFrequency`: Whether to use a parsimony that adapts to the
    relative proportion of equations at each complexity; this will
    ensure that there are a balanced number of equations considered
    for every complexity.
- `useFrequencyInTournament`: Whether to use the adaptive parsimony described
    above inside the score, rather than just at the mutation accept/reject stage.
- `fast_cycle`: Whether to thread over subsamples of equations during
    regularized evolution. Slightly improves performance, but is a different
    algorithm.
- `migration`: Whether to migrate equations between processes.
- `hofMigration`: Whether to migrate equations from the hall of fame
    to processes.
- `fractionReplaced`: What fraction of each population to replace with
    migrated equations at the end of each cycle.
- `fractionReplacedHof`: What fraction to replace with hall of fame
    equations at the end of each cycle.
- `shouldOptimizeConstants`: Whether to use an optimization algorithm
    to periodically optimize constants in equations.
- `optimizer_nrestarts`: How many different random starting positions to consider
    for optimization of constants.
- `optimizer_algorithm`: Select algorithm to use for optimizing constants. Default
    is "BFGS", but "NelderMead" is also supported.
- `optimizer_options`: General options for the constant optimization. For details
    we refer to the documentation on `Optim.Options` from the `Optim.jl` package.
    Options can be provided here as `NamedTuple`, e.g. `(iterations=16,)`, as a
    `Dict`, e.g. Dict(:x_tol => 1.0e-32,), or as an `Optim.Options` instance.
- `hofFile`: What file to store equations to, as a backup.
- `perturbationFactor`: When mutating a constant, either
    multiply or divide by (1+perturbationFactor)^(rand()+1).
- `probNegate`: Probability of negating a constant in the equation
    when mutating it.
- `mutationWeights`: Relative probabilities of the mutations, in the order: MutateConstant, MutateOperator, AddNode, InsertNode, DeleteNode, Simplify, Randomize, DoNothing.
- `annealing`: Whether to use simulated annealing.
- `warmupMaxsize`: Whether to slowly increase the max size from 5 up to
    `maxsize`. If nonzero, specifies how many cycles (populations*iterations)
    before increasing by 1.
- `verbosity`: Whether to print debugging statements or
    not.
- `bin_constraints`: See `constraints`. This is the same, but specified for binary
    operators only (for example, if you have an operator that is both a binary
    and unary operator).
- `una_constraints`: Likewise, for unary operators.
- `seed`: What random seed to use. `nothing` uses no seed.
- `progress`: Whether to use a progress bar output (`verbosity` will
    have no effect).
- `probPickFirst`: Expressions in subsample are chosen based on, for
    p=probPickFirst: p, p*(1-p), p*(1-p)^2, and so on.
- `earlyStopCondition`: Float - whether to stop early if the mean loss gets below this value.
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
"""
function Options(;
    binary_operators::NTuple{nbin,Any}=(+, -, /, *),
    unary_operators::NTuple{nuna,Any}=(),
    constraints=nothing,
    loss=L2DistLoss(),
    ns=12, #1 sampled from every ns per mutation
    topn=12, #samples to return per population
    complexity_of_operators=nothing,
    complexity_of_constants::Union{Nothing,Real}=nothing,
    complexity_of_variables::Union{Nothing,Real}=nothing,
    parsimony=0.0032f0,
    alpha=0.100000f0,
    maxsize=20,
    maxdepth=nothing,
    fast_cycle=false,
    migration=true,
    hofMigration=true,
    fractionReplacedHof=0.035f0,
    shouldOptimizeConstants=true,
    hofFile=nothing,
    npopulations=15,
    perturbationFactor=0.076f0,
    annealing=false,
    batching=false,
    batchSize=50,
    mutationWeights=[0.048, 0.47, 0.79, 5.1, 1.7, 0.0020, 0.00023, 0.21],
    crossoverProbability=0.066f0,
    warmupMaxsizeBy=0.0f0,
    useFrequency=true,
    useFrequencyInTournament=true,
    npop=33,
    ncyclesperiteration=550,
    fractionReplaced=0.00036f0,
    verbosity=convert(Int, 1e9),
    probNegate=0.01f0,
    seed=nothing,
    bin_constraints=nothing,
    una_constraints=nothing,
    progress=true,
    terminal_width=nothing,
    warmupMaxsize=nothing,
    optimizer_algorithm="BFGS",
    optimizer_nrestarts=2,
    optimize_probability=0.14f0,
    optimizer_iterations=nothing,
    optimizer_options::Union{Dict,NamedTuple,Optim.Options,Nothing}=nothing,
    recorder=nothing,
    recorder_file="pysr_recorder.json",
    probPickFirst=0.86f0,
    earlyStopCondition::Union{Function,Real,Nothing}=nothing,
    stateReturn::Bool=false,
    timeout_in_seconds=nothing,
    max_evals=nothing,
    skip_mutation_failures::Bool=true,
    enable_autodiff::Bool=false,
    nested_constraints=nothing,
    deterministic=false,
) where {nuna,nbin}
    if warmupMaxsize !== nothing
        error(
            "warmupMaxsize is deprecated. Please use warmupMaxsizeBy, and give the time at which the warmup will end as a fraction of the total search cycles.",
        )
    end

    if hofFile === nothing
        hofFile = "hall_of_fame.csv" #TODO - put in date/time string here
    end

    @assert maxsize > 3
    @assert warmupMaxsizeBy >= 0.0f0

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

    if enable_autodiff
        diff_binary_operators = Any[]
        diff_unary_operators = Any[]

        test_inputs = map(x -> convert(Float32, x), LinRange(-100, 100, 99))
        # Create grid over [-100, 100]^2:
        test_inputs_xy = reduce(
            hcat, reduce(hcat, ([[[x, y] for x in test_inputs] for y in test_inputs]))
        )
        for op in binary_operators
            diff_op(x, y) = gradient(op, x, y)

            test_output = diff_op.(test_inputs_xy[1, :], test_inputs_xy[2, :])
            gradient_exists = all((x) -> x !== nothing, Iterators.flatten(test_output))
            if gradient_exists
                push!(diff_binary_operators, diff_op)
            else
                if verbosity > 0
                    @warn "Automatic differentiation has been turned off, since operator $(op) does not have well-defined gradients."
                end
                enable_autodiff = false
                break
            end
        end

        for op in unary_operators
            diff_op(x) = gradient(op, x)[1]
            test_output = diff_op.(test_inputs)
            gradient_exists = all((x) -> x !== nothing, test_output)
            if gradient_exists
                push!(diff_unary_operators, diff_op)
            else
                if verbosity > 0
                    @warn "Automatic differentiation has been turned off, since operator $(op) does not have well-defined gradients."
                end
                enable_autodiff = false
                break
            end
        end
        diff_binary_operators = Tuple(diff_binary_operators)
        diff_unary_operators = Tuple(diff_unary_operators)
    end

    if !enable_autodiff
        diff_binary_operators = nothing
        diff_unary_operators = nothing
    end

    mutationWeights = map((x,) -> convert(Float64, x), mutationWeights)
    if length(mutationWeights) != 8
        error("Not the right number of mutation probabilities given")
    end

    for (op, f) in enumerate(map(Symbol, binary_operators))
        _f = if f in [Symbol(pow), Symbol(safe_pow)]
            Symbol(^)
        else
            f
        end
        if !isdefined(Base, _f)
            continue
        end
        @eval begin
            function Base.$_f(l::Node{T1}, r::Node{T2}) where {T1<:Real,T2<:Real}
                T = promote_type(T1, T2)
                l = convert(Node{T}, l)
                r = convert(Node{T}, r)
                if (l.constant && r.constant)
                    return Node(; val=$f(l.val, r.val))
                else
                    return Node($op, l, r)
                end
            end
            function Base.$_f(l::Node{T1}, r::T2) where {T1<:Real,T2<:Real}
                T = promote_type(T1, T2)
                l = convert(Node{T}, l)
                r = convert(T, r)
                return l.constant ? Node(; val=$f(l.val, r)) : Node($op, l, Node(; val=r))
            end
            function Base.$_f(l::T1, r::Node{T2}) where {T1<:Real,T2<:Real}
                T = promote_type(T1, T2)
                l = convert(T, l)
                r = convert(Node{T}, r)
                return r.constant ? Node(; val=$f(l, r.val)) : Node($op, Node(; val=l), r)
            end
        end
    end

    # Redefine Base operations:
    for (op, f) in enumerate(map(Symbol, unary_operators))
        if !isdefined(Base, f)
            continue
        end
        @eval begin
            function Base.$f(l::Node{T})::Node{T} where {T<:Real}
                return l.constant ? Node(; val=$f(l.val)) : Node($op, l)
            end
        end
    end

    if progress
        verbosity = 0
    end

    if recorder === nothing
        recorder = haskey(ENV, "PYSR_RECORDER") && (ENV["PYSR_RECORDER"] == "1")
    end

    if typeof(earlyStopCondition) <: Real
        # Need to make explicit copy here for this to work:
        stopping_point = Float64(earlyStopCondition)
        earlyStopCondition = (loss, complexity) -> loss < stopping_point
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

    options = Options{
        typeof(binary_operators),
        typeof(unary_operators),
        typeof(diff_binary_operators),
        typeof(diff_unary_operators),
        typeof(loss),
        eltype(complexity_mapping),
    }(
        binary_operators,
        unary_operators,
        diff_binary_operators,
        diff_unary_operators,
        bin_constraints,
        una_constraints,
        complexity_mapping,
        ns,
        parsimony,
        alpha,
        maxsize,
        maxdepth,
        fast_cycle,
        migration,
        hofMigration,
        fractionReplacedHof,
        shouldOptimizeConstants,
        hofFile,
        npopulations,
        perturbationFactor,
        annealing,
        batching,
        batchSize,
        mutationWeights,
        crossoverProbability,
        warmupMaxsizeBy,
        useFrequency,
        useFrequencyInTournament,
        npop,
        ncyclesperiteration,
        fractionReplaced,
        topn,
        verbosity,
        probNegate,
        nuna,
        nbin,
        seed,
        loss,
        progress,
        terminal_width,
        optimizer_algorithm,
        optimize_probability,
        optimizer_nrestarts,
        optimizer_options,
        recorder,
        recorder_file,
        probPickFirst,
        earlyStopCondition,
        stateReturn,
        timeout_in_seconds,
        max_evals,
        skip_mutation_failures,
        enable_autodiff,
        nested_constraints,
        deterministic,
    )

    @eval begin
        Base.print(io::IO, tree::Node) = print(io, string_tree(tree, $options))
        Base.show(io::IO, tree::Node) = print(io, string_tree(tree, $options))
    end

    return options
end

end
