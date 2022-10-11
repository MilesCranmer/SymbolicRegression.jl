module SymbolicRegression

# Types
export Population,
    PopMember,
    HallOfFame,
    Options,
    MutationWeightings,
    Node,

    #Functions:
    EquationSearch,
    s_r_cycle,
    calculate_pareto_frontier,
    count_nodes,
    compute_complexity,
    print_tree,
    string_tree,
    eval_tree_array,
    eval_diff_tree_array,
    eval_grad_tree_array,
    differentiable_eval_tree_array,
    set_node!,
    copy_node,
    node_to_symbolic,
    symbolic_to_node,
    combine_operators,
    gen_random_tree,
    gen_random_tree_fixed_size,

    #Operators
    plus,
    sub,
    mult,
    square,
    cube,
    pow,
    safe_pow,
    div,
    safe_log,
    safe_log2,
    safe_log10,
    safe_log1p,
    safe_acosh,
    safe_sqrt,
    neg,
    greater,
    relu,
    logical_or,
    logical_and,

    # special operators
    gamma,
    erf,
    erfc,
    atanh_clip

using Distributed
using JSON3: JSON3
import Printf: @printf, @sprintf
using Pkg: Pkg
import TOML: parsefile
import Random: seed!, shuffle!
using Reexport
@reexport import LossFunctions:
    MarginLoss,
    DistanceLoss,
    SupervisedLoss,
    ZeroOneLoss,
    LogitMarginLoss,
    PerceptronLoss,
    HingeLoss,
    L1HingeLoss,
    L2HingeLoss,
    SmoothedL1HingeLoss,
    ModifiedHuberLoss,
    L2MarginLoss,
    ExpLoss,
    SigmoidLoss,
    DWDMarginLoss,
    LPDistLoss,
    L1DistLoss,
    L2DistLoss,
    PeriodicLoss,
    HuberLoss,
    EpsilonInsLoss,
    L1EpsilonInsLoss,
    L2EpsilonInsLoss,
    LogitDistLoss,
    QuantileLoss,
    LogCoshLoss

# https://discourse.julialang.org/t/how-to-find-out-the-version-of-a-package-from-its-module/37755/15
const PACKAGE_VERSION = let
    project = parsefile(joinpath(pkgdir(@__MODULE__), "Project.toml"))
    VersionNumber(project["version"])
end

include("Core.jl")
include("Recorder.jl")
include("Utils.jl")
include("EquationUtils.jl")
include("EvaluateEquation.jl")
include("EvaluateEquationDerivative.jl")
include("CheckConstraints.jl")
include("AdaptiveParsimony.jl")
include("MutationFunctions.jl")
include("LossFunctions.jl")
include("PopMember.jl")
include("ConstantOptimization.jl")
include("Population.jl")
include("HallOfFame.jl")
include("InterfaceSymbolicUtils.jl")
include("SimplifyEquation.jl")
include("Mutate.jl")
include("RegularizedEvolution.jl")
include("SingleIteration.jl")
include("ProgressBars.jl")
include("SearchUtils.jl")

import .CoreModule:
    CONST_TYPE,
    MAX_DEGREE,
    BATCH_DIM,
    FEATURE_DIM,
    RecordType,
    Dataset,
    Node,
    copy_node,
    set_node!,
    Options,
    MutationWeightings,
    plus,
    sub,
    mult,
    square,
    cube,
    pow,
    safe_pow,
    div,
    safe_log,
    safe_log2,
    safe_log10,
    safe_log1p,
    safe_sqrt,
    safe_acosh,
    neg,
    greater,
    greater,
    relu,
    logical_or,
    logical_and,
    gamma,
    erf,
    erfc,
    atanh_clip,
    SRConcurrency,
    SRSerial,
    SRThreaded,
    SRDistributed,
    string_tree,
    print_tree
import .UtilsModule: debug, debug_inline, is_anonymous_function, recursive_merge
import .EquationUtilsModule:
    count_nodes,
    compute_complexity,
    get_constants,
    set_constants,
    index_constants,
    NodeIndex
import .EvaluateEquationModule: eval_tree_array, differentiable_eval_tree_array
import .EvaluateEquationDerivativeModule: eval_diff_tree_array, eval_grad_tree_array
import .CheckConstraintsModule: check_constraints
import .AdaptiveParsimonyModule:
    RunningSearchStatistics, update_frequencies!, move_window!, normalize_frequencies!
