module SymbolicRegression

# Types
export Population,
    PopMember,
    HallOfFame,
    Options,
    Node,

    #Functions:
    EquationSearch,
    SRCycle,
    calculateParetoFrontier,
    countNodes,
    copyNode,
    printTree,
    stringTree,
    evalTreeArray,
    node_to_symbolic,
    symbolic_to_node,
    custom_simplify,
    simplifyWithSymbolicUtils,
    combineOperators,
    genRandomTree,

    #Operators:
    plus,
    sub,
    mult,
    square,
    cube,
    pow,
    div,
    log_abs,
    log2_abs,
    log10_abs,
    sqrt_abs,
    neg,
    greater,
    relu,
    logical_or,
    logical_and

using Distributed
using Printf: @printf
using Pkg
using Random: seed!
using FromFile
using Reexport
@reexport using LossFunctions

@from "Core.jl" import CONST_TYPE, maxdegree, Dataset, Node, copyNode, Options, plus, sub, mult, square, cube, pow, div, log_abs, log2_abs, log10_abs, sqrt_abs, neg, greater, greater, relu, logical_or, logical_and
@from "Utils.jl" import debug, debug_inline, is_anonymous_function
@from "EquationUtils.jl" import countNodes, printTree, stringTree
@from "EvaluateEquation.jl" import evalTreeArray
@from "CheckConstraints.jl" import check_constraints
@from "MutationFunctions.jl" import genRandomTree
@from "LossFunctions.jl" import EvalLoss, Loss, scoreFunc
@from "PopMember.jl" import PopMember, copyPopMember
@from "Population.jl" import Population, bestSubPop
@from "HallOfFame.jl" import HallOfFame, calculateParetoFrontier, string_dominating_pareto_curve
@from "SingleIteration.jl" import SRCycle, OptimizeAndSimplifyPopulation
@from "InterfaceSymbolicUtils.jl" import node_to_symbolic, symbolic_to_node
@from "CustomSymbolicUtilsSimplification.jl" import custom_simplify
@from "SimplifyEquation.jl" import simplifyWithSymbolicUtils, combineOperators, simplifyTree
@from "ProgressBars.jl" import ProgressBar, set_multiline_postfix

include("Configure.jl")
include("Deprecates.jl")