import .MutationFunctionsModule:
    gen_random_tree,
    gen_random_tree_fixed_size,
    random_node,
    random_node_and_parent,
    crossover_trees
import .LossFunctionsModule: eval_loss, loss, score_func, update_baseline_loss!
import .PopMemberModule: PopMember, copy_pop_member
import .PopulationModule: Population, best_sub_pop, record_population, best_of_sample
import .HallOfFameModule:
    HallOfFame, calculate_pareto_frontier, string_dominating_pareto_curve
import .SingleIterationModule: s_r_cycle, optimize_and_simplify_population
import .InterfaceSymbolicUtilsModule: node_to_symbolic, symbolic_to_node
import .SimplifyEquationModule: combine_operators, simplify_tree
import .ProgressBarsModule: WrappedProgressBar
import .RecorderModule: @recorder, find_iteration_from_record
import .SearchUtilsModule:
    next_worker,
    @sr_spawner,
    watch_stream,
    close_reader!,
    check_for_user_quit,
    check_for_loss_threshold,
    check_for_timeout,
    check_max_evals,
    update_progress_bar!,
    print_search_state,
    init_dummy_pops

include("Configure.jl")
include("Deprecates.jl")

StateType{T} = Tuple{
    Union{Vector{Vector{Population{T}}},Matrix{Population{T}}},
    Union{HallOfFame{T},Vector{HallOfFame{T}}},
}

"""
    EquationSearch(X, y[; kws...])

Perform a distributed equation search for functions `f_i` which
describe the mapping `f_i(X[:, j]) ≈ y[i, j]`. Options are
configured using SymbolicRegression.Options(...),
which should be passed as a keyword argument to options.
One can turn off parallelism with `numprocs=0`,
which is useful for debugging and profiling.

# Arguments
- `X::AbstractMatrix{T}`:  The input dataset to predict `y` from.
    The first dimension is features, the second dimension is rows.
- `y::Union{AbstractMatrix{T}, AbstractVector{T}}`: The values to predict. The first dimension
    is the output feature to predict with each equation, and the
    second dimension is rows.
- `niterations::Int=10`: The number of iterations to perform the search.
    More iterations will improve the results.
- `weights::Union{AbstractMatrix{T}, AbstractVector{T}, Nothing}=nothing`: Optionally
    weight the loss for each `y` by this value (same shape as `y`).
- `varMap::Union{Array{String, 1}, Nothing}=nothing`: The names
    of each feature in `X`, which will be used during printing of equations.
- `options::Options=Options()`: The options for the search, such as
    which operators to use, evolution hyperparameters, etc.
- `numprocs::Union{Int, Nothing}=nothing`:  The number of processes to use,
    if you want `EquationSearch` to set this up automatically. By default
    this will be `4`, but can be any number (you should pick a number <=
    the number of cores available).
- `procs::Union{Array{Int, 1}, Nothing}=nothing`: If you have set up
    a distributed run manually with `procs = addprocs()` and `@everywhere`,
    pass the `procs` to this keyword argument.
- `multithreading::Bool=false`: Whether to use multithreading. Otherwise,
    will use multiprocessing. Multithreading uses less memory, but multiprocessing
    can handle multi-node compute.
- `runtests::Bool=true`: Whether to run (quick) tests before starting the
    search, to see if there will be any problems during the equation search
    related to the host environment.
- `saved_state::Union{StateType, Nothing}=nothing`: If you have already
    run `EquationSearch` and want to resume it, pass the state here.
    To get this to work, you need to have stateReturn=true in the options,
    which will cause `EquationSearch` to return the state. Note that
    you cannot change the operators or dataset, but most other options
    should be changeable.
- `addprocs_function::Union{Function, Nothing}=nothing`: If using distributed
    mode (`multithreading=false`), you may pass a custom function to use
    instead of `addprocs`. This function should take a single positional argument,
    which is the number of processes to use, as well as the `lazy` keyword argument.
    For example, if set up on a slurm cluster, you could pass
    `addprocs_function = addprocs_slurm`, which will set up slurm processes.

# Returns
- `hallOfFame::HallOfFame`: The best equations seen during the search.
    hallOfFame.members gives an array of `PopMember` objects, which
    have their tree (equation) stored in `.tree`. Their score (loss)
    is given in `.score`. The array of `PopMember` objects
    is enumerated by size from `1` to `options.maxsize`.
"""
function EquationSearch(
    X::AbstractMatrix{T},
    y::AbstractMatrix{T};
    niterations::Int=10,
    weights::Union{AbstractMatrix{T},AbstractVector{T},Nothing}=nothing,
    varMap::Union{Array{String,1},Nothing}=nothing,
    options::Options=Options(),
    numprocs::Union{Int,Nothing}=nothing,
    procs::Union{Array{Int,1},Nothing}=nothing,
    multithreading::Bool=false,
    runtests::Bool=true,
    saved_state::Union{StateType{T},Nothing}=nothing,
    addprocs_function::Union{Function,Nothing}=nothing,
) where {T<:Real}
    nout = size(y, FEATURE_DIM)
    if weights !== nothing
        weights = reshape(weights, size(y))
    end
    datasets = [
        Dataset(
            X,
            y[j, :];
            weights=(weights === nothing ? weights : weights[j, :]),
            varMap=varMap,
        ) for j in 1:nout
    ]

    return EquationSearch(
        datasets;
        niterations=niterations,
        options=options,
        numprocs=numprocs,
        procs=procs,
        multithreading=multithreading,
        runtests=runtests,
        saved_state=saved_state,
        addprocs_function=addprocs_function,
    )