"""
    EquationSearch(X, y[; kws...])

Perform a distributed equation search for functions which
describe the mapping f(X[:, j]) ≈ y[j]. Options are
configured using SymbolicRegression.Options(...),
which should be passed as a keyword argument to options.
One can turn off parallelism with `numprocs=0`,
which is useful for debugging and profiling.

# Arguments
- `X::AbstractMatrix{T}`:  The input dataset to predict `y` from.
    The first dimension is features, the second dimension is rows.
- `y::AbstractVector{T}`: The values to predict. Only a single feature
    is allowed, so `y` is a 1D array.
- `niterations::Int=10`: The number of iterations to perform the search.
    More iterations will improve the results.
- `weights::Union{AbstractVector{T}, Nothing}=nothing`: Optionally
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
- `runtests::Bool=true`: Whether to run (quick) tests before starting the
    search, to see if there will be any problems during the equation search
    related to the host environment.

# Returns
- `hallOfFame::HallOfFame`: The best equations seen during the search.
    hallOfFame.members gives an array of `PopMember` objects, which
    have their tree (equation) stored in `.tree`. Their score (loss)
    is given in `.score`. The array of `PopMember` objects
    is enumerated by size from `1` to `options.maxsize`.
"""
function EquationSearch(X::AbstractMatrix{T}, y::AbstractVector{T};
        niterations::Int=10,
        weights::Union{AbstractVector{T}, Nothing}=nothing,
        varMap::Union{Array{String, 1}, Nothing}=nothing,
        options::Options=Options(),
        numprocs::Union{Int, Nothing}=nothing,
        procs::Union{Array{Int, 1}, Nothing}=nothing,
        runtests::Bool=true
       ) where {T<:Real}

    dataset = Dataset(X, y,
                     weights=weights,
                     varMap=varMap)
    serial = (procs == nothing && numprocs == 0)
    parallel = !serial

    if runtests
        testOptionConfiguration(T, options)
        testDatasetConfiguration(dataset, options)
    end

    if dataset.weighted
        avgy = sum(dataset.y .* dataset.weights)/sum(dataset.weights)
        baselineMSE = Loss(dataset.y, ones(T, dataset.n) .* avgy, dataset.weights, options)
    else
        avgy = sum(dataset.y)/dataset.n
        baselineMSE = Loss(dataset.y, ones(T, dataset.n) .* avgy, options)
    end

    if options.seed !== nothing
        seed!(options.seed)
    end
    # Start a population on every process
    allPopsType = parallel ? Future : Tuple{Population,HallOfFame}
    allPops = allPopsType[]
    # Set up a channel to send finished populations back to head node
    channels = [RemoteChannel(1) for j=1:options.npopulations]
    bestSubPops = [Population(dataset, baselineMSE, npop=1, options=options, nfeatures=dataset.nfeatures) for j=1:options.npopulations]
    hallOfFame = HallOfFame(options)
    actualMaxsize = options.maxsize + maxdegree
    frequencyComplexity = ones(T, actualMaxsize)
    curmaxsize = 3
    if options.warmupMaxsizeBy == 0f0
        curmaxsize = options.maxsize
    end

    we_created_procs = false
    ##########################################################################
    ### Distributed code:
    ##########################################################################
    if parallel
        if numprocs == nothing && procs == nothing
            numprocs = 4
            procs = addprocs(4)
            we_created_procs = true
        elseif numprocs == nothing
            numprocs = length(procs)
        elseif procs == nothing
            procs = addprocs(numprocs)
            we_created_procs = true
        end
        if we_created_procs
            project_path = splitdir(Pkg.project().path)[1]
            activate_env_on_workers(procs, project_path, options)
            import_module_on_workers(procs, @__FILE__, options)
        end
        move_functions_to_workers(procs, options, dataset)
        if runtests
            test_module_on_workers(procs, options)
        end

        if runtests
            test_entire_pipeline(procs, dataset, options)
        end
    end
    cur_proc_idx = 1
    # Get the next worker process to give a job:
    function next_worker()::Int
        if parallel
            idx = ((cur_proc_idx-1) % numprocs) + 1
            cur_proc_idx += 1
            return procs[idx]
        else
            return 0
        end
    end

    for i=1:options.npopulations
        worker_idx = next_worker()
        new_pop = if parallel
            (@spawnat worker_idx Population(dataset, baselineMSE,
                                            npop=options.npop, nlength=3,
                                            options=options,
                                            nfeatures=dataset.nfeatures),
            HallOfFame(options))
        else
            (Population(dataset, baselineMSE,
                        npop=options.npop, nlength=3,
                        options=options,
                        nfeatures=dataset.nfeatures), HallOfFame(options))
        end
        push!(allPops, new_pop)
    end
    # 2. Start the cycle on every process:
    for i=1:options.npopulations
        worker_idx = next_worker()
        allPops[i] = if parallel
            @spawnat worker_idx let
                tmp_pop, tmp_best_seen = SRCycle(dataset, baselineMSE, fetch(allPops[i])[1], options.ncyclesperiteration, curmaxsize, copy(frequencyComplexity)/sum(frequencyComplexity), verbosity=options.verbosity, options=options)
                tmp_pop = OptimizeAndSimplifyPopulation(dataset, baselineMSE, tmp_pop, options, curmaxsize)
                if options.batching
                    for i_member=1:(options.maxsize + maxdegree)
                        tmp_best_seen.members[i_member].score = scoreFunc(dataset, baselineMSE, tmp_best_seen.members[i_member].tree, options)
                    end
                end
                (tmp_pop, tmp_best_seen)
            end
        else
            tmp_pop, tmp_best_seen = SRCycle(dataset, baselineMSE, allPops[i][1], options.ncyclesperiteration, curmaxsize, copy(frequencyComplexity)/sum(frequencyComplexity), verbosity=options.verbosity, options=options)
            tmp_pop = OptimizeAndSimplifyPopulation(dataset, baselineMSE, tmp_pop, options, curmaxsize)
            if options.batching
                for i_member=1:(options.maxsize + maxdegree)
                    tmp_best_seen.members[i_member].score = scoreFunc(dataset, baselineMSE, tmp_best_seen.members[i_member].tree, options)
                end
            end
            (tmp_pop, tmp_best_seen)
        end
    end

    debug(options.verbosity > 0 || options.progress, "Started!")
    total_cycles = options.npopulations * niterations
    cycles_remaining = total_cycles
    if options.progress
        progress_bar = ProgressBar(1:cycles_remaining;
                                   width=options.terminal_width)
        cur_cycle = nothing
        cur_state = nothing
    end

    last_print_time = time()
    num_equations = 0.0
    print_every_n_seconds = 5
    equation_speed = Float32[]

    if parallel
        for i=1:options.npopulations
            # Start listening for each population to finish:
            @async put!(channels[i], fetch(allPops[i]))
        end
    end

    while cycles_remaining > 0
        for i=1:options.npopulations
            # Non-blocking check if a population is ready:
            population_ready = parallel ? isready(channels[i]) : true
            if population_ready
                # Take the fetch operation from the channel since its ready
                (cur_pop, best_seen) = parallel ? take!(channels[i]) : allPops[i]
                cur_pop::Population
                best_seen::HallOfFame
                bestSubPops[i] = bestSubPop(cur_pop, topn=options.topn)

                #Try normal copy...
                bestPops = Population([member for pop in bestSubPops for member in pop.members])

                for (i_member, member) in enumerate(Iterators.flatten((cur_pop.members, best_seen.members[best_seen.exists])))
                    part_of_cur_pop = i_member <= length(cur_pop.members)
                    size = countNodes(member.tree)
                    if part_of_cur_pop
                        frequencyComplexity[size] += 1
                    end
                    actualMaxsize = options.maxsize + maxdegree
                    if size < actualMaxsize && all([member.score < hallOfFame.members[size2].score for size2=1:size])
                        hallOfFame.members[size] = copyPopMember(member)
                        hallOfFame.exists[size] = true
                    end
                end

                # Dominating pareto curve - must be better than all simpler equations
                dominating = calculateParetoFrontier(dataset, hallOfFame, options)
                open(options.hofFile, "w") do io
                    println(io,"Complexity|MSE|Equation")
                    for member in dominating
                        println(io, "$(countNodes(member.tree))|$(member.score)|$(stringTree(member.tree, options, varMap=dataset.varMap))")
                    end
                end
                cp(options.hofFile, options.hofFile*".bkup", force=true)

                # Try normal copy otherwise.
                if options.migration
                    for k in rand(1:options.npop, round(Int, options.npop*options.fractionReplaced))
                        to_copy = rand(1:size(bestPops.members, 1))
                        cur_pop.members[k] = PopMember(
                            copyNode(bestPops.members[to_copy].tree),
                            bestPops.members[to_copy].score)
                    end
                end

                if options.hofMigration && size(dominating, 1) > 0
                    for k in rand(1:options.npop, round(Int, options.npop*options.fractionReplacedHof))
                        # Copy in case one gets used twice
                        to_copy = rand(1:size(dominating, 1))
                        cur_pop.members[k] = PopMember(
                           copyNode(dominating[to_copy].tree), dominating[to_copy].score
                        )
                    end
                end

                cycles_remaining -= 1
                if cycles_remaining == 0
                    break
                end
                worker_idx = next_worker()
                allPops[i] = if parallel
                    @spawnat worker_idx let
                        tmp_pop, tmp_best_seen = SRCycle(
                            dataset, baselineMSE, cur_pop, options.ncyclesperiteration,
                            curmaxsize, copy(frequencyComplexity)/sum(frequencyComplexity),
                            verbosity=options.verbosity, options=options)
                        tmp_pop = OptimizeAndSimplifyPopulation(dataset, baselineMSE, tmp_pop, options, curmaxsize)
                        if options.batching
                            for i_member=1:(options.maxsize + maxdegree)
                                tmp_best_seen.members[i_member].score = scoreFunc(dataset, baselineMSE, tmp_best_seen.members[i_member].tree, options)
                            end
                        end
                        (tmp_pop, tmp_best_seen)
                    end
                else
                    tmp_pop, tmp_best_seen = SRCycle(
                        dataset, baselineMSE, cur_pop, options.ncyclesperiteration,
                        curmaxsize, copy(frequencyComplexity)/sum(frequencyComplexity),
                        verbosity=options.verbosity, options=options)
                    tmp_pop = OptimizeAndSimplifyPopulation(dataset, baselineMSE, tmp_pop, options, curmaxsize)
                    if options.batching
                        for i_member=1:(options.maxsize + maxdegree)
                            tmp_best_seen.members[i_member].score = scoreFunc(dataset, baselineMSE, tmp_best_seen.members[i_member].tree, options)
                        end
                    end
                    (tmp_pop, tmp_best_seen)
                end
                if parallel
                    @async put!(channels[i], fetch(allPops[i]))
                end

                cycles_elapsed = total_cycles - cycles_remaining
                if options.warmupMaxsizeBy > 0
                    fraction_elapsed = 1f0 * cycles_elapsed / total_cycles
                    if fraction_elapsed > options.warmupMaxsizeBy
                        curmaxsize = options.maxsize
                    else
                        curmaxsize = 3 + floor(Int, (options.maxsize - 3) * fraction_elapsed / options.warmupMaxsizeBy)
                    end
                end
                num_equations += options.ncyclesperiteration * options.npop / 10.0

                if options.progress
                    # set_postfix(iter, Equations=)
                    equation_strings = string_dominating_pareto_curve(hallOfFame, baselineMSE,
                                                                      dataset, options,
                                                                      avgy)
                    set_multiline_postfix(progress_bar, equation_strings)
                    if cur_cycle == nothing
                        (cur_cycle, cur_state) = iterate(progress_bar)
                    else
                        (cur_cycle, cur_state) = iterate(progress_bar, cur_state)
                    end
                end
            end
            elapsed = time() - last_print_time
            #Update if time has passed, and some new equations generated.
            if elapsed > print_every_n_seconds && num_equations > 0.0
                # Dominating pareto curve - must be better than all simpler equations
                current_speed = num_equations/elapsed
                average_over_m_measurements = 10 #for print_every...=5, this gives 50 second running average
                push!(equation_speed, current_speed)
                if length(equation_speed) > average_over_m_measurements
                    deleteat!(equation_speed, 1)
                end
                if options.verbosity > 0
                    @printf("\n")
                    average_speed = sum(equation_speed)/length(equation_speed)
                    @printf("Cycles per second: %.3e\n", round(average_speed, sigdigits=3))
                    cycles_elapsed = total_cycles - cycles_remaining
                    @printf("Progress: %d / %d total iterations (%.3f%%)\n",
                            cycles_elapsed, total_cycles,
                            100.0*cycles_elapsed/total_cycles)
                    equation_strings = string_dominating_pareto_curve(hallOfFame, baselineMSE,
                                                                      dataset, options,
                                                                      avgy)
                    print(equation_strings)
                end
                last_print_time = time()
                num_equations = 0.0
            end
        end
        sleep(1e-3)
    end
    if we_created_procs
        rmprocs(procs)
    end
    ##########################################################################
    ### Distributed code^
    ##########################################################################
    return hallOfFame
end

function EquationSearch(X::AbstractMatrix{T1}, y::AbstractVector{T2}; kw...) where {T1<:Real,T2<:Real}
    U = promote_type(T1, T2)
    EquationSearch(convert(AbstractMatrix{U}, X), convert(AbstractVector{U}, y); kw...)
end

end #module SR