end

function EquationSearch(
    X::AbstractMatrix{T1}, y::AbstractMatrix{T2}; kw...
) where {T1<:Real,T2<:Real}
    U = promote_type(T1, T2)
    return EquationSearch(
        convert(AbstractMatrix{U}, X), convert(AbstractMatrix{U}, y); kw...
    )
end

function EquationSearch(
    X::AbstractMatrix{T1}, y::AbstractVector{T2}; kw...
) where {T1<:Real,T2<:Real}
    return EquationSearch(X, reshape(y, (1, size(y, 1))); kw...)
end

function EquationSearch(
    datasets::Array{Dataset{T},1};
    niterations::Int=10,
    options::Options=Options(),
    numprocs::Union{Int,Nothing}=nothing,
    procs::Union{Array{Int,1},Nothing}=nothing,
    multithreading::Bool=false,
    runtests::Bool=true,
    saved_state::Union{StateType{T},Nothing}=nothing,
    addprocs_function::Union{Function,Nothing}=nothing,
) where {T<:Real}
    noprocs = (procs === nothing && numprocs == 0)
    someprocs = !noprocs

    concurrency = if multithreading
        @assert procs === nothing && numprocs in [0, nothing]
        SRThreaded()
    elseif someprocs
        SRDistributed()
    else #noprocs, multithreading=false
        SRSerial()
    end

    return _EquationSearch(
        concurrency,
        datasets;
        niterations=niterations,
        options=options,
        numprocs=numprocs,
        procs=procs,
        runtests=runtests,
        saved_state=saved_state,
        addprocs_function=addprocs_function,
    )
end

function _EquationSearch(
    ::ConcurrencyType,
    datasets::Array{Dataset{T},1};
    niterations::Int=10,
    options::Options=Options(),
    numprocs::Union{Int,Nothing}=nothing,
    procs::Union{Array{Int,1},Nothing}=nothing,
    runtests::Bool=true,
    saved_state::Union{StateType{T},Nothing}=nothing,
    addprocs_function::Union{Function,Nothing}=nothing,
) where {T<:Real,ConcurrencyType<:SRConcurrency}
    if options.deterministic
        if ConcurrencyType != SRSerial
            error("Determinism is only guaranteed for serial mode.")
        end
    end

    stdin_reader = watch_stream(stdin)

    # Redefine print, show:
    @eval begin
        function Base.print(io::IO, tree::Node)
            return print(io, string_tree(tree, $options; varMap=$(datasets[1].varMap)))
        end
        function Base.show(io::IO, tree::Node)
            return print(io, string_tree(tree, $options; varMap=$(datasets[1].varMap)))
        end
    end

    example_dataset = datasets[1]
    nout = size(datasets, 1)

    if runtests
        test_option_configuration(T, options)
        # Testing the first output variable is the same:
        test_dataset_configuration(example_dataset, options)
    end

    for dataset in datasets
        update_baseline_loss!(dataset, options)
    end

    if options.seed !== nothing
        seed!(options.seed)
    end
    # Start a population on every process
    #    Store the population, hall of fame
    allPopsType = if ConcurrencyType == SRSerial
        Tuple{Population,HallOfFame,RecordType,Float64}
    elseif ConcurrencyType == SRDistributed
        Future
    else
        Task
    end

    allPops = [allPopsType[] for j in 1:nout]
    init_pops = [allPopsType[] for j in 1:nout]
    # Set up a channel to send finished populations back to head node
    if ConcurrencyType in [SRDistributed, SRThreaded]
        if ConcurrencyType == SRDistributed
            channels = [
                [RemoteChannel(1) for i in 1:(options.npopulations)] for j in 1:nout
            ]
        else
            channels = [[Channel(1) for i in 1:(options.npopulations)] for j in 1:nout]
        end
        tasks = [Task[] for j in 1:nout]
    end

    # This is a recorder for populations, but is not actually used for processing, just
    # for the final return.
    returnPops = init_dummy_pops(nout, options.npopulations, datasets, options)
    # These initial populations are discarded:
    bestSubPops = init_dummy_pops(nout, options.npopulations, datasets, options)

    if saved_state === nothing
        hallOfFame = [HallOfFame(options, T) for j in 1:nout]
    else
        hallOfFame = saved_state[2]::Union{HallOfFame{T},Vector{HallOfFame{T}}}
        if !isa(hallOfFame, Vector{HallOfFame{T}})
            hallOfFame = [hallOfFame]
        end
        hallOfFame::Vector{HallOfFame{T}}
    end
    actualMaxsize = options.maxsize + MAX_DEGREE

    all_running_search_statistics = [
        RunningSearchStatistics(; options=options) for i in 1:nout
    ]

    curmaxsizes = [3 for j in 1:nout]
    record = RecordType("options" => "$(options)")

    if options.warmupMaxsizeBy == 0.0f0
        curmaxsizes = [options.maxsize for j in 1:nout]
    end

    # Records the number of evaluations:
    # Real numbers indicate use of batching.
    num_evals = [[0.0 for i in 1:(options.npopulations)] for j in 1:nout]

    we_created_procs = false
    ##########################################################################
    ### Distributed code:
    ##########################################################################
    if ConcurrencyType == SRDistributed
        if addprocs_function === nothing
            addprocs_function = addprocs
        end
        if numprocs === nothing && procs === nothing
            numprocs = 4
            procs = addprocs_function(4; lazy=false)
            we_created_procs = true
        elseif numprocs === nothing
            numprocs = length(procs)
        elseif procs === nothing
            procs = addprocs_function(numprocs; lazy=false)
            we_created_procs = true
        end

        if we_created_procs
            project_path = splitdir(Pkg.project().path)[1]
            activate_env_on_workers(procs, project_path, options)
            import_module_on_workers(procs, @__FILE__, options)
        end
        move_functions_to_workers(procs, options, example_dataset)
        if runtests
            test_module_on_workers(procs, options)
        end

        if runtests
            test_entire_pipeline(procs, example_dataset, options)
        end
    end
    # Get the next worker process to give a job:
    worker_assignment = Dict{Tuple{Int,Int},Int}()

    for j in 1:nout
        for i in 1:(options.npopulations)
            worker_idx = next_worker(worker_assignment, procs)
            if ConcurrencyType == SRDistributed
                worker_assignment[(j, i)] = worker_idx
            end
            if saved_state === nothing
                new_pop = @sr_spawner ConcurrencyType worker_idx (
                    Population(
                        datasets[j];
                        npop=options.npop,
                        nlength=3,
                        options=options,
                        nfeatures=datasets[j].nfeatures,
                    ),
                    HallOfFame(options, T),
                    RecordType(),
                    Float64(options.npop),
                )
                # This involves npop evaluations, on the full dataset:
            else
                is_vector = typeof(saved_state[1]) <: Vector{Vector{Population{T}}}
                cur_saved_state = is_vector ? saved_state[1][j][i] : saved_state[1][j, i]

                if length(cur_saved_state.members) >= options.npop
                    new_pop = @sr_spawner ConcurrencyType worker_idx (
                        cur_saved_state, HallOfFame(options, T), RecordType(), 0.0
                    )
                else
                    # If population has not yet been created (e.g., exited too early)
                    println(
                        "Warning: recreating population (output=$(j), population=$(i)), as the saved one only has $(length(cur_saved_state.members)) members.",
                    )
                    new_pop = @sr_spawner ConcurrencyType worker_idx (
                        Population(
                            datasets[j];
                            npop=options.npop,
                            nlength=3,
                            options=options,
                            nfeatures=datasets[j].nfeatures,
                        ),
                        HallOfFame(options, T),
                        RecordType(),
                        Float64(options.npop),
                    )
                end
            end
            push!(init_pops[j], new_pop)
        end
    end
    # 2. Start the cycle on every process:
    for j in 1:nout
        dataset = datasets[j]
        running_search_statistics = all_running_search_statistics[j]
        curmaxsize = curmaxsizes[j]
        for i in 1:(options.npopulations)
            @recorder record["out$(j)_pop$(i)"] = RecordType()
            worker_idx = next_worker(worker_assignment, procs)
            if ConcurrencyType == SRDistributed
                worker_assignment[(j, i)] = worker_idx
            end

            # TODO - why is this needed??
            # Multi-threaded doesn't like to fetch within a new task:
            updated_pop = @sr_spawner ConcurrencyType worker_idx let
                in_pop = if ConcurrencyType in [SRDistributed, SRThreaded]
                    fetch(init_pops[j][i])[1]
                else
                    init_pops[j][i][1]
                end

                cur_record = RecordType()
                @recorder cur_record["out$(j)_pop$(i)"] = RecordType(
                    "iteration0" => record_population(in_pop, options)
                )
                tmp_num_evals = 0.0
                normalize_frequencies!(running_search_statistics)
                tmp_pop, tmp_best_seen, evals_from_cycle = s_r_cycle(
                    dataset,
                    in_pop,
                    options.ncyclesperiteration,
                    curmaxsize,
                    running_search_statistics;
                    verbosity=options.verbosity,
                    options=options,
                    record=cur_record,
                )
                tmp_num_evals += evals_from_cycle
                tmp_pop, evals_from_optimize = optimize_and_simplify_population(
                    dataset, tmp_pop, options, curmaxsize, cur_record
                )
                tmp_num_evals += evals_from_optimize
                if options.batching
                    for i_member in 1:(options.maxsize + MAX_DEGREE)
                        score, result_loss = score_func(
                            dataset, tmp_best_seen.members[i_member].tree, options
                        )
                        tmp_best_seen.members[i_member].score = score
                        tmp_best_seen.members[i_member].loss = result_loss
                        tmp_num_evals += 1
                    end
                end
                (tmp_pop, tmp_best_seen, cur_record, tmp_num_evals)
            end
            push!(allPops[j], updated_pop)
        end
    end

    debug(options.verbosity > 0 || options.progress, "Started!")
    start_time = time()
    total_cycles = options.npopulations * niterations
    cycles_remaining = [total_cycles for j in 1:nout]
    if options.progress && nout == 1
        #TODO: need to iterate this on the max cycles remaining!
        sum_cycle_remaining = sum(cycles_remaining)
        progress_bar = WrappedProgressBar(
            1:sum_cycle_remaining; width=options.terminal_width
        )
    end

    last_print_time = time()
    num_equations = 0.0
    print_every_n_seconds = 5
    equation_speed = Float32[]

    if ConcurrencyType in [SRDistributed, SRThreaded]
        for j in 1:nout
            for i in 1:(options.npopulations)
                # Start listening for each population to finish:
                t = @async put!(channels[j][i], fetch(allPops[j][i]))
                push!(tasks[j], t)
            end
        end
    end

    # Randomly order which order to check populations:
    # This is done so that we do work on all nout equally.
    all_idx = [(j, i) for j in 1:nout for i in 1:(options.npopulations)]
    shuffle!(all_idx)
    kappa = 0
    head_node_occupied_for = 0.0
    head_node_start = time()
    while sum(cycles_remaining) > 0
        kappa += 1
        if kappa > options.npopulations * nout
            kappa = 1
        end
        # nout, npopulations:
        j, i = all_idx[kappa]

        # Check if error on population:
        if ConcurrencyType in [SRDistributed, SRThreaded]
            if istaskfailed(tasks[j][i])
                fetch(tasks[j][i])
                error("Task failed for population")
            end
        end
        # Non-blocking check if a population is ready:
        population_ready =
            ConcurrencyType in [SRDistributed, SRThreaded] ? isready(channels[j][i]) : true
        # Don't start more if this output has finished its cycles:
        # TODO - this might skip extra cycles?
        population_ready &= (cycles_remaining[j] > 0)
        if population_ready
            head_node_start_work = time()
            # Take the fetch operation from the channel since its ready
            (cur_pop, best_seen, cur_record, cur_num_evals) =
                if ConcurrencyType in [SRDistributed, SRThreaded]
                    take!(channels[j][i])
                else
                    allPops[j][i]
                end
            returnPops[j][i] = cur_pop
            cur_pop::Population
            best_seen::HallOfFame
            cur_record::RecordType
            cur_num_evals::Float64
            bestSubPops[j][i] = best_sub_pop(cur_pop; topn=options.topn)
            @recorder record = recursive_merge(record, cur_record)
            num_evals[j][i] += cur_num_evals

            dataset = datasets[j]
            curmaxsize = curmaxsizes[j]

            #Try normal copy...
            bestPops = Population([
                member for pop in bestSubPops[j] for member in pop.members
            ])

            ###################################################################
            # Hall Of Fame updating ###########################################
            for (i_member, member) in enumerate(
                Iterators.flatten((cur_pop.members, best_seen.members[best_seen.exists]))
            )
                part_of_cur_pop = i_member <= length(cur_pop.members)
                size = compute_complexity(member.tree, options)

                if part_of_cur_pop
                    update_frequencies!(all_running_search_statistics[j]; size=size)
                end
                actualMaxsize = options.maxsize + MAX_DEGREE

                valid_size = size < actualMaxsize
                if valid_size
                    already_filled = hallOfFame[j].exists[size]
                    better_than_current = member.score < hallOfFame[j].members[size].score
                    if !already_filled || better_than_current
                        hallOfFame[j].members[size] = copy_pop_member(member)
                        hallOfFame[j].exists[size] = true
                    end
                end
            end
            ###################################################################

            # Dominating pareto curve - must be better than all simpler equations
            dominating = calculate_pareto_frontier(dataset, hallOfFame[j], options)
            hofFile = options.hofFile
            if nout > 1
                hofFile = hofFile * ".out$j"
            end
            # Write file twice in case exit in middle of filewrite
            for out_file in [hofFile, hofFile * ".bkup"]
                open(out_file, "w") do io
                    println(io, "Complexity,Loss,Equation")
                    for member in dominating
                        println(
                            io,
                            "$(compute_complexity(member.tree, options)),$(member.loss),\"$(string_tree(member.tree, options, varMap=dataset.varMap))\"",
                        )
                    end
                end
            end

            ###################################################################
            # Migration #######################################################
            # Try normal copy otherwise.
            if options.migration
                for k in rand(
                    1:(options.npop), round(Int, options.npop * options.fractionReplaced)
                )
                    to_copy = rand(1:size(bestPops.members, 1))

                    # Explicit copy here resets the birth. 
                    cur_pop.members[k] = PopMember(
                        copy_node(bestPops.members[to_copy].tree),
                        copy(bestPops.members[to_copy].score),
                        copy(bestPops.members[to_copy].loss);
                        ref=copy(bestPops.members[to_copy].ref),
                        parent=copy(bestPops.members[to_copy].parent),
                        deterministic=options.deterministic,
                    )
                    # TODO: Clean this up using copy_pop_member.
                end
            end

            if options.hofMigration && size(dominating, 1) > 0
                for k in rand(
                    1:(options.npop), round(Int, options.npop * options.fractionReplacedHof)
                )
                    # Copy in case one gets used twice
                    to_copy = rand(1:size(dominating, 1))
                    cur_pop.members[k] = PopMember(
                        copy_node(dominating[to_copy].tree),
                        copy(dominating[to_copy].score),
                        copy(dominating[to_copy].loss);
                        ref=copy(dominating[to_copy].ref),
                        parent=copy(dominating[to_copy].parent),
                        deterministic=options.deterministic,
                    )
                    # TODO: Clean this up with copy_pop_member.
                end
            end
            ###################################################################

            cycles_remaining[j] -= 1
            if cycles_remaining[j] == 0
                break
            end
            worker_idx = next_worker(worker_assignment, procs)
            if ConcurrencyType == SRDistributed
                worker_assignment[(j, i)] = worker_idx
            end
            @recorder begin
                key = "out$(j)_pop$(i)"
                iteration = find_iteration_from_record(key, record) + 1
            end

            allPops[j][i] = @sr_spawner ConcurrencyType worker_idx let
                cur_record = RecordType()
                @recorder cur_record[key] = RecordType(
                    "iteration$(iteration)" => record_population(cur_pop, options)
                )
                tmp_num_evals = 0.0
                normalize_frequencies!(all_running_search_statistics[j])
                tmp_pop, tmp_best_seen, evals_from_cycle = s_r_cycle(
                    dataset,
                    cur_pop,
                    options.ncyclesperiteration,
                    curmaxsize,
                    all_running_search_statistics[j];
                    verbosity=options.verbosity,
                    options=options,
                    record=cur_record,
                )
                tmp_num_evals += evals_from_cycle
                tmp_pop, evals_from_optimize = optimize_and_simplify_population(
                    dataset, tmp_pop, options, curmaxsize, cur_record
                )
                tmp_num_evals += evals_from_optimize

                # Update scores if using batching:
                if options.batching
                    for i_member in 1:(options.maxsize + MAX_DEGREE)
                        if tmp_best_seen.exists[i_member]
                            score, result_loss = score_func(
                                dataset, tmp_best_seen.members[i_member].tree, options
                            )
                            tmp_best_seen.members[i_member].score = score
                            tmp_best_seen.members[i_member].loss = result_loss
                            tmp_num_evals += 1
                        end
                    end
                end

                (tmp_pop, tmp_best_seen, cur_record, tmp_num_evals)
            end
            if ConcurrencyType in [SRDistributed, SRThreaded]
                tasks[j][i] = @async put!(channels[j][i], fetch(allPops[j][i]))
            end

            cycles_elapsed = total_cycles - cycles_remaining[j]
            if options.warmupMaxsizeBy > 0
                fraction_elapsed = 1.0f0 * cycles_elapsed / total_cycles
                if fraction_elapsed > options.warmupMaxsizeBy
                    curmaxsizes[j] = options.maxsize
                else
                    curmaxsizes[j] =
                        3 + floor(
                            Int,
                            (options.maxsize - 3) * fraction_elapsed /
                            options.warmupMaxsizeBy,
                        )
                end
            end
            num_equations += options.ncyclesperiteration * options.npop / 10.0

            if options.progress && nout == 1
                head_node_occupation =
                    100 * head_node_occupied_for / (time() - head_node_start)
                update_progress_bar!(
                    progress_bar;
                    hall_of_fame=hallOfFame[j],
                    dataset=datasets[j],
                    options=options,
                    head_node_occupation=head_node_occupation,
                )
            end
            head_node_end_work = time()
            head_node_occupied_for += (head_node_end_work - head_node_start_work)

            move_window!(all_running_search_statistics[j])
        end
        sleep(1e-6)

        ################################################################
        ## Printing code
        elapsed = time() - last_print_time
        #Update if time has passed, and some new equations generated.
        if elapsed > print_every_n_seconds && num_equations > 0.0
            # Dominating pareto curve - must be better than all simpler equations
            head_node_occupation = 100 * head_node_occupied_for / (time() - head_node_start)
            current_speed = num_equations / elapsed
            average_over_m_measurements = 10 #for print_every...=5, this gives 50 second running average
            push!(equation_speed, current_speed)
            if length(equation_speed) > average_over_m_measurements
                deleteat!(equation_speed, 1)
            end
            if (options.verbosity > 0) || (options.progress && nout > 1)
                print_search_state(
                    hallOfFame,
                    datasets,
                    options;
                    equation_speed=equation_speed,
                    total_cycles=total_cycles,
                    cycles_remaining=cycles_remaining,
                    head_node_occupation=head_node_occupation,
                )
            end
            last_print_time = time()
            num_equations = 0.0
        end
        ################################################################

        ################################################################
        ## Early stopping code
        if any((
            check_for_loss_threshold(datasets, hallOfFame, options),
            check_for_user_quit(stdin_reader),
            check_for_timeout(start_time, options),
            check_max_evals(num_evals, options),
        ))
            break
        end
        ################################################################
    end

    close_reader!(stdin_reader)

    if we_created_procs
        rmprocs(procs)
    end
    # TODO - also stop threads here?

    ##########################################################################
    ### Distributed code^
    ##########################################################################

    @recorder begin
        open(options.recorder_file, "w") do io
            JSON3.write(io, record; allow_inf=true)
        end
    end

    if options.stateReturn
        state = (returnPops, (nout == 1 ? hallOfFame[1] : hallOfFame))
        state::StateType{T}
        return state
    else
        if nout == 1
            return hallOfFame[1]
        else
            return hallOfFame
        end
    end
end

end #module SR
